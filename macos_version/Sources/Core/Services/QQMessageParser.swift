import Foundation

/// QQ 识别出的预定义指令
public enum QQCommand: Equatable {
    case status
    case quota
    case reset
    case help
    case ai(prompt: String)
    case video(url: String)
}

/// QQ 消息解析提取工具，专为 OneBot v11 / NapCat 结构化消息与卡片设计
public struct QQMessageParser {

    /// 解码 CQ 码内转义的特殊字符
    public static func unescapeCQ(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&#44;", with: ",")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#91;", with: "[")
            .replacingOccurrences(of: "&#93;", with: "]")
            .replacingOccurrences(of: "\\/", with: "/")
    }

    /// 从文本或 JSON 卡片数据中提取已知视频平台的 URL (支持 B站/抖音/TikTok/Twitter/YouTube)
    public static func extractVideoUrl(from raw: String) -> String? {
        let text = unescapeCQ(raw)

        // 精准匹配各视频平台，规避周边 JSON 或 XML 杂质
        let patterns = [
            #"https?://(?:www\.)?bilibili\.com/video/(?:BV[a-zA-Z0-9]+|av\d+)(?:[^\s"'\<>\,\}\]]*)?"#,
            #"https?://b23\.tv/[a-zA-Z0-9]+"#,
            #"https?://v\.douyin\.com/[a-zA-Z0-9]+"#,
            #"https?://(?:www\.)?douyin\.com/video/\d+"#,
            #"https?://(?:www\.)?(?:tiktok\.com/@[^/]+/video/\d+|(?:vm|vt)\.tiktok\.com/[a-zA-Z0-9]+)"#,
            #"https?://(?:www\.)?(?:twitter|x)\.com/[a-zA-Z0-9_]+/status/\d+"#,
            #"https?://(?:www\.)?youtube\.com/(?:watch\?v=[a-zA-Z0-9_-]+|shorts/[a-zA-Z0-9_-]+)"#,
            #"https?://youtu\.be/[a-zA-Z0-9_-]+"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                var url = (text as NSString).substring(with: match.range)
                while url.hasSuffix("\"") || url.hasSuffix(",") || url.hasSuffix("}") || url.hasSuffix("]") || url.hasSuffix("\\") || url.hasSuffix("'") {
                    url.removeLast()
                }
                return url
            }
        }

        return nil
    }

    /// 判断消息是否应作为视频解析请求 (卡片消息、纯链接、样板前缀、短标题分享)
    public static func isVideoRequest(raw: String, videoUrl: String?) -> Bool {
        guard let url = videoUrl else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 卡片消息 (Ark / 小程序 / 图文卡片)
        if trimmed.contains("[CQ:json") || trimmed.contains("[CQ:xml") || trimmed.contains("\"app\":\"com.tencent.") {
            return true
        }

        // 2. 显式指令触发
        if trimmed.hasPrefix("/video") || trimmed.hasPrefix("解析") {
            return true
        }

        // 3. 纯链接或标准 App 样板分享文本
        let unescaped = unescapeCQ(trimmed)
        let withoutUrl = unescaped.replacingOccurrences(of: url, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if withoutUrl.isEmpty {
            return true
        }

        // 常见客户端分享字样
        if withoutUrl.contains("复制打开抖音") ||
           withoutUrl.contains("b23.tv") ||
           withoutUrl.contains("bilibili") ||
           (withoutUrl.hasPrefix("【") && withoutUrl.contains("】")) {
            return true
        }

        // 短附言（少于 15 个字）视为随手分享的标题
        if withoutUrl.count <= 15 {
            return true
        }

        // 其余长文本（如“根据此视频做个总结: https://...”）视为 AI 提问
        return false
    }

    /// 提取消息纯净文本（剥除 CQ 码与 @机器人 标签）
    public static func extractPlainText(from raw: String, botUin: Int64, botNickname: String = "") -> String {
        var text = raw

        // 去除 [CQ:at,qq=...]
        if botUin > 0 {
            text = text.replacingOccurrences(of: "[CQ:at,qq=\(botUin)]", with: "")
        }
        text = text.replacingOccurrences(of: #"\[CQ:at,qq=[^\]]+\]"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "@机器人", with: "")
        if !botNickname.isEmpty {
            text = text.replacingOccurrences(of: "@\(botNickname)", with: "")
        }

        // 去除常见的 CQ 标签 [CQ:...]
        text = text.replacingOccurrences(of: #"\[CQ:[^\]]+\]"#, with: "", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 解析指令 (支持大小写容错、前后空格与中文常见别名)
    public static func parseCommand(_ text: String) -> QQCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // 1. 系统宿主状态指令
        if lower == "/status" || lower == "status" || lower == "状态" || lower == "系统状态" || lower == "查看状态" || lower == "运行状态" || lower.hasPrefix("/status ") {
            return .status
        }

        // 2. 额度查询指令
        if lower == "/quota" || lower == "quota" || lower == "/limit" || lower == "limit" || lower == "额度" || lower == "查询额度" || lower == "剩余额度" || lower == "反重力额度" || lower.hasPrefix("/quota ") {
            return .quota
        }

        // 3. 会话重置/清空记忆指令
        if lower == "/reset" || lower == "reset" || lower == "/clear" || lower == "clear" || lower == "重置" || lower == "清空" || lower == "清空记忆" || lower == "重置记忆" || lower == "重置会话" || lower.hasPrefix("/reset ") || lower.hasPrefix("/clear ") {
            return .reset
        }

        // 4. 帮助与功能说明指令
        if lower == "/help" || lower == "help" || lower == "帮助" || lower == "使用说明" || lower == "功能" || lower == "菜单" || lower.hasPrefix("/help ") {
            return .help
        }

        // 5. 显式 AI 指令
        if trimmed.hasPrefix("/ai ") {
            let prompt = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .ai(prompt: prompt)
        }

        // 6. 显式视频解析指令
        if trimmed.hasPrefix("/video ") {
            let url = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .video(url: url)
        } else if trimmed.hasPrefix("解析 ") {
            let url = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .video(url: url)
        }

        return nil
    }
}
