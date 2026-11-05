import Foundation

public enum VideoPlatform: String {
    case twitter = "Twitter / X"
    case tiktok = "TikTok / 抖音"
    case bilibili = "Bilibili"
    case youtube = "YouTube"
    case unknown = "通用网页"

    public var badge: String {
        switch self {
        case .twitter: return "🐦 Twitter/X"
        case .tiktok: return "🎵 TikTok/抖音"
        case .bilibili: return "📺 Bilibili"
        case .youtube: return "▶️ YouTube"
        case .unknown: return "🎬 视频流"
        }
    }
}

public struct UniversalVideoResolver {
    // 匹配正则
    public static let urlRegex = try! NSRegularExpression(
        pattern: #"https?://[^\s/$.?#].[^\s]*"#,
        options: .caseInsensitive
    )

    public static func detectPlatform(url: String) -> VideoPlatform {
        let lower = url.lowercased()
        if lower.contains("twitter.com") || lower.contains("x.com") {
            return .twitter
        } else if lower.contains("tiktok.com") || lower.contains("douyin.com") || lower.contains("b23.tv") == false && lower.contains("v.douyin.com") {
            return .tiktok
        } else if lower.contains("bilibili.com") || lower.contains("b23.tv") {
            return .bilibili
        } else if lower.contains("youtube.com") || lower.contains("youtu.be") {
            return .youtube
        }
        return .unknown
    }

    /// 提取消息中包含的第一个有效视频链接
    public static func extractUrl(from text: String) -> String? {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = urlRegex.firstMatch(in: text, range: range) else { return nil }
        return ns.substring(with: match.range)
    }

    /// 判断消息是否为一条纯视频链接或视频 App 分享文本（用于与普通 AI 对话清晰分流）
    public static func isVideoLinkMessage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = extractUrl(from: trimmed) else { return false }
        let platform = detectPlatform(url: url)
        guard platform != .unknown else { return false }

        // 移除 URL 后检查剩余字符
        let withoutUrl = trimmed.replacingOccurrences(of: url, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if withoutUrl.isEmpty {
            return true
        }

        // 兼容抖音、B站等常见客户端一键分享的样板前缀文本
        if withoutUrl.contains("复制打开抖音") || withoutUrl.contains("b23.tv") || (withoutUrl.hasPrefix("【") && withoutUrl.hasSuffix("】")) {
            return true
        }

        return false
    }

    /// 统一入口：根据链接全自动识别并分发给对应引擎
    public static func resolve(
        rawUrl: String,
        twitterApiKey: String? = nil
    ) async throws -> (platform: VideoPlatform, result: VideoParseResult) {
        let platform = detectPlatform(url: rawUrl)

        switch platform {
        case .twitter:
            let statusId = extractTwitterStatusId(from: rawUrl) ?? ""
            let res = try await TwitterResolvers.resolve(tweetUrl: rawUrl, statusId: statusId, apiKey: twitterApiKey)
            return (.twitter, res)

        case .tiktok:
            let res = try await resolveTikTok(url: rawUrl)
            return (.tiktok, res)

        case .bilibili:
            let res = try await resolveBilibili(url: rawUrl)
            return (.bilibili, res)

        case .youtube:
            let res = try await resolveYouTube(url: rawUrl)
            return (.youtube, res)

        case .unknown:
            // 尝试按 Twitter 链接解析
            if let statusId = extractTwitterStatusId(from: rawUrl) {
                let res = try await TwitterResolvers.resolve(tweetUrl: rawUrl, statusId: statusId, apiKey: twitterApiKey)
                return (.twitter, res)
            }
            throw NSError(domain: "Resolver", code: 400, userInfo: [NSLocalizedDescriptionKey: "暂不支持该网站的自动直链解析"])
        }
    }

    private static func extractTwitterStatusId(from url: String) -> String? {
        let ns = url as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = TwitterResolvers.twitterRegex.firstMatch(in: url, range: range), match.numberOfRanges >= 2 {
            return ns.substring(with: match.range(at: 1))
        }
        return nil
    }

