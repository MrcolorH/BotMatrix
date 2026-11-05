import Foundation
import CryptoKit

public struct NapCatLoginStatus: Codable {
    public let isLogin: Bool
    public let isOffline: Bool
    public let loginPhase: String
    public let qrLoginAccepted: Bool
    public let coreReady: Bool
    public let qrcodeurl: String?
    public let loginError: String?
}

public struct NapCatUserInfo: Codable {
    public let uin: String?
    public let nick: String?
    public let online: Bool?
    public let avatarUrl: String?
}

public struct NapCatPasswordResult {
    public let success: Bool
    public let message: String
    public let needCaptcha: Bool
    public let proofWaterUrl: String?
    public let needNewDevice: Bool
    public let jumpUrl: String?
}

public final class NapCatService {
    public static let shared = NapCatService()

    private var cachedCredential: String?
    private var lastCredentialTime: Date?
    private let logger = LogService.shared

    private init() {}

    /// 获取 NapCat 配置文件路径
    private var webUIConfigUrl: URL? {
        let possiblePaths = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/QQ/NapCat/config/webui.json"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Containers/com.tencent.qq/Data/Documents/napcat/config/webui.json"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".tgbot/napcat/config/webui.json")
        ]
        return possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    /// 读取 WebUI 端口与 Token
    public func getWebUIConfig() -> (host: String, port: Int, token: String, autoLoginAccount: String)? {
        guard let url = webUIConfigUrl,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let port = json["port"] as? Int ?? 6099
        let token = json["token"] as? String ?? ""
        let host = "127.0.0.1"
        let autoLogin = json["autoLoginAccount"] as? String ?? ""
        return (host, port, token, autoLogin)
    }

    /// 探测 NapCat WebUI 端口是否就绪
    public func isWebUIReachable() async -> Bool {
        guard let config = getWebUIConfig() else { return false }
        guard let url = URL(string: "http://\(config.host):\(config.port)/api/test") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.httpMethod = "GET"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                return true
            }
        } catch {}
        return false
    }

    /// 认证并获取 Credential
    public func authenticate() async throws -> String {
        if let cred = cachedCredential, let last = lastCredentialTime, Date().timeIntervalSince(last) < 1800 {
            return cred
        }

        guard let config = getWebUIConfig(), !config.token.isEmpty else {
            throw NSError(domain: "NapCatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到 NapCat webui.json 配置或 Token 为空"])
        }

        // NapCat Token 格式: SHA256(token + ".napcat")
        let raw = "\(config.token).napcat"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()

        let loginUrl = URL(string: "http://\(config.host):\(config.port)/api/auth/login")!
        var request = URLRequest(url: loginUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 4.0
        request.httpBody = try JSONSerialization.data(withJSONObject: ["hash": hash])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "NapCatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "NapCat WebUI 握手 HTTP 异常"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataObj = json["data"] as? [String: Any],
              let credential = dataObj["Credential"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "未知错误"
            throw NSError(domain: "NapCatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "NapCat 认证失败: \(msg)"])
        }

        self.cachedCredential = credential
        self.lastCredentialTime = Date()
        return credential
    }

    /// 发起统一经过认证的 POST 请求
    private func postRequest(path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        guard let config = getWebUIConfig() else {
            throw NSError(domain: "NapCatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到 NapCat 配置"])
        }

        var cred = try await authenticate()
        let url = URL(string: "http://\(config.host):\(config.port)/api\(path)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cred)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 6.0
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var (data, response) = try await URLSession.shared.data(for: request)

        // 遇到 401 自动重试一次握手
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            self.cachedCredential = nil
            cred = try await authenticate()
            request.setValue("Bearer \(cred)", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NapCatService", code: -4, userInfo: [NSLocalizedDescriptionKey: "解析 NapCat 响应失败"])
        }
        return json
    }

    /// 获取本机已记住的快速登录 QQ 列表
    public func getQuickLoginList() async throws -> [String] {
        let json = try await postRequest(path: "/QQLogin/GetQuickLoginList")
        if let list = json["data"] as? [String] {
            return list
        }
        if let list = json["data"] as? [NSNumber] {
            return list.map { $0.stringValue }
        }
        return []
    }

    /// 一键快捷免密登录
    public func quickLogin(uin: String) async throws -> Bool {
        logger.info("QQ", "正在向 NapCat 请求一键快速免密登录 (QQ: \(uin))...")
        let json = try await postRequest(path: "/QQLogin/SetQuickLogin", body: ["uin": uin])
        let code = json["code"] as? Int ?? -1
        let msg = json["message"] as? String ?? ""
        if code == 0 || msg == "QQ Is Logined" || msg.localizedCaseInsensitiveContains("logined") {
            logger.success("QQ", "一键登录请求已下发或 QQ 已处于登录在线状态")
            // 同时设为自登账号
            try? await setAutoLoginAccount(uin: uin)
            return true
        } else {
            let msgText = msg.isEmpty ? "未知错误" : msg
            throw NSError(domain: "NapCatService", code: code, userInfo: [NSLocalizedDescriptionKey: msgText])
        }
    }

    /// 设置默认自动登录账号
    public func setAutoLoginAccount(uin: String) async throws {
        _ = try? await postRequest(path: "/QQLogin/SetQuickLoginQQ", body: ["uin": uin])
    }

    /// 账号密码登录
    public func passwordLogin(uin: String, password: String) async throws -> NapCatPasswordResult {
        logger.info("QQ", "正在尝试使用账号密码登录 QQ: \(uin)...")
        let md5 = Insecure.MD5.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
        let json = try await postRequest(path: "/QQLogin/PasswordLogin", body: ["uin": uin, "passwordMd5": md5])
        let code = json["code"] as? Int ?? -1
        let msg = json["message"] as? String ?? ""

        if code == 0 {
            logger.success("QQ", "账号密码验证通过，登录成功！")
            try? await setAutoLoginAccount(uin: uin)
            return NapCatPasswordResult(success: true, message: "登录成功", needCaptcha: false, proofWaterUrl: nil, needNewDevice: false, jumpUrl: nil)
        }

        if msg == "QQ Is Logined" {
            logger.info("QQ", "NapCat 提示 QQ 已经处于登录在线状态")
            try? await setAutoLoginAccount(uin: uin)
            return NapCatPasswordResult(success: true, message: "QQ 当前已处于登录状态", needCaptcha: false, proofWaterUrl: nil, needNewDevice: false, jumpUrl: nil)
        }

        let data = json["data"] as? [String: Any]
        let needCaptcha = data?["needCaptcha"] as? Bool ?? false
        let proofWaterUrl = data?["proofWaterUrl"] as? String
        let needNewDevice = data?["needNewDevice"] as? Bool ?? false
        let jumpUrl = data?["jumpUrl"] as? String

        return NapCatPasswordResult(
            success: false,
            message: msg.isEmpty ? "登录失败" : msg,
            needCaptcha: needCaptcha,
            proofWaterUrl: proofWaterUrl,
            needNewDevice: needNewDevice,
            jumpUrl: jumpUrl
        )
    }

    /// 获取登录二维码 URL
    public func getQRCode() async throws -> String {
        let json = try await postRequest(path: "/QQLogin/GetQQLoginQrcode")
        if let data = json["data"] as? [String: Any], let qrcode = data["qrcode"] as? String {
            return qrcode
        }
        let msg = json["message"] as? String ?? "获取二维码失败"
        throw NSError(domain: "NapCatService", code: -5, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    /// 刷新二维码
    public func refreshQRCode() async throws -> String {
        let json = try await postRequest(path: "/QQLogin/RefreshQRcode")
        if let data = json["data"] as? [String: Any], let qrcode = data["qrcodeurl"] as? String {
            return qrcode
        }
        let msg = json["message"] as? String ?? "刷新二维码失败"
        throw NSError(domain: "NapCatService", code: -6, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    /// 轮询检测当前 QQ 登录阶段
    public func checkLoginStatus() async throws -> NapCatLoginStatus {
        let json = try await postRequest(path: "/QQLogin/CheckLoginStatus")
        guard let data = json["data"] as? [String: Any] else {
            throw NSError(domain: "NapCatService", code: -7, userInfo: [NSLocalizedDescriptionKey: "无法解析登录状态"])
        }
        let isLogin = data["isLogin"] as? Bool ?? false
        let isOffline = data["isOffline"] as? Bool ?? false
        let loginPhase = data["loginPhase"] as? String ?? ""
        let qrLoginAccepted = data["qrLoginAccepted"] as? Bool ?? false
        let coreReady = data["coreReady"] as? Bool ?? false
        let qrcodeurl = data["qrcodeurl"] as? String
        let loginError = data["loginError"] as? String

        return NapCatLoginStatus(
            isLogin: isLogin,
            isOffline: isOffline,
            loginPhase: loginPhase,
            qrLoginAccepted: qrLoginAccepted,
            coreReady: coreReady,
            qrcodeurl: qrcodeurl,
            loginError: loginError
        )
    }

    /// 获取当前已登录的账号详情
    public func getLoginInfo() async throws -> NapCatUserInfo? {
        let json = try await postRequest(path: "/QQLogin/GetQQLoginInfo")
        guard let data = json["data"] as? [String: Any] else { return nil }
        let uin = (data["uin"] as? String) ?? ((data["uin"] as? NSNumber)?.stringValue)
        let nick = data["nick"] as? String
        let online = data["online"] as? Bool
        let avatarUrl = data["avatarUrl"] as? String
        return NapCatUserInfo(uin: uin, nick: nick, online: online, avatarUrl: avatarUrl)
    }
}
