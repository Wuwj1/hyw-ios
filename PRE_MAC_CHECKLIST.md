# PRE_MAC_CHECKLIST

日期：2026-10-23 ｜ 范围：iOS App 本体（不含引擎）｜ 状态：源码收口完成，**未编译**

---

## 1. 已修的潜在问题

| # | 问题 | 修法 |
|---|---|---|
| 1 | `GameStore.load()` 直接过滤 `kind=6`，iOS 保存后会把 Android 的 Windows 卡片永久写丢 | 读盘/存盘**完整保留**所有记录；只有 UI 用 `availableGames` 过滤 |
| 2 | 删除游戏后沙盒里的封面副本残留 | `remove()` 增加 `removeCoverCopy`，只删 `Application Support/HeYiWei/Covers/` 下的文件，外部原图不动 |
| 3 | bookmark 过期（stale）后不重建，下次仍失败 | `resolve` 检测 stale → 立刻 `save` 重建；彻底解析失败则清掉该条，避免反复报错 |
| 4 | `save()` 在 `startAccessing` 返回 false 时直接放弃建 bookmark | 改为照常尝试建 bookmark（能否访问是 resolve 时才知道） |
| 5 | 下载同名文件会静默覆盖 | 新增 `AppPaths.uniqueFile`，URLSession 与 WKDownload 共用，重名生成 `(1) name` |
| 6 | `games.json` 写入是否可能写坏 | 确认使用 `Data.write(options: .atomic)`，异常退出不会留半截文件 |
| 7 | `WKWebView` delegate 回调直接改 `@MainActor` 的 `WebState` | `WebState` 去掉 `@MainActor`，所有状态变更统一 `DispatchQueue.main.async` |
| 8 | `AddGameView` 作为 sheet 打开时可能拿不到 `EnvironmentObject` | sheet 内显式 `.environmentObject(store)`（`CoverPickerView` 原本就有） |
| 9 | `Importer.commit` 复制封面时没开 security scope，外部目录会被拒 | 复制前后 `start/stopAccessingSecurityScopedResource` |
| 10 | `CoverPickerView` 用 `URL(string: "file://" + path)` 构造，中文路径会失败 | 改 `URL(fileURLWithPath:)` |
| 11 | `LicenseView` 假定资源保留子目录 | 同时尝试 `subdirectory: "Licenses"` 与 bundle 根 |
| 12 | `Game.subtitle` 对 kind=6 落到"未知" | 明确显示 `Windows（iOS 不支持）`，编号含义不变 |
| 13 | `project.yml` 未声明桥接头与头文件路径 | 补 `SWIFT_OBJC_BRIDGING_HEADER` + `HEADER_SEARCH_PATHS` |
| 14 | ObjC++ host 会被第一轮编译拉进来，报一堆 SDL3 找不到 | `sources.excludes` 排除 `Engines/Bridge/hmy_krkr_host.mm`（见第 4 节） |
| 15 | Info.plist 缺少加密声明 / iPad 方向 | 补 `ITSAppUsesNonExemptEncryption=false`、`UIApplicationSupportsIndirectInputEvents`、`UISupportedInterfaceOrientations~ipad` |

静态检查结果：

```
Swift 文件 26 个 / 1581 行
类型重复定义        无（40 个类型）
成员引用不一致      无（store./downloads./game./draft. 全量比对）
security-scoped     4 个文件，start/stop 全部配对
@MainActor          仅 GameStore、Downloader
部署目标            17.0，所用 API 均 ≤ 17（ContentUnavailableView 需要 17）
```

---

## 2. 只能等 Xcode / 真机暴露的问题

