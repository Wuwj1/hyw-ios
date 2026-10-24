# krkrsdl3 的 iOS 宿主分析

基线 commit：`krkrsdl3 dd1de3d2` / `krkrsdl3_build 6059f785`（见 `THIRD_PARTY.md`）
本文件全部结论来自上游源码，未在 Mac 上编译验证。

## 1. 上游 iOS 构建结构

### 1.1 CMake 预设（`krkrsdl3_build/CMakePresets.json`）

| 预设 | 关键变量 |
|---|---|
| `iOS Device Config` | generator=Xcode，`IOS=true`，`CMAKE_SYSTEM_NAME=iOS`，`CMAKE_OSX_SYSROOT=iphoneos`，`CMAKE_OSX_DEPLOYMENT_TARGET=13.0`，`CMAKE_OSX_ARCHITECTURES=arm64`，`VCPKG_TARGET_TRIPLET=arm64-ios`，`USE_FFMPEG=true`，`USE_RENDER_GL=true`，`USE_RENDER_VK=false`，binaryDir=`out/ios-device` |
| `iOS Simulator Config` | 同上，sysroot=`iphonesimulator`，triplet=`arm64-ios-simulator`，binaryDir=`out/ios-simulator` |

Build presets：`iOS Device Debug/Release Build`、`iOS Simulator Debug/Release Build`。

### 1.2 一键脚本（`script/build-ios.sh`）

```bash
./script/build-ios.sh device Release
# 内部等效：
#   cmake --preset "iOS Device Config" -DUSE_RENDER_VK=OFF
#   cmake --build --preset "iOS Device Release Build" --parallel
```

前提：
- `DEVELOPER_DIR`（默认 `/Applications/Xcode.app/Contents/Developer`）
- `VCPKG_ROOT`（脚本会退而找 `../vcpkg`）

### 1.3 编译宏（iOS 分支）

```
-D_KRKRSDL3_IOS=1
-D_KRKRSDL3_GLES=1        （iOS 用 GLES，不是桌面 GL）
-D_KRKRSDL3_USE_SDL3=1
-D_KRKRSDL3_USE_FFMPEG=1
-D_KRKRSDL3_USE_VULKAN  ← 关闭（预设与脚本都置 OFF）
```

### 1.4 目标类型（`cmake/cmake_main.txt`）

```cmake
elseif(IOS)
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${KRKRSDL_SRC})
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.tvp.krkrsdl3"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
```

对比 Android 分支：`add_library(${PROJECT_NAME} SHARED ...)` —— 安卓是 `.so`，iOS 是**整个 `.app`**。

## 2. 产物是什么

```
out/ios-device/Release-iphoneos/krkrsdl3.app        ← 未签名的 iOS App Bundle
  ├── krkrsdl3                                      可执行文件（引擎宿主就在里面）
  ├── Info.plist                                    bundle id = org.tvp.krkrsdl3
  └── Frameworks/ 或链接静态依赖（视 vcpkg 配置）
```

**注意**：上游给的是「一个能自己跑的 App」，不是一个库。
所以我们有两种用法：

| 路线 | 做法 | 用途 |
|---|---|---|
| **A. 直接跑上游 .app** | 重签 → 装真机 → 把游戏丢进它的 Documents → 启动 | **第一阶段验收最快路径**，用来证明「引擎在 iPhone 上能出画面」 |
| **B. 编成静态库嵌进何意味** | 自己写 CMake/Xcode 目标，复用同一批源码，产出 `libkrkrsdl3.a` | 正式产品：何意味 SwiftUI → 宿主 → 引擎 |

第一阶段先走 A（不写宿主就能验证），通过后再做 B。

## 3. iOS 入口在哪里

关键文件：`environ/sdl3/sdl3_entry.cpp`（全文只有 2 行）

```cpp
// sdl3入口点，如果ios/mac系统需要自定义启动函数以套壳，则不加入此源码
#define SDL_MAIN_USE_CALLBACKS
#include <SDL3/SDL_main.h>
```

也就是说：**上游明确留出了"自己写启动函数"的口子，iOS 要排除这个文件**，
由宿主提供 `main`，然后调用 SDL3 的回调式入口：

```cpp
SDL_EnterAppMainCallbacks(argc, argv, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
```

