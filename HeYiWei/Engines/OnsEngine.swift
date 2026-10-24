import Foundation

/// ONS（ONScripter）接入位。
///
/// 计划路线（与 KRKR 同样的分层：内核用开源实现，宿主自己写）：
///   1. 取 ONScripter 公开 C++ 源码（含 SDL 层）
///   2. 用 CMake/Xcode 编 arm64 静态库，产出 `libonscripter.a`
///   3. 宿主负责：传入游戏目录、窗口/输入/音频桥接、退出回传
///   4. 本类的 launch() 调宿主，isAvailable 改为 true（仅在真机验证通过后）
///
/// 与 KRKR 的差异：ONS 没有 SDL3 的 main 回调封装，移植面更小；
/// 但仍需处理 iOS 上「谁拥有 UIApplication 生命周期」的同一类问题。
///
/// 当前状态：**未接入**，不做假启动。
final class OnsEngine: GameEngine {
    let kind = Game.ons
    let displayName = "ONS"
    var isAvailable: Bool { false }

    func launch(_ game: Game) throws {
        throw EngineError.notReady(
            "ONS 引擎尚未编入 iOS 版。计划移植 ONScripter 开源核心，"
            + "需要 macOS 上编出 arm64 库并实现宿主层。"
        )
    }
}