1. **编译期**：Swift 语法、协议一致性、`async`/隔离告警在 `SWIFT_STRICT_CONCURRENCY=minimal` 下的真实等级
2. **XcodeGen 资源归属**：`Resources/Licenses/*.txt` 到底被打平还是保留目录（代码两种都试了，但哪种生效要跑一次才知道）
3. **EnvironmentObject 注入链**：sheet / NavigationLink 在真机的继承行为（已显式注入，但没编译过）
4. **安全作用域**：`.fileImporter([.folder])` 在 iCloud Drive、本地「我的 iPhone」、第三方网盘上的差异
5. **bookmark 跨重启**：沙盒容器路径变化后能否解析（这是最容易踩的一条）
6. **WKDownload 写 Documents**：是否首次弹权限、是否被 App 沙盒限制
7. **文件 App 可见性**：`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` 的实际效果
8. **UI 细节**：安全区、横屏、iPad 分栏、网格列宽在真机的表现
9. **识别准确率**：`GameDetector` 分数未用真实游戏目录校准（按约定暂不调）
10. **引擎相关**：MAC-1～MAC-4（AppDelegate 归属、生命周期观察、窗口归属、销毁顺序），本轮不涉及

---

## 3. 拿到 Mac 后从第 1 条到最后一条

```bash
# 1. 装工具链
xcode-select --install
brew install xcodegen

# 2. 把 Windows 上的工程拷过来（整个 hmy-ios 目录，不含 _research 也行）
cd ~/hmy-ios

# 3. 生成工程
xcodegen generate
# 产物：HeYiWei.xcodeproj

# 4. 确认 KRKR host 没有被加进工程（应当输出 0）
grep -c "hmy_krkr_host" HeYiWei.xcodeproj/project.pbxproj

# 5. 命令行编译（先不开真机，验证纯编译）
xcodebuild -project HeYiWei.xcodeproj \
           -scheme HeYiWei \
           -configuration Debug \
           -destination 'generic/platform=iOS' \
           build 2>&1 | tee ~/hmy-build1.log

# 6. 看错误（只处理真实报错，不猜）
grep -n "error:" ~/hmy-build1.log | head -40

# 7. 打开工程，选自己的 Team（Signing & Capabilities → Team）
open HeYiWei.xcodeproj

# 8. 连真机，选设备，Run
#    首次运行会要求信任开发者证书（设置 → 通用 → VPN与设备管理）

# 9. 装机后按这个顺序自测：
#    设置页能开 → 站点列表 502 条 → 打开一个站点 → 下载一个小文件
#    → 文件 App 里能看到 何意味/Downloads → + 添加一个 KRKR 游戏目录
#    → 卡片出现、封面显示、重命名/删除正常 → 杀掉 App 重开，卡片和目录授权还在
```

第 9 步里"重开 App 后目录授权还在"这条如果失败，问题一定在 `BookmarkStore`（第 2 节第 5 条），不用去查别处。

---

## 4. 第一轮如何排除 KRKR ObjC++ host

已经写进 `project.yml`：

```yaml
targets:
  HeYiWei:
    sources:
      - path: HeYiWei
        excludes:
          - "Engines/Bridge/hmy_krkr_host.mm"
```

效果：
- `hmy_krkr_host.mm`（334 行 ObjC++）**不参与编译**，不需要 SDL3 / krkrsdl3 的头文件与静态库
- `hmy_krkr.h` 仍通过桥接头暴露给 Swift，但当前**没有任何 Swift 代码调用**（只有 `KrkrEngine.swift` 注释里提到），所以不会出现链接期符号缺失
- `KrkrEngine.isAvailable` 保持 `false`，点卡片提示未接入

验证方式（二选一）：

```bash
grep -c "hmy_krkr_host" HeYiWei.xcodeproj/project.pbxproj   # 期望 0
grep -c "hmy_krkr_host" ~/hmy-build1.log                    # 期望 0
```

第 4 步（接入引擎）时改回来：
1. 删掉 `project.yml` 里那条 exclude
2. `settings.base` 追加 `OTHER_LDFLAGS`（krkrsdl3 / SDL3 的静态库）与 include 路径
3. 上游 `environ/sdl3/sdl3_entry.cpp` 必须排除（它自带 `main()`）
4. `xcodegen generate` 重新生成，再按 `docs/KRKR_IOS_LIFECYCLE.md` 的 MAC-1～MAC-4 逐条验证
