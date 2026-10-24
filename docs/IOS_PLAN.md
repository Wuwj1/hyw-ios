# 何意味 iOS 版 迁移矩阵与阶段计划

日期：2026-10-23 ｜ 基线：Android 版 34 个 Java 文件 / 约 7,900 行 / 原生 View

## 一、迁移矩阵

| Android 模块 | 实现方式 | iOS 判定 | 做法 |
|---|---|---|---|
| 游戏库卡片（GridAdapter + MainActivity） | 自定义 View + GridView | **重写** | SwiftUI `LazyVGrid`，视觉照原样 |
| Game 数据模型 | JSON 存 filesDir | **直接迁移** | 字段与 kind 编号完全一致，`games.json` 双向兼容 |
| 添加游戏（选目录） | java.io.File + 自建浏览器 | **重写** | `UIDocumentPicker` + security-scoped bookmark |
| 目录扫描（Scanner） | File.listFiles 递归 | **重写** | 只能在授权目录内遍历，逻辑相同 |
| 封面/截图 | Bitmap + File | **重写** | `UIImage(contentsOfFile:)` + 缓存 |
| 弹窗体系（Ui.card / Ui.sheet） | 手绘 Dialog | **重写** | SwiftUI sheet，无边框平铺风格保持 |
| 502 站搜索 | WebView + sites.json | **直接迁移** | `WKWebView` + 同一份 502 条 sites.json |
| 站点列表/抽屉 | ListView | **重写** | SwiftUI List |
| 下载管理器（Dl + DownloadsActivity） | HttpURLConnection + .part | **重写** | `URLSessionDownloadTask`，落 Documents/Downloads |
| 更新检查（Updater + latest.json） | 应用内下载 APK | **不可用** | iOS 不允许自更新；改为"提示去侧载源" |
| 公告弹窗 | 卡片 | **重写** | 同视觉，数据仍读 latest.json 的 notes |
| QQ 群跳转 | `mqqapi://` scheme | **不可行** | 改成复制群号 / 二维码 |
| 引擎设置页（KrkrSettingsActivity） | 自定义 | **待定** | 等引擎真正接入后再定选项 |
| KRKR（TY Kirikiroid139） | Activity + libgame.so | **移植内核** | 上游 krkrsdl3 支持 iOS，需自写宿主层 |
| ONS（assets/ons_engine.apk 外部 APK） | 拉起 com.yuri.onscripter | **移植内核** | ONScripter C++ 源码编 iOS 静态库 |
| JoiPlay | 跳外部 App | **不支持** | iOS 无对应应用；UI 保留"待移植"标注 |
| Maldives | 跳外部 App | **不支持** | 同上 |
| PPSSPP | 跳外部 App | **待评估** | iOS 有 PPSSPP 但无对外 URL 接口 |
| Windows / Winlator | 外置直启版 | **移除** | 按要求完全不做；kind=6 读到时跳过 |
| 存储权限（MANAGE_EXTERNAL_STORAGE） | Android 专属 | **移除** | 换成 bookmark 授权模型 |

## 二、分阶段

### 阶段 1（当前，不需要 Mac 即可完成 80%）

- [x] 工程骨架：`project.yml`（XcodeGen）、目录结构、Info.plist
- [x] Core：Game / GameStore / BookmarkStore / Sites / Downloader / FeatureFlags
- [x] 界面：游戏库、添加游戏、502 站、下载、设置
- [x] 引擎协议 + KRKR / ONS 接入位（明确"未接入"，无假实现）
- [x] 目录识别（KRKR/ONS 打分）、封面候选与沙盒保存、封面更换
- [x] 游戏库：搜索 / 排序 / 重命名 / 删除
- [x] 下载：URLSession + WKDownload，落 Documents/Downloads（第一版不解压）
- [x] 设置 / 关于 / 开源许可页（读 LICENSES 资源）
- [ ] 在 Mac 上 `xcodegen generate` + 真机跑通（需要 Mac）
- [x] 卡片长按菜单（重命名 / 换封面 / 删除）

验收：iOS 上能浏览站点、下载文件、把游戏目录加成卡片并显示。

### 阶段 2（需要 Mac）——KRKR 技术验证（顺序固定）

```
第1步  编译何意味纯 SwiftUI 工程，解决所有 Swift / Xcode 错误
第2步  单独编译官方 krkrsdl3.app（cmake --preset "iOS Device Config"）
第3步  真机跑官方 krkrsdl3 + 一个最小 KRKR 游戏 → 验收 A
第4步  把 native host（hmy_krkr_host.mm）接进何意味，先解决编译 / 链接
第5步  真机：何意味 → KRKR 卡片 → 游戏画面 → 退出 → 回何意味 → 验收 B
```

两个验收的界定（不能混为一谈）：

| 验收 | 内容 | 证明了什么 | 没证明什么 |
|---|---|---|---|
| **A** | 官方 `.app` 在 iPhone 上打开游戏目录能出画面 | 上游 krkrsdl3 的 iOS 支持有效、渲染/音频/输入链路可用 | 能否嵌入已有 SwiftUI App（它走的是 SDL 自己的 UIApplicationMain） |
| **B** | 何意味 → 卡片 → 宿主 → 游戏 → 退出回到何意味 | 产品形态成立 | —— |

B 的失败点集中在 `docs/KRKR_IOS_LIFECYCLE.md` 的 MAC-1~8（AppDelegate、生命周期、窗口归属、销毁顺序），
和引擎本身无关。**A 通过不等于 B 只是打包问题。**

**B 不通过就不做 UI 适配**，直接按 MAC 清单的最小边界改宿主，或讨论换核心。

### 阶段 3——ONS

ONScripter 源码 → iOS 静态库 → 桥接 `OnsEngine`。验收同上四级。

### 阶段 4——对齐 Android 细节

封面抓取、排序、最近启动、公告弹窗、引擎设置项、KRKR 在线补丁（视情况）。

## 三、模块化约定

- 站点搜索由 `FeatureFlags.siteSearch` 控制，取值来自 Info.plist `HMY_SITE_SEARCH`
- App Store 版：构建时把该键置 false，或用 xcconfig 覆盖，**不新增工程**
- 引擎全部走 `GameEngine` 协议，缺哪个引擎只影响对应 kind 的卡片

## 四、明确不做

- Android APK 转 IPA 的任何方案
- Windows / Wine / Box64 / DXVK / Turnip
- Windows 游戏类型、Winlator 入口、.exe 选择
- 假启动（引擎未就绪时点卡片只提示，不进黑屏）
