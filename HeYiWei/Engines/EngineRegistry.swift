import Foundation

enum EngineRegistry {
    static let all: [GameEngine] = [KrkrEngine(), OnsEngine()]

    static func engine(for kind: Int) -> GameEngine? {
        all.first { $0.kind == kind }
    }
}