    // 引擎：TikTok / 抖音解析
    private static func resolveTikTok(url: String) async throws -> VideoParseResult {
        guard let apiUrl = URL(string: "https://www.tikwm.com/api/?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)") else {
            throw NSError(domain: "TikTok", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的 TikTok 链接"])
        }

        let (data, _) = try await URLSession.shared.data(from: apiUrl)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let item = json["data"] as? [String: Any] else {
            throw NSError(domain: "TikTok", code: 500, userInfo: [NSLocalizedDescriptionKey: "TikTok / 抖音解析失败，未提取到无水印直链"])
        }

        let playUrl = item["play"] as? String ?? item["wmplay"] as? String ?? ""
        let title = item["title"] as? String ?? "抖音无水印视频"
        let author = (item["author"] as? [String: Any])?["nickname"] as? String ?? "短视频作者"
        let cover = item["cover"] as? String

        var result = VideoParseResult(
            url: playUrl,
            resolution: "无水印高清",
            author: author,
            title: title,
            thumbnail: cover
        )
        if let u = URL(string: playUrl) {
            result.fileSize = await TwitterResolvers.getRemoteFileSize(url: u)
        }
        return result
    }

    // 引擎：Bilibili 解析
    private static func resolveBilibili(url: String) async throws -> VideoParseResult {
        var finalUrl = url
        // 处理 b23.tv 短链重定向
        if url.contains("b23.tv") {
            if let reqUrl = URL(string: url) {
                var request = URLRequest(url: reqUrl)
                request.httpMethod = "GET"
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                if let (_, resp) = try? await URLSession.shared.data(for: request),
                   let http = resp as? HTTPURLResponse {
                    if let targetUrl = http.url?.absoluteString, (targetUrl.contains("BV") || targetUrl.contains("bilibili.com")) {
                        finalUrl = targetUrl
                    } else if let loc = http.allHeaderFields["Location"] as? String {
                        finalUrl = loc
                    }
                }
            }
        }

        // 提取 BV 或 AV 号
        var bvid = ""
        var aid = ""
        if let bvMatch = finalUrl.range(of: #"BV[a-zA-Z0-9]+"#, options: .regularExpression) {
            bvid = String(finalUrl[bvMatch])
        } else if let avMatch = finalUrl.range(of: #"av(\d+)"#, options: .regularExpression) {
            let fullAv = String(finalUrl[avMatch])
            aid = String(fullAv.dropFirst(2))
        }

        guard !bvid.isEmpty || !aid.isEmpty else {
            throw NSError(domain: "Bilibili", code: 400, userInfo: [NSLocalizedDescriptionKey: "未找到 Bilibili 视频 BV 或 AV 号"])
        }

        let queryParam = !bvid.isEmpty ? "bvid=\(bvid)" : "aid=\(aid)"
        guard let infoApi = URL(string: "https://api.bilibili.com/x/web-interface/view?\(queryParam)") else {
            throw NSError(domain: "Bilibili", code: 400, userInfo: [NSLocalizedDescriptionKey: "B站接口请求失败"])
        }

        let (data, _) = try await URLSession.shared.data(from: infoApi)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw NSError(domain: "Bilibili", code: 500, userInfo: [NSLocalizedDescriptionKey: "获取 B站 视频信息失败"])
        }

        let title = dataObj["title"] as? String ?? "Bilibili 视频"
        let owner = (dataObj["owner"] as? [String: Any])?["name"] as? String ?? "UP主"
        let pic = dataObj["pic"] as? String
        let videoIdentifier = !bvid.isEmpty ? bvid : "av\(aid)"
        let shortLink = "https://www.bilibili.com/video/\(videoIdentifier)"

        return VideoParseResult(
            url: shortLink,
            resolution: "1080p/高清",
            author: owner,
            title: title,
            thumbnail: pic,
            fileSize: "官方在线流"
        )
    }

    // 引擎：YouTube 基础信息提取
    private static func resolveYouTube(url: String) async throws -> VideoParseResult {
        guard let oembed = URL(string: "https://www.youtube.com/oembed?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)&format=json") else {
            throw NSError(domain: "YouTube", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的 YouTube 链接"])
        }

        let (data, _) = try await URLSession.shared.data(from: oembed)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "YouTube", code: 500, userInfo: [NSLocalizedDescriptionKey: "YouTube 视频信息获取失败"])
        }

        let title = json["title"] as? String ?? "YouTube 视频"
        let author = json["author_name"] as? String ?? "YouTube 创作者"
        let thumb = json["thumbnail_url"] as? String

        return VideoParseResult(
            url: url,
            resolution: "HD/原画",
            author: author,
            title: title,
            thumbnail: thumb,
            fileSize: "流媒体直链"
        )
    }
}