引擎侧已经实现好的四个回调（`environ/sdl3/sdl3_app.cpp`）：

| 回调 | 行号 | 职责 |
|---|---|---|
| `SDL_AppInit(appstate, argc, argv)` | 198 | 解析参数 → `SDL_Init(VIDEO|AUDIO)` → 建窗 → 初始化渲染后端 → 启动 KRKR |
| `SDL_AppEvent(appstate, event)` | 425 | 事件分发（触摸/键盘/窗口/退出） |
| `SDL_AppIterate(appstate)` | 543 | 主循环一帧 |
| `SDL_AppQuit(appstate, result)` | 561 | 收尾、释放 |

**结论：我们不重写引擎主循环，只提供 `main` + 参数 + 退出回调。**

## 4. 游戏目录怎么传（最关键）

`core/utils/TVPSettings.cpp:246` `TVPParseArguments()`：

```cpp
TVPNativeExeName = argv[0];
TVPNativeProjectData = argv[1];              // ← 游戏目录/数据文件，就是第 2 个参数
if (TVPCheckExistentLocalFolder(argv[1])) TVPNativeProjectDir = argv[1];
else if (TVPCheckExistentLocalFile(argv[1])) TVPNativeProjectDir = 其父目录;
else { log "%1 not found."; return false; }  // ← 目录不存在直接失败

TVPProjectData = TVPNormalizeStorageName(argv[1]);
TVPDataPath    = TVPProjectDir + "savedata/";      // ← 存档目录
TVPSetLogLocation(TVPNativeDataPath);              // ← 日志也写这里
```

所以在宿主里构造 argv 即可：

```c
char *argv[] = { (char*)"krkrsdl3", (char*)game_dir_utf8, NULL };
SDL_EnterAppMainCallbacks(2, argv, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
```

- `game_dir_utf8` 必须是**游戏根目录**（里面能直接找到 `startup.tjs` 或 `data.xp3`）
- 存档写到 `<游戏目录>/savedata/`，日志同目录
- 目录不存在 → 引擎直接返回失败（不会静默黑屏）

## 5. 渲染 / Surface 怎么挂到 iOS

`environ/sdl3/sdl3_app.cpp:48 TVPCreateWindowForBackend(renderer)`：
用 `SDL_CreateWindowWithProperties` 建窗，之后按 `TVPSettings.renderer`
（`software` / `opengl` / `vulkan`）选渲染后端；建窗或后端失败会回退到 `software`。

iOS 上的实际形态：
- 窗口由 SDL3 内部创建（SDL3 的 iOS 层自带 UIWindow / UIView 与 Metal/GL 视图）
- 我们**不直接操作 UIView**，SDK 层面只跟 SDL 打交道
- 对外可见的 iOS 专有接口（`environ/iOS/ios_core.mm`）只有两个：
  - `TVPSetGameRunningOrientation(bool)` → 进游戏锁横屏、退出恢复
  - `KrkrIsLandscapeLocked()` → 查询

## 6. 音频

`environ/sdl3/sdl3_audio.cpp`：走 SDL3 音频子系统，iOS 上由 SDL 转为 AVAudioSession。
宿主层面需要处理的只有一件：**进入游戏时把 AVAudioSession 类别设成 Playback**（否则静音键会影响），这属于我们的壳要做的，不是引擎。

## 7. 输入（触摸/键盘）

`environ/sdl3/sdl3_input.cpp`：把 SDL3 事件（手指触摸、外接键盘、手柄）转成 TVP 输入事件。
引擎侧已完整实现，**宿主不需要写触摸映射代码**。

## 8. 退出后怎么返回 SwiftUI

- 引擎侧：`SDL_AppQuit()` 负责释放资源
- 宿主侧：`SDL_EnterAppMainCallbacks` 返回后，我们调用自己的 Swift 回调（`onFinished`）→ 关闭承载引擎的 ViewController → 回到 SwiftUI 的库页面
- 注意：`SDL_EnterAppMainCallbacks` 在 iOS 上会接管 `UIApplicationMain`。
  **集成路线 B 的最大待验证点就是它和 SwiftUI 的 App 生命周期能否共存**
  （备选：让 SDL 自己开一个全屏 window/VC，SwiftUI 只负责弹出和关闭）

## 9. 存档/可写路径映射

