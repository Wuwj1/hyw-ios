import Foundation

/// KRKR 引擎接入位。
///
/// 技术基线（固定版本，见 THIRD_PARTY.md）：
///   源码      https://github.com/krkrsdl3/krkrsdl3         commit dd1de3d2fd6a10c4f5ef8801e6649f520fc5bc3e
///   构建      https://github.com/krkrsdl3/krkrsdl3_build   commit 6059f7857bf6c56bad33a781ec0fc2cc5151b86a
///   许可      KiriKiri Z 三条款式（LICENSES/KiriKiri-Z-LICENSE.txt）
///   iOS 预设  iOS Device Config / iOS Device Release Build（arm64, sysroot iphoneos, deployment 13.0）
///
/// 上游已经提供、我们不改的部分：
///   - 主循环：environ/sdl3/sdl3_app.cpp 的 SDL_AppInit / SDL_AppEvent / SDL_AppIterate / SDL_AppQuit
///   - 游戏目录传参：argv[1]（core/utils/TVPSettings.cpp:253）
///   - 存档路径：<游戏目录>/savedata/（同文件 :273）
///   - 输入 / 音频：environ/sdl3/sdl3_input.cpp、sdl3_audio.cpp
///   - iOS 默认目录：environ/iOS/ios_core.mm → NSDocumentDirectory
///
/// 我们只写宿主层（契约见 Engines/Bridge/hmy_krkr.h，实现见 hmy_krkr_host.mm）：
///   SwiftUI → KrkrEngine → hmy_krkr_set_presenter(VC) → hmy_krkr_run(gameDir)
///           → SDL_AppInit / SDL_AppIterate（宿主用 CADisplayLink 驱动，不走 UIApplicationMain）
///           → 退出 → 回调 → dismiss → 回到 SwiftUI
///
/// 为什么不用 SDL_EnterAppMainCallbacks：SDL3 的 iOS 实现在结束时调用 exit()，
/// 且假设自己跑在 UIApplicationMain 里（证据见 docs/KRKR_IOS_LIFECYCLE.md）。
///
/// 当前状态：**未接入**（arm64 产物未构建，宿主未在 Mac 上编译验证）。
/// 所以 isAvailable = false，点卡片只提示未接入，不做任何假启动。
final class KrkrEngine: GameEngine {
    let kind = Game.krkr
    let displayName = "KRKR"
    var isAvailable: Bool { false }

    func launch(_ game: Game) throws {
        // 拿到 Mac 之后的实现顺序（TODO(MAC-9)：链接通过后逐条补真）：
        //   1. BookmarkStore.resolve(id:) 恢复 security-scoped 目录
        //   2. 校验目录内存在 startup.tjs / data.xp3
        //   3. hmy_krkr_set_presenter(承载 VC)   ← 需要能拿到当前 UIViewController
        //   4. hmy_krkr_run(dir, callback)       ← 阻塞到初始化完成，之后由 CADisplayLink 驱动
        //   5. 回调里 stopAccessingSecurityScopedResource()
        throw EngineError.notReady(
            "KRKR 引擎尚未编入 iOS 版。上游源码与 iOS 预设已确认（krkrsdl3 dd1de3d2 / "
            + "krkrsdl3_build 6059f785），宿主已写好，需在 macOS 上编出 arm64 产物并完成链接验证。"
        )
    }
}
