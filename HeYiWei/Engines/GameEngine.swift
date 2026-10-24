import Foundation

enum EngineError: LocalizedError {
    case notReady(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notReady(let s): return s
        case .unsupported(let s): return s
        }
    }
}

/// 所有游戏引擎实现这个协议，UI 只认协议。
protocol GameEngine {
    var kind: Int { get }
    var displayName: String { get }
    /// 是否已具备可用实现；false 时必须明确提示，不允许假装能跑
    var isAvailable: Bool { get }
    func launch(_ game: Game) throws
}