`environ/iOS/ios_core.mm`：

```objc
std::string TVPGetDefaultFileDir() {           // ← 默认目录
    NSDocumentDirectory ...
}
std::vector<std::string> TVPGetAppStoragePath(){ return {TVPGetDefaultFileDir()}; }
```

要点：
- 引擎默认目录 = `NSDocumentDirectory`（App 沙盒 Documents）
- 但**实际存档路径**由 `argv[1]` 决定：`<游戏目录>/savedata/`
- 因此如果游戏目录在外部（用户通过 `UIDocumentPicker` 授权的 iCloud/本地目录），存档也写在那里面 —— 这需要该目录可写；**只读授权会导致存档失败**，必须让用户在可写目录里放游戏，或把游戏复制进 App 沙盒

## 10. 依赖链接（iOS 预设下）

vcpkg triplet：`arm64-ios` / `arm64-ios-simulator`，依赖：

```
oniguruma zlib ffmpeg libpng libwebp libjpeg-turbo libvorbis opusfile
freetype plutovg sdl3 sdl3-ttf glm glad
```

CMake 里通过 `CMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake` 引入，
iOS 分支强制 `USE_SDL3=ON`（源码里明确：Android/iOS 不支持 SDL2 后端）。

## 11. 我们还需要写多少宿主代码

按上游已有的东西倒推，宿主只需要这一层（**不碰引擎内部**）：

| 文件 | 内容 | 估计 |
|---|---|---|
| `hmy_krkr_host.mm` | `hmy_krkr_run(const char* dir)`：拼 argv → 调 `SDL_EnterAppMainCallbacks`；退出回调 | ~120 行 |
| `hmy_krkr_bridge.h` | 给 Swift 的 C 接口 | ~20 行 |
| `KrkrViewController.swift` | 承载引擎画面 / 生命周期 / 退出返回 | ~80 行 |
| `KrkrEngine.swift` | 实现 `GameEngine.launch`：bookmark → 路径 → `hmy_krkr_run` | ~40 行 |
| CMake 目标 | 复用上游源码列表产出 `libkrkrsdl3.a`（或直接改 target 类型） | — |

合计约 260 行，**核心代码零改动**。

## 12. 待 Mac 验证的清单

1. `cmake --preset "iOS Device Config"` 能否完整拉完 vcpkg 依赖（ffmpeg 最慢）
2. `krkrsdl3.app` 能否编出、重签后装到真机
3. 真机能进游戏画面（路线 A 的四级验收）
4. 改成静态库后，`SDL_EnterAppMainCallbacks` 与 SwiftUI 生命周期是否冲突
5. 外置目录（security-scoped）里游戏能否存档
6. `USE_RENDER_VK=OFF` 下 GLES 后端在真机的实际帧率

## 13. Mac 上的完整首次构建步骤

```bash
# 0. 环境
xcode-select --install
brew install cmake ninja git-lfs

# 1. 取代码（固定版本）
git clone https://github.com/krkrsdl3/krkrsdl3_build.git
cd krkrsdl3_build
git checkout 6059f7857bf6c56bad33a781ec0fc2cc5151b86a
git submodule update --init --recursive
git -C <子模块目录> checkout dd1de3d2fd6a10c4f5ef8801e6649f520fc5bc3e

# 2. vcpkg
git clone https://github.com/microsoft/vcpkg.git ../vcpkg
../vcpkg/bootstrap-vcpkg.sh
export VCPKG_ROOT=$(cd ../vcpkg && pwd)

# 3. 配置 + 编译（真机 Release）
chmod +x script/build-ios.sh
./script/build-ios.sh device Release

# 4. 取产物
ls out/ios-device/Release-iphoneos/krkrsdl3.app

# 5. 重签（用你自己的开发者证书）
codesign -f -s "Apple Development: 你的名字 (TEAMID)" \
  --entitlements /path/entitlements.plist out/ios-device/Release-iphoneos/krkrsdl3.app

# 6. 安装到 iPhone
xcrun devicectl device install app --device <UDID> out/ios-device/Release-iphoneos/krkrsdl3.app
```

> 第 3 步第一次会编译 ffmpeg 等依赖，耗时取决于网络与 CPU；失败通常是 vcpkg 下载中断，
> 重跑同一条命令即可（vcpkg 有缓存）。
