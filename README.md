# 币安灵动岛 (BinanceIsland)

在 iPhone 灵动岛 / 锁屏「实时活动」上显示币安实时价格（iOS 16.2+）。

## 获取 IPA（无需 Mac）
1. 把本项目推到你自己的 GitHub 仓库。
2. GitHub → Actions → **Build unsigned IPA** 会在每次 push 时自动运行（也可手动 Run workflow）。
3. 运行完成后，在该次运行页面底部 Artifacts 下载 `BinanceIsland-ipa`（zip 内即 `BinanceIsland.ipa`）。
4. 推送 `v1.0.0` 这类 tag 时会自动创建 Release 并附带 ipa。

工程用 XcodeGen（`project.yml`）在 CI 上生成，仓库内不含 `.xcodeproj`。

## 安装 / 签名
IPA 未签名，请自行签名安装：
- **Sideloadly / 爱思助手**：用 Apple ID 免费签名（7 天有效，需定期重签）。签名时保持 App 与小组件扩展（PlugIns/BinanceIslandWidget.appex）一起签名。
- **TrollStore**：支持的系统版本可直接安装，永久有效。
- 实时活动 **不需要特殊 entitlement**，免费签名即可使用（推送更新才需要 aps-environment）。
- Bundle ID：`com.uzi.binanceisland`，扩展：`com.uzi.binanceisland.widget`。免费签名工具若改了主 ID，扩展 ID 需保持为「主 ID + .widget」前缀关系（Sideloadly 一般自动处理）。

## 使用
- 默认交易对 BTCUSDT、ETHUSDT，可添加如 SOLUSDT，左滑删除，列表保存在本地。
- 点选某一行或用「显示交易对」选择灵动岛显示的币种，点「开始」启动实时活动，「停止」结束。
- 「红涨绿跌」开关默认开启（中国习惯），关闭则为绿涨红跌。
- 「数据源」：binance.com 被屏蔽时可切换到 `data-api.binance.vision` 或 `binance.us`（注意 binance.us 交易对较少）。
- 若无法启动：设置 → 币安灵动岛 → 允许「实时活动」。

## 数据
优先使用 WebSocket `miniTicker` 组合流；失败时自动改为每 2 秒 REST 轮询 `/api/v3/ticker/24hr`，并每约 30 秒尝试重连 WebSocket。灵动岛更新限流约每秒一次，每次更新设置 60 秒 staleDate。

## 后台限制（重要）
iOS 不允许普通 App 在后台常驻网络连接。本应用只在前台保持 WebSocket；切到后台时申请后台任务时间（通常约 30 秒），之后 App 被挂起，灵动岛会停留在最后价格并在 60 秒后显示为过期。回到 App 即恢复。
本项目**没有**滥用后台音频等手段。若要在后台持续更新，需要一台服务器通过 **APNs 推送** 更新实时活动（需付费开发者账号的推送证书，属于后续可选功能）。
