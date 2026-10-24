# iOS App 本体功能说明（不含引擎）

日期：2026-10-23 ｜ 状态：源码完成，未编译

## 1. 文件权限模型：不做全盘扫描

Android 版靠 `MANAGE_EXTERNAL_STORAGE` 扫全盘；iOS 没有这个概念，照搬必然失败。

iOS 版规则：

```
用户用「文件」App 或 UIDocumentPicker 选一个文件夹
  → 何意味立刻分析这个文件夹（识别类型 + 找封面）
  → 保存 security-scoped bookmark（下次启动还能访问）
  → 游戏卡片只记录 path + bookmark id
```

- 没有任何"扫描整机"的入口
- 撤销授权（用户删 App / 移动目录）后，bookmark 解析失败 → 卡片提示"目录不可访问"
- 封面**复制进沙盒**（`Application Support/HeYiWei/Covers/<id>.jpg`），
  避免外部目录失效后封面一起消失

## 2. 目录识别规则

打分制，不靠单一特征下结论（`Core/GameDetector.swift`）。

### KRKR

| 特征 | 分 |
|---|---|
| 根目录 `startup.tjs` | +60 |
| 根目录 `data.xp3` | +30 |
| 任意 `.xp3` | 每个 +10（上限 30） |
| 任意 `.ks` 脚本 | +10 |
| 有 `.tjs` 但无 `startup.tjs` | +8 |

### ONS

| 特征 | 分 |
|---|---|
| `nscript.dat` | +60 |
| `nscript.___` / `nscript.dat.bak` | +40 |
| `arc.nsa` | +30 |
| 任意 `.nsa` | 每个 +8（上限 20） |
| `.ns2` / `.ns3` 脚本 | +25 |
| `0.txt` + `1.txt` 同时存在 | +10 |

判定：两边谁分高按谁；置信度 `≥60 高 / ≥25 中 / 其余 低`。
**弱置信度时 UI 会提示并允许手动改类型**，不会硬判。

> 只扫两层目录（根 + 一层子目录），避免在大目录上做全量遍历。

## 3. 添加游戏流程

```
+ → 选择文件夹（系统选择器）
  → Importer.analyze(url)
       校验：是目录 / 非空 / 不是压缩包
       识别：GameDetector
       封面：CoverStore.candidates（cover.* > title.* > icon.* > 大图）
  → 确认页：标题（可改）/ 类型（可改）/ 封面（可选候选图）
  → Importer.commit
       BookmarkStore.save(目录授权)
       CoverStore.save(复制封面)
       GameStore.add(写 games.json)
```

## 4. 游戏库

- 网格卡片：封面 + 标题 + 类型徽标（KRKR / ONS / 外部应用 / 待移植）
- 搜索：按标题过滤
- 排序：最近启动 / 名称 / 添加顺序（存 UserDefaults，不写进 games.json）
- 长按菜单：重命名 / 更换封面 / 删除
- 删除时同时清 bookmark（封面文件保留，避免误删用户图）

## 5. 封面

- 来源：游戏目录内的图片，或用户从「文件」挑一张图
- 存储：复制到沙盒，`Game.cover` 记沙盒绝对路径
- 显示：`UIImage(contentsOfFile:)`，失败则占位图标（不做磁盘缓存层，图片量小）

## 6. 下载

第一版**不做自动解压**：

```
WKWebView 页面触发下载 / 手动 URLSession 下载
  → 文件落到 Documents/Downloads（UIFileSharingEnabled=true，文件 App 可见）
  → 用户在文件 App 里用系统解压，或第三方解压 App
  → 回到何意味 → + → 选解压出来的文件夹
```

- `DownloadsView` 分两段：进行中（URLSession 任务）+ 已下载（扫描目录，含 WKDownload 落地的文件）
- 已下载项支持分享（交给解压 App）、左滑删除
- 后续确认 ZIP 解压稳定后，再加"下载完成 → 自动解压 → 直接添加"

## 7. 数据兼容

`Game` 的 JSON 键名与 `kind` 编号完全沿用 Android（0 KRKR / 1 ONS / 2 EXTERNAL / 3 JOIPLAY / 4 PPSSPP / 5 MALDIVES / 6 Windows）。

- 读到 `kind=6`（Windows）→ 过滤掉、不显示，**不改编号含义**
- 读到 iOS 不支持的类型 → 显示"不支持"提示，不崩
- iOS 新增字段不写回 Android 无法识别的键（当前只有 cover 复用原字段）

## 8. 本轮源码清单

| 文件 | 作用 |
|---|---|
| `Core/AppPaths.swift` | 沙盒路径 |
| `Core/GameDetector.swift` | KRKR/ONS 识别 |
| `Core/CoverStore.swift` | 封面候选 / 保存 / 读取 |
| `Core/GameStore.swift` | 库、排序、增删改 |
| `Core/Importer.swift` | 分析 → 落库 |
| `Core/Downloader.swift` | URLSession 下载 |
| `Core/BookmarkStore.swift` | security-scoped bookmark |
| `Features/Library/*` | 库、卡片、添加、封面选择 |
| `Features/Search/*` | 站点列表 + WKWebView（含 WKDownload） |
| `Features/Downloads/DownloadsView.swift` | 下载与已下载文件 |
| `Features/Settings/*` | 设置、关于、开源许可 |

## 9. 仍必须 macOS 才能确认的事项

1. `xcodegen generate` 后工程能否一次编过（Swift 语法 / API 版本）
2. `.fileImporter(allowedContentTypes: [.folder])` 在真机上的实际行为（iCloud Drive / 本地 / 第三方网盘差异）
3. security-scoped bookmark 在**重启 App 后**是否仍可解析（沙盒路径会变）
4. `WKDownload` 落地到 Documents 是否被系统允许（首次可能弹权限）
5. 文件 App 是否能看到 Documents/Downloads（`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`）
6. 资源打包：Licenses 两个 txt 是"打平到 bundle 根"还是"保留子目录"（代码两种都试了）
7. 真实游戏目录里封面候选的排序是否符合预期（这张表是按常见命名猜的，需要真游戏验证）
