# 开水记账（KaiShuiLedger）

iOS 准自动记账 App：**付款完轻点手机背面两下，截屏 OCR 解析支付页，自动写账**。带桌面小组件、图表看板、CSV 导出。纯本地存储，不需要服务器。

## 功能

- 今日支出 / 本月累计 / 近 14 天趋势图 / 本月分类汇总（Swift Charts）
- 明细按天分组，左滑删除
- 桌面小组件（WidgetKit，每 30 分钟刷新）
- **快捷指令深度集成（App Intents）**：`从支付页文本记账` / `记一笔支出` 两个动作，快捷指令可以直接调
- CSV 导出
- 数据存 App Group JSON，App、小组件、快捷指令三端共享

## 目录结构

```
KaiShuiLedger/
├── project.yml                 # XcodeGen 工程描述（不要手工建 xcodeproj）
├── Sources/
│   ├── App/                    # App 入口
│   ├── Shared/                 # 数据模型 + 存储 + 分类引擎（App/小组件共用）
│   ├── Views/                  # SwiftUI 界面
│   └── Intents/                # App Intents（快捷指令入口 + OCR 文本解析）
├── Widget/                     # WidgetKit 小组件
├── Support/                    # Info.plist 参数与 App Group entitlements
└── .github/workflows/build.yml # GitHub Actions 云端打包未签名 IPA
```

## 没有 Mac 怎么打包（你的情况）

**第 1 步：推到 GitHub**
把整个 `KaiShuiLedger` 文件夹推到一个 GitHub 仓库（`.github` 目录必须带上去）。

**第 2 步：云端编译**
仓库页面 → Actions → `Build unsigned IPA` → Run workflow。
跑完后在该次运行页面底部下载 artifact `KaiShuiLedger-unsigned-ipa`，得到 `KaiShuiLedger-unsigned.ipa`。

**第 3 步：本地签名（Sideloadly）**
1. Sideloadly 里拖入这个 IPA
2. Apple ID 填 `8619954453884`
3. 密码填 **App 专用密码**（appleid.apple.com → 登录与安全性 → App 专用密码）
4. Start，等它自动签名 + 装进手机

**第 4 步：手机信任**
设置 → 通用 → VPN 与设备管理 → 开发者 APP → 选你的 Apple ID → 信任。

> 免费签名 7 天过期。过期后 IPA 还在，Sideloadly 重签一遍即可，数据不丢。

## 快捷指令配置（自动记账核心）

**① 手机上新建快捷指令**（快捷指令 App → 右上角 + ）：

| # | 动作 | 参数 |
|---|------|------|
| 1 | 拍摄屏幕快照 | 无 |
| 2 | 从输入提取文本 | 语言：简体中文 |
| 3 | App → 开水记账 → 从支付页文本记账 | OCR文本 = 上一步的「提取的文本」 |

保存，命名为 **「记一笔」**。

**② 绑定轻点背面**：
设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 快捷指令 → 记一笔。

**③ 使用**：微信/支付宝付款完成停在成功页 → **轻点手机背面两下** → 弹通知「已记 ¥xx.xx · 商户 · 分类」。

**可选**：加第 4 个动作「显示通知」把结果常驻通知栏；也可以把该快捷指令加到分享面板，付款页截屏后走分享 → 记一笔。

## 使用说明

- 手动记账：App 内右上角 ＋
- 分类自动打标：写入时按商户关键词匹配（瑞幸→餐食、滴滴→交通、话费→通讯……），手改分类在记一笔表单里选
- 导出：设置 → 导出 CSV 账单

## 常见问题

**签名时报 App Group 相关错误**
免费账号一般没问题；若报错，打开 `project.yml` 删掉 `LedgerWidget` 整段和 App 的 `dependencies` 两行，重新跑 Actions，得到不带小组件的版本。

**OCR 识别不到金额**
支付成功页要完整露出 `¥xx.xx`。快捷指令里 OCR 语言必须选简体中文。

**小组件不更新**
长按小组件 → 编辑 → 无需配置；小组件每 30 分钟自动刷新，点一下 App 里的记录会立即刷新。

**想在真机调试（有 Mac 的话）**
装 XcodeGen → `xcodegen generate` → 打开 `KaiShuiLedger.xcodeproj` → 选个人 Team → Run。
