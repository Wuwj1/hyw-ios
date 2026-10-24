# 云端编译（Codemagic）

目的：没有 Mac 的情况下，用 Codemagic 的 macOS + Xcode 跑
`xcodegen generate` + `xcodebuild`，拿到真实编译日志，从第一个根错误开始修。

第一阶段范围：**iOS Simulator 无签名编译**。
不做：真机、签名、IPA、KRKR/ONS 引擎、验收 A/B。

## 配置在哪

```
codemagic.yaml        工作流定义（Codemagic 自动识别仓库根目录的这个文件）
project.yml           XcodeGen 工程定义（含显式 scheme: HeYiWei）
```

## 每次构建做什么

```
1 Toolchain versions     sw_vers / xcodebuild -version / iphonesimulator SDK / swift --version
2 Install XcodeGen       brew install xcodegen
3 Generate               xcodegen generate + xcodebuild -list
4 Verify KRKR host       pbxproj 里出现 hmy_krkr_host 直接失败
5 Build                  xcodebuild -scheme HeYiWei -destination generic/platform=iOS Simulator
                         CODE_SIGNING_ALLOWED=NO，日志 tee 到 build.log
6 Summarize first errors 打印前 40 条 error: 与产物路径
```

产物：`build.log`、`HeYiWei.app`（Simulator，Debug）、`.app.dSYM`。

## 成本

Codemagic 免费额度约 500 分钟/月（macOS 机器），一次构建 3–6 分钟（含 brew 安装 xcodegen）。

## 失败后发什么

第一条 `error:` 的完整行 + 前后 5 行上下文；或直接把 `build.log` 下载下来给我。
不要只发 `** BUILD FAILED **`。

## 明确边界

CI 编译通过 ≠ 真机可用。bookmark 跨重启、文件 App 可见性、Document Picker 的云盘行为、
SDL/UIKit 生命周期（MAC-1～4）与验收 B，仍必须 iPhone 真机验证。
