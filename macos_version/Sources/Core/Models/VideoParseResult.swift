import Foundation

public struct VideoParseResult: Identifiable, Equatable {
    public let id = UUID()
    public let url: String
    public let resolution: String
    public let author: String
    public let title: String
    public let thumbnail: String?
    public var fileSize: String?

    public init(
        url: String,
        resolution: String,
        author: String,
        title: String,
        thumbnail: String? = nil,
        fileSize: String? = nil
    ) {
        self.url = url
        self.resolution = resolution
        self.author = author
        self.title = title
        self.thumbnail = thumbnail
        self.fileSize = fileSize
    }

    public var cleanFilename: String {
        var clean = title
            .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[@#]\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^\w\u4e00-\u9fa5\s_-]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)

        if clean.count > 40 {
            clean = String(clean.prefix(40))
        }
        if clean.isEmpty {
            clean = "twitter_video"
        }
        return "\(author)_\(clean).mp4"
    }
}
