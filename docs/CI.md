# 用 GitHub Actions 的 macOS Runner 编 iOS（Windows 端操作）

目的：在没有 Mac 的情况下，用 GitHub 托管的 macOS 跑
`xcodegen generate` + `xcodebuild`，拿到**真实编译日志**，从第一个根错误开始修。

本轮只做：**何意味 iOS App 本体，iOS Simulator，无签名编译**。
不做：真机、签名、IPA、KRKR/ONS 引擎、验收 A/B。

---

## 0. 成本（先看这个）

| 仓库类型 | Actions 费用 |
|---|---|
| **Public** | 标准 runner 免费、不限分钟 |
| **Private** | 免费额度 2000 分钟/月，但 **macOS runner 按 10 倍计费** → 实际约 200 分钟/月 |

一次 iOS 编译大概 2–5 分钟（不含 xcodegen/brew 安装），200 分钟够跑几十次。
跑得频繁就用 public 仓库，或用 private 但注意次数。

---

## 1. 把工程传到 GitHub（Windows）

工程里已经放好：

```
.github/workflows/ios-build.yml     CI 定义
.gitignore                          排除 xcodeproj / build / _research
```

### 方式 A：GitHub CLI（推荐）

```bash
winget install --id GitHub.cli        # 装 gh
gh auth login                          # 浏览器授权，不要用 token 贴聊天

cd /f/HMY/hmy-ios
git init -b main
git add .
git commit -m "pre-mac baseline: iOS app skeleton + build CI"

gh repo create hmy-ios --private --source=. --push
# 想省额度就换成 --public
```

### 方式 B：网页建仓库 + 手动推

1. 在 GitHub 上新建空仓库（不要勾 README / .gitignore，避免冲突）
2. 本地执行：

```bash
cd /f/HMY/hmy-ios
git init -b main
git add .
git commit -m "pre-mac baseline: iOS app skeleton + build CI"
git remote add origin https://github.com/<你的用户名>/hmy-ios.git
git push -u origin main
```

推送时要求密码 → 用 **Personal Access Token**（repo 权限）代替密码。
令牌只在 Git Credential Manager 里填一次，**不要贴进聊天、不要写进任何文件**。

---

## 2. 第一次运行 workflow

### 网页

```
仓库 → Actions → 左侧「iOS Build (Simulator, unsigned)」→ Run workflow → main → Run
```

### 命令行

```bash
gh workflow run ios-build.yml
gh run list --workflow=ios-build.yml
gh run watch            # 实时看日志
```

也可以直接在本地推送触发（workflow 已配置 `push` 到 main 且改动 `HeYiWei/**` 或 `project.yml`）。

---

## 3. CI 做了什么（9 步）

```
1 Checkout
2 Toolchain versions    sw_vers / xcodebuild -version / iphonesimulator SDK 版本 / swift --version
                        → 写进 Summary，以后对版本问题用
3 Install XcodeGen      brew install xcodegen
4 Generate               xcodegen generate + xcodebuild -list
5 Verify KRKR host        检查 project.pbxproj 里不能出现 hmy_krkr_host，出现就红
6 Build                  xcodebuild -target HeYiWei -sdk iphonesimulator
                         CODE_SIGNING_ALLOWED=NO，日志 tee 到 build.log
7 Extract first errors    把前 40 条 error: 写进 Summary
8 Upload build log        artifact: ios-build-log（14 天）
9 Upload .app             成功时上传 HeYiWei-simulator-app（7 天）
```

两个刻意的设计：

- 用 `-target` 而不是 `-scheme`：xcodegen 不保证一定生成 scheme，用 target 不会因为找不到 scheme 直接失败
- `Info.plist` 已从 sources 里排除：否则会出现 "Multiple commands produce Info.plist"

---

## 4. 跑完之后发我什么

优先发 **Summary 里的 First errors**；不够就看 artifact `ios-build-log`。

需要的格式：

```
第一条 error 的完整行 + 前后各 5 行上下文
（如果有 "The following build commands failed" 段，也一并贴上）
```

不要只贴最后一句 `** BUILD FAILED **` —— 那说明不了根因。
也不要把几百条 error 一次性全贴，先给**第一条**，我改完你再重跑。

---

## 5. 预期会出现的问题（不改代码，先知道）

| 现象 | 原因 | 处理 |
|---|---|---|
| `Multiple commands produce Info.plist` | Info.plist 同时被当资源 | 已排除，若仍出现再看 xcodegen 版本 |
| `The project does not contain a scheme` | 未生成 scheme | 已用 `-target` 规避 |
| `ContentUnavailableView is only available in iOS 17.0` | 部署目标 | 当前已是 17.0，正常不应出现 |
| Swift 并发告警 | `@MainActor` 与 delegate | 已把 WebView 状态改为主线程派发，剩余按日志改 |
| `No such module 'X'` | 缺少系统框架 import | 按日志补 import |

---

## 6. 明确边界

**CI 编译通过 ≠ 真机可用。**

后面仍然必须用 iPhone 验证：

- security-scoped bookmark 跨重启是否还有效
- 文件 App 能否看到 Documents/Downloads
- Document Picker 在各云盘/本地目录的行为
- SDL/UIKit 生命周期（MAC-1～MAC-4）与验收 B

这些在模拟器和 CI 上都测不出来。

---

## 7. App 本体编过之后

再让同一套 CI 去编 krkrsdl3 的 iOS 目标：

```
新增 workflow: krkrsdl3-ios.yml
  clone krkrsdl3 + krkrsdl3_build（固定 commit）
  vcpkg bootstrap
  cmake --preset "iOS Simulator Config" && cmake --build ...
```

那一步很重（ffmpeg 等依赖），先不急，等 App 本体 BUILD SUCCEEDED 再说。
