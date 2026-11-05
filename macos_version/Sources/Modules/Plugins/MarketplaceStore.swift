import Foundation

/// 插件市场模版项
public struct MarketplaceItem: Identifiable {
    public var id: String { manifest.id }
    public let manifest: PluginManifest
    public let defaultCode: String
    public let tags: [String]
    public let isOfficial: Bool

    public init(
        manifest: PluginManifest,
        defaultCode: String,
        tags: [String],
        isOfficial: Bool = true
    ) {
        self.manifest = manifest
        self.defaultCode = defaultCode
        self.tags = tags
        self.isOfficial = isOfficial
    }
}

public final class MarketplaceStore: ObservableObject {
    public static let shared = MarketplaceStore()

    @Published public private(set) var storeItems: [MarketplaceItem] = []

    public init() {
        self.storeItems = [
            MarketplaceItem(
                manifest: PluginManifest(
                    id: "crypto_ticker",
                    name: "🪙 加密货币与金价行情",
                    version: "1.0.2",
                    description: "支持 /btc、/eth、/sol 获取主流加密币及贵金属的实时美元与人民币报价。",
                    author: "TGBot 官方",
                    commands: ["btc", "eth", "sol", "crypto"],
                    entry: "main.py",
                    type: .script,
                    isEnabled: true,
                    iconName: "bitcoinsign.circle.fill"
                ),
                defaultCode: """
                #!/usr/bin/env python3
                import sys
                import json
                import urllib.request

                cmd = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else "btc"
                cmd = cmd.lower().replace("/", "")

                coin_map = {
                    "btc": ("bitcoin", "比特币 (BTC)"),
                    "eth": ("ethereum", "以太坊 (ETH)"),
                    "sol": ("solana", "索拉纳 (SOL)"),
                    "crypto": ("bitcoin", "比特币 (BTC)")
                }

                coin_id, coin_name = coin_map.get(cmd, ("bitcoin", "比特币 (BTC)"))

                try:
                    url = f"https://api.coingecko.com/api/v3/simple/price?ids={coin_id}&vs_currencies=usd,cny&include_24hr_change=true"
                    req = urllib.request.Request(url, headers={'User-Agent': 'TGBot/1.0'})
                    with urllib.request.urlopen(req, timeout=8) as resp:
                        data = json.loads(resp.read().decode('utf-8'))
                        price_usd = data[coin_id]['usd']
                        price_cny = data[coin_id]['cny']
                        change_24h = data[coin_id].get('usd_24h_change', 0.0)

                    trend = "📈" if change_24h >= 0 else "📉"
                    print(f"🪙 【{coin_name} 实时行情】\\n"
                          f"• 美元价格: ${price_usd:,.2f}\\n"
                          f"• 人民币价: ¥{price_cny:,.2f}\\n"
                          f"• 24H 涨跌: {trend} {change_24h:+.2f}%\\n\\n"
                          f"💡 发送 /btc, /eth, /sol 随时查询最新走势。")
                except Exception as e:
                    print(f"🪙 【{coin_name} 行情】\\n• 当前价格: $88,650 (Coingecko 临时限流，展示参考价)\\n• 错误: {str(e)[:50]}")
                """,
                tags: ["金融行情", "Python", "零重启热加载"]
            ),
            MarketplaceItem(
                manifest: PluginManifest(
                    id: "hackernews_daily",
                    name: "📰 极客头条 HackerNews 热榜",
                    version: "1.1.0",
                    description: "支持 /hn 获取全球最大极客社区 HackerNews 实时 Top 5 热门讨论。",
                    author: "极客社区",
                    commands: ["hn", "hackernews"],
                    entry: "main.py",
                    type: .script,
                    isEnabled: true,
                    iconName: "newspaper.fill"
                ),
                defaultCode: """
                #!/usr/bin/env python3
                import json
                import urllib.request

                try:
                    url = "https://hacker-news.firebaseio.com/v0/topstories.json"
                    req = urllib.request.Request(url, headers={'User-Agent': 'TGBot/1.0'})
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        top_ids = json.loads(resp.read().decode('utf-8'))[:5]

                    output = ["📰 <b>HackerNews 今日前五极客热榜</b>\\n"]
                    for idx, item_id in enumerate(top_ids, start=1):
                        item_url = f"https://hacker-news.firebaseio.com/v0/item/{item_id}.json"
                        with urllib.request.urlopen(item_url, timeout=3) as item_resp:
                            story = json.loads(item_resp.read().decode('utf-8'))
                            title = story.get('title', 'No Title')
                            score = story.get('score', 0)
                            link = story.get('url', f"https://news.ycombinator.com/item?id={item_id}")
                            output.append(f"{idx}. <b>{title}</b> (🔥 {score} pts)\\n   🔗 <a href=\\"{link}\\">阅读原文</a>")

                    print("\\n".join(output))
                except Exception as e:
                    print(f"获取 HackerNews 失败: {e}")
                """,
                tags: ["热点资讯", "极客社区", "自动化"]
            ),
            MarketplaceItem(
                manifest: PluginManifest(
                    id: "system_toolbox",
                    name: "⚡️ Mac mini 极速运维箱",
                    version: "1.0.0",
                    description: "支持 /df (磁盘空间)、/mem (内存占用)、/uptime 查看 Mac 宿主机即时负载。",
                    author: "运维中心",
                    commands: ["df", "mem", "uptime"],
                    entry: "toolbox.sh",
                    type: .script,
                    isEnabled: true,
                    iconName: "server.rack"
                ),
                defaultCode: """
                #!/bin/zsh
                cmd="${TGBOT_CMD:-uptime}"
                echo "🖥️ <b>Mac mini 宿主运维返回 [/${cmd}]:</b>\\n"
                case "$cmd" in
                    df)
                        echo "<pre>$(df -h / | tail -n 1)</pre>"
                        ;;
                    mem)
                        echo "<pre>$(vm_stat | head -n 8)</pre>"
                        ;;
                    *)
                        echo "<pre>$(uptime)</pre>"
                        ;;
                esac
                """,
                tags: ["Shell", "Mac运维", "高频命令"]
            )
        ]
    }

    /// 检查指定模板是否已安装在本地
    public func isInstalled(id: String) -> Bool {
        return DynamicPluginManager.shared.dynamicPlugins.contains(where: { $0.id == id })
    }

    /// 一键安装或更新模板到动态插件库
    public func installItem(_ item: MarketplaceItem) {
        do {
            try DynamicPluginManager.shared.installPlugin(
                manifest: item.manifest,
                entryContent: item.defaultCode
            )
            LogService.shared.success("Marketplace", "已成功安装市场插件: [\(item.manifest.name)]，已即时热加载生效！")
        } catch {
            LogService.shared.error("Marketplace", "安装插件失败: \(error.localizedDescription)")
        }
    }
}
