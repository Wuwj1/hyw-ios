# 第三方组件与版本锁定

本文件记录 iOS KRKR 路线依赖的上游项目**固定版本**。升级必须单独验证，不允许跟随 main/HEAD。

## 1. KRKR 引擎

| 项目 | 值 |
|---|---|
| 名称 | krkrsdl3（多平台 KiriKiri 运行时，C++ / SDL3） |
| 源码仓库 | https://github.com/krkrsdl3/krkrsdl3 |
| **锁定 commit** | `dd1de3d2fd6a10c4f5ef8801e6649f520fc5bc3e` |
| 提交时间 | 2026-10-19 |
| 提交说明 | Merge pull request #14 from itsCheney/fix/psb-parser-safety |
| 构建工程 | https://github.com/krkrsdl3/krkrsdl3_build |
| **锁定 commit** | `6059f7857bf6c56bad33a781ec0fc2cc5151b86a` |
| 提交时间 | 2026-10-16 |
| 提交说明 | 追加测试项和libbpg |
| 许可证 | KiriKiri Z 三条款式（见 `LICENSES/KiriKiri-Z-LICENSE.txt`） |
| 平台支持 | windows / linux / android / wasm / HarmonyOS / macOS / **iOS** |

### 关联参考（TY Android 版所用版本）

| 项目 | 值 |
|---|---|
| TY 文档锁定的上游参考提交 | `e5cabc20a0ebcc4bc024fa245fc661036bc1790a`（`environ/PlatformView.h`） |
| TY 打包的 Android 库 build-id | `e088c4563fdbc75118564e68acf6e3e70ec83a91` |
| 对应 sha256 | `d5dff5f84b410576415ddbf2afcfdbad112ef9d71851e153584a759065e163ac` |
| 出处 | `hmy_ty/docs/krkr-local-raw-filters.md` |

> 说明：iOS 使用上表的 `dd1de3d2…` 作为基线；Android 侧 TY 用的是 `e5cabc20…` 附近的构建。
> 两者**不要求一致**，但 iOS 首次验收通过后也要把实际使用的 commit 回写到本文件。

## 2. 依赖库（vcpkg 管理，来自 krkrsdl3_build/vcpkg.json）

```
oniguruma  zlib  ffmpeg  libpng  libwebp  libjpeg-turbo
libvorbis  opusfile  freetype  plutovg
sdl3  sdl3-ttf  glm  glad
```

iOS 使用的 vcpkg triplet：

```
真机      arm64-ios
模拟器    arm64-ios-simulator
```

第三方库各自许可证随 vcpkg 安装目录附带，最终需汇总进 App 的「开源许可」页面。

## 3. 分发时的义务

KiriKiri Z 许可要求：再分发（源码或二进制）时必须附带
版权声明、条件列表、免责声明，且未经书面许可不得用作者名义宣传。

落地位置：iOS「设置 → 关于 → 开源许可」，Android 版后续同步补一页。

## 4. 升级流程

1. 记录当前 commit 与验收结果（真机能否进游戏）
2. 单独升级 `krkrsdl3` 或 `krkrsdl3_build`，不同时升级两者
3. 重新跑四级验收：编出 arm64 → 启动不崩 → 读到游戏目录 → 进入游戏画面
4. 通过后更新本文件的 commit 与日期，并在提交信息里写明验收结论

升级未通过时回滚到本文件记录的 commit，不允许"先合了再说"。
