# 何意味 iOS 版（侧载）

真正的 iOS 原生版，不是 APK 转 IPA。Android 版工程不参与本目录，两边独立构建。

## 目录

```
project.yml            XcodeGen 工程定义（不手写 pbxproj）
HeYiWei/App            入口、主题、底部导航（游戏 / 搜索 / 设置）
HeYiWei/Core           Game / GameStore / Bookmarks / Sites / Downloader / FeatureFlags
HeYiWei/Engines        GameEngine 协议、EngineRegistry、KrkrEngine、OnsEngine、Bridge/hmy_krkr.h
HeYiWei/Features       游戏库、添加游戏、搜索、下载、设置
HeYiWei/Resources      Info.plist、sites.json（与 Android 同一份，502 条）
docs/                  追查报告、iOS 宿主分析、迁移矩阵
LICENSES/              许可证全文 + 开源声明
```

## 当前状态（2026-10-23）

| 项 | 状态 |
|---|---|
| 游戏库（搜索 / 排序 / 重命名 / 删封面） | 已写源码，**未编译** |
| 添加游戏（选目录 → 识别 KRKR/ONS → 选封面 → 落库） | 已写源码，**未编译** |
| 封面（候选 / 复制进沙盒 / 更换） | 已写源码，**未编译** |
| 502 站 + WKWebView | 已写源码，**未编译** |
| 下载（URLSession + WKDownload，落 Documents/Downloads） | 已写源码，**未编译** |
| 设置 / 关于 / 开源许可页 | 已写源码，**未编译** |
| Game 模型与 Android kind 编号兼容 | 已实现（kind=6 Windows 读到时过滤） |
| KRKR | 接口已留，宿主未实现，isAvailable = false |
| ONS | 接口已留，ONScripter 未移植 |
| Windows / Winlator | 按需求不存在 |

## 在 Mac 上跑

```bash
brew install xcodegen
cd hmy-ios
xcodegen generate
open HeYiWei.xcodeproj
```

## 文档索引

```
THIRD_PARTY.md              上游版本锁定（krkrsdl3 dd1de3d2 / krkrsdl3_build 6059f785）
docs/KRKR_SOURCE_REPORT.md  libkrkrsdl3.so 源码追查结论
docs/KRKR_IOS_HOST.md       iOS 宿主分析：入口、参数、渲染、音频、存档、构建步骤
docs/KRKR_IOS_LIFECYCLE.md  SDL3 iOS 生命周期调查（为什么不用 EnterAppMainCallbacks）
docs/IOS_PLAN.md            迁移矩阵与阶段计划（验收 A / B 顺序）
docs/IOS_APP_FEATURES.md    App 本体：识别规则、添加流程、下载流程、Mac 待确认项
LICENSES/                   许可证全文与开源声明
HeYiWei/Engines/Bridge/     hmy_krkr.h（C 契约）+ hmy_krkr_host.mm（宿主第一版，未编译）
```

## 构建前必读

没有 macOS 就无法编译、签名、真机验证。这里所有 Swift 代码**尚未编译过**，
只能保证结构完整；第一次 xcodegen generate 之后的编译错误需要逐条修。
