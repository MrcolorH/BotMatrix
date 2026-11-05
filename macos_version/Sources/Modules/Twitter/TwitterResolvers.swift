import Foundation

public enum TwitterResolverError: LocalizedError {
    case invalidUrl
    case noMediaFound
    case noVideoStreams
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "未匹配到有效的 Twitter / X 推文链接"
        case .noMediaFound:
            return "推文中未检测到媒体内容"
        case .noVideoStreams:
            return "未找到可用的 MP4 视频直链"
        case .apiError(let msg):
            return "解析引擎异常: \(msg)"
        }
    }
}

public struct TwitterResolvers {
    public static let twitterRegex = try! NSRegularExpression(
        pattern: #"https?://(?:www\.)?(?:twitter|x)\.com/[a-zA-Z0-9_]+/status/(\d+)"#,
        options: .caseInsensitive
    )

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
        return URLSession(configuration: config)
    }()

    public static func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "未知大小" }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }

    /// 通过 HEAD 请求毫秒级探测远程视频文件大小
    public static func getRemoteFileSize(url: URL) async -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        do {
            let (_, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse,
               let lenHeader = httpRes.allHeaderFields["Content-Length"] as? String,
               let bytes = Int64(lenHeader), bytes > 0 {
                return formatBytes(bytes)
            }
        } catch {}
        return "未知大小"
    }

    /// 引擎 1：FixTweet API (免 Key，画质高)
    public static func resolveViaFxTwitter(statusId: String) async throws -> VideoParseResult {
        guard let url = URL(string: "https://api.fxtwitter.com/status/\(statusId)") else {
            throw TwitterResolverError.invalidUrl
        }

        let (data, response) = try await session.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw TwitterResolverError.apiError("FixTweet 响应异常")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tweet = json["tweet"] as? [String: Any] else {
            throw TwitterResolverError.apiError("推文数据解析失败")
        }

        guard let media = tweet["media"] as? [String: Any],
              let videos = media["videos"] as? [[String: Any]],
              let firstVideo = videos.first else {
            throw TwitterResolverError.noMediaFound
        }

        let formats = firstVideo["formats"] as? [[String: Any]] ?? []
        let mp4Formats = formats.filter { item in
            let container = item["container"] as? String ?? ""
            let u = item["url"] as? String ?? ""
            return container.lowercased() == "mp4" || u.contains(".mp4")
        }

        var bestUrl: String = ""
        if !mp4Formats.isEmpty {
            let sorted = mp4Formats.sorted { a, b in
                let bitA = a["bitrate"] as? Int ?? 0
                let bitB = b["bitrate"] as? Int ?? 0
                return bitB < bitA
            }
            bestUrl = sorted.first?["url"] as? String ?? ""
        } else {
            bestUrl = firstVideo["url"] as? String ?? ""
        }

        guard !bestUrl.isEmpty else {
            throw TwitterResolverError.noVideoStreams
        }

        var resolution = "最高画质"
        if let regex = try? NSRegularExpression(pattern: #"(\d+)x(\d+)"#),
           let match = regex.firstMatch(in: bestUrl, range: NSRange(bestUrl.startIndex..., in: bestUrl)),
           let heightRange = Range(match.range(at: 2), in: bestUrl) {
            resolution = "\(bestUrl[heightRange])p"
        } else if let height = firstVideo["height"] as? Int {
            resolution = "\(height)" + "p"
        }

        let authorName = (tweet["author"] as? [String: Any])?["name"] as? String ?? "Twitter 用户"
        let tweetText = tweet["text"] as? String ?? ""
        let thumbnail = firstVideo["thumbnail_url"] as? String

        return VideoParseResult(
            url: bestUrl,
            resolution: resolution,
            author: authorName,
            title: tweetText.count > 160 ? String(tweetText.prefix(160)) : tweetText,
            thumbnail: thumbnail
        )
    }

    /// 引擎 2：TwitterDown 官方接口
    public static func resolveViaTwitterDown(tweetUrl: String, apiKey: String) async throws -> VideoParseResult {
        guard let url = URL(string: "https://twitterdown.com/api/v1/twitter") else {
            throw TwitterResolverError.invalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ["url": tweetUrl]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw TwitterResolverError.apiError("TwitterDown HTTP 响应异常")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TwitterResolverError.apiError("TwitterDown 响应解析失败")
        }

        guard let code = json["code"] as? Int, code == 0,
              let resData = json["data"] as? [String: Any],
              let videos = resData["videos"] as? [[String: Any]],
              let firstVideo = videos.first else {
            throw TwitterResolverError.apiError(json["message"] as? String ?? "TwitterDown 未获取到视频")
        }

        let videoUrl = firstVideo["url"] as? String ?? ""
        let resolution = firstVideo["resolution"] as? String ?? "HD"
        let author = resData["username"] as? String ?? "未知"
        let text = resData["text"] as? String ?? ""
        let thumbnail = resData["thumbnail"] as? String

        return VideoParseResult(
            url: videoUrl,
            resolution: resolution,
            author: author,
            title: text,
            thumbnail: thumbnail
        )
    }

    /// 引擎 3：VxTwitter 开放兜底接口
    public static func resolveViaVxTwitter(statusId: String) async throws -> VideoParseResult {
        guard let url = URL(string: "https://api.vxtwitter.com/Twitter/status/\(statusId)") else {
            throw TwitterResolverError.invalidUrl
        }

        let (data, response) = try await session.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw TwitterResolverError.apiError("VxTwitter 响应异常")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TwitterResolverError.apiError("数据解析失败")
        }

        guard let mediaUrls = json["mediaURLs"] as? [String],
              let videoUrl = mediaUrls.first(where: { $0.contains(".mp4") }) else {
            throw TwitterResolverError.noVideoStreams
        }

        var resolution = "最高画质"
        if let regex = try? NSRegularExpression(pattern: #"(\d+)x(\d+)"#),
           let match = regex.firstMatch(in: videoUrl, range: NSRange(videoUrl.startIndex..., in: videoUrl)),
           let heightRange = Range(match.range(at: 2), in: videoUrl) {
            resolution = "\(videoUrl[heightRange])p"
        }

        let authorName = json["user_name"] as? String ?? "Twitter 用户"
        let text = json["text"] as? String ?? ""

        return VideoParseResult(
            url: videoUrl,
            resolution: resolution,
            author: authorName,
            title: text,
            thumbnail: nil
        )
    }

    /// 聚合多引擎自动降级解析
    public static func resolve(
        tweetUrl: String,
        statusId: String,
        apiKey: String? = nil
    ) async throws -> VideoParseResult {
        var lastError: Error?

        // 1. 尝试 FixTweet
        do {
            var result = try await resolveViaFxTwitter(statusId: statusId)
            if let streamUrl = URL(string: result.url) {
                result.fileSize = await getRemoteFileSize(url: streamUrl)
            }
            return result
        } catch {
            lastError = error
        }

        // 2. 尝试 TwitterDown (若提供了 key)
        if let key = apiKey, !key.trimmingCharacters(in: .whitespaces).isEmpty {
            do {
                var result = try await resolveViaTwitterDown(tweetUrl: tweetUrl, apiKey: key)
                if let streamUrl = URL(string: result.url) {
                    result.fileSize = await getRemoteFileSize(url: streamUrl)
                }
                return result
            } catch {
                lastError = error
            }
        }

        // 3. 尝试 VxTwitter 兜底
        do {
            var result = try await resolveViaVxTwitter(statusId: statusId)
            if let streamUrl = URL(string: result.url) {
                result.fileSize = await getRemoteFileSize(url: streamUrl)
            }
            return result
        } catch {
            lastError = error
        }

        throw lastError ?? TwitterResolverError.apiError("所有解析引擎均无响应")
    }
}
