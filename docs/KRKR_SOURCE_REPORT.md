# libkrkrsdl3.so 源码追查报告

日期：2026-10-23
结论：**选项 ②——来自公开上游仓库，且有源码、有 iOS 平台层、有 iOS 构建预设。**

## 一、结论先行

| 判断项 | 结果 |
|---|---|
| TY 自己维护但没放进仓库 | 否 |
| **来自另一个公开上游仓库** | **是** `https://github.com/krkrsdl3/krkrsdl3` |
| 构建时下载的预编译二进制 | 否，是源码编译产物（Android 目标） |
| 真正闭源只有 .so | **否** |

因此 iOS 侧不需要逆 .so，也不需要换核心，走**同一份上游源码的 iOS 构建**即可。

## 二、证据链

### 1. TY 仓库内的线索（F:\HMY\hmy_ty）

- 无 `.git`、无 `.gitmodules`（是导出的源码包，不是 git clone）
- `engine/src/main/jniLibs/arm64-v8a/libkrkrsdl3.so` 27.1 MB，无对应 C/C++ 源码
- `engine/src/main/cpp/` 只有 18 个文件，全部是 bridge 层：
  `krkr_bridge.cpp`、`krkrsdl3_graphics.cpp`、`artemis_*.cpp`、`siglus_bridge.cpp` 等
- `engine/src/main/cpp/CMakeLists.txt` 只编译这些 bridge（`add_library(krkr_bridge_v2 ...)`），
  不包含引擎本体 → 引擎本体是"jniLibs 直打包"模式
- `docs/FVP接入方案.md:141` 明确写了这个模式：
  > "jniLibs 直打包：`libfvp.so`，随 APK 分发，CI 不需要 Rust 工具链
  > （与 `libkrkrsdl3.so` / `libsiglus.so` 同模式）"

### 2. TY 文档直接给出了上游地址和版本

`hmy_ty/docs/krkr-local-raw-filters.md`：

```
| libkrkrsdl3.so | e088c4563fdbc75118564e68acf6e3e70ec83a91 | d5dff5f84b410576415ddbf2afcfdbad112ef9d71851e153584a759065e163ac |

公开舞台结构参考 [krkrsdl3 固定版本的 PlatformView.h]
(https://github.com/krkrsdl3/krkrsdl3/blob/e5cabc20a0ebcc4bc024fa245fc661036bc1790a/environ/PlatformView.h)
```

即：打包库有 build-id 和 sha256 可核对，参考的上游提交是 `e5cabc20…`。

### 3. 上游仓库实况（今日实测）

```
git ls-remote https://github.com/krkrsdl3/krkrsdl3 HEAD
→ dd1de3d2fd6a10c4f5ef8801e6649f520fc5bc3e      （可达，公开）

仓库信息：krkrsdl3/krkrsdl3
  description: 多平台支持的krkr视觉小说引擎
  language: C++      size: ~92 MB
  license: 自定义（KiriKiri Z 三条款式，允许再分发，需保留版权声明与免责声明）

顶层目录：core/  environ/  plugins/  tjs2/  LICENSE  README.md
environ/ 平台目录：
  android  apple  console  iOS  linux  macos  ohos  sdl2  sdl3  unix  wasm  windows
```

`environ/iOS/ios_core.mm`（3 KB）与 `environ/apple/apple_core.mm`（3.4 KB）存在，
说明 iOS 平台层是上游正式维护的分支，不是我们临时拼的。

### 4. 构建工程确认支持 iOS

```
仓库：krkrsdl3/krkrsdl3_build   （CMake + vcpkg + 各平台脚本）
README: "目前支持 windows/linux/android/WebAssembly/HarmonyOS/macOS/IOS系统"

CMakePresets.json 中的 iOS 预设（原文）：
  iOS Device Config / iOS Device Debug Build / iOS Device Release Build
  iOS Simulator Config / iOS Simulator Debug Build / iOS Simulator Release Build
```

依赖（vcpkg 管理）：oniguruma、zlib、ffmpeg、libpng/libwebp/libjpeg-turbo、
libvorbis/opusfile、freetype、plutosvg、sdl3/glad。

## 三、对 iOS 意味着什么

**能做**，但工作量在"宿主层"而不在"内核移植"：

| 层 | 状态 | 需要做的事 |
|---|---|---|
| TJS2 脚本内核 | 上游已有 | 直接编 |
| KRKR 运行内核（core/main、render、media） | 上游已有 | 直接编 |
| 平台层 | 上游有 `environ/iOS` | 可能要按需补：文件系统路径、字体回退、音频会话 |
| 图形 | SDL3（Metal 后端） | 用上游 iOS 预设即可 |
| **宿主层** | **没有**（Android 侧是 TY 的 `RemoteActivity` + SDLActivity） | **我们要自己写**：`main()` 注入、启动参数（游戏目录）、事件循环托管、退出回传 |

TY 的 Android 启动契约（`LaunchContract.PATH` + `Kirikiroid139`）是 Android 专有的，
iOS 上不能复用，需要写一个等价的最小宿主：接收游戏目录 → 设工作目录 → 启动 SDL3 主循环。

## 四、下一步（需要 Mac）

```bash
# 1. 取构建工程与源码
git clone https://github.com/krkrsdl3/krkrsdl3_build
# 该仓库通过 .gitmodules 拉取 krkrsdl3 主仓库

# 2. 装依赖
brew install cmake ninja
./vcpkg/bootstrap-vcpkg.sh

# 3. 用 iOS Device 预设配置并编译
cmake --preset "iOS Device Config"
cmake --build --preset "iOS Device Release Build"

# 4. 产出：arm64 静态库 / dylib（具体形式以 CMakeLists 为准）
```

验收分四级（与你的要求一致）：

1. 编出 iOS arm64 产物
2. 在 iPhone 上链接进最小 App 后能启动、不崩
3. 能读取指定游戏目录（`startup.tjs` / `data.xp3`）
4. 能实际进入游戏画面

## 五、许可证注意

上游为 KiriKiri Z 三条款式许可：允许源码/二进制再分发与修改，条件是要保留
版权声明、条件列表、免责声明；未经书面许可不得用作者名义宣传。
**侧载版分发时，App 内"关于"页需要放这段声明**（后续要补）。
