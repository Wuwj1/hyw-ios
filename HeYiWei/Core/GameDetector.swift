import Foundation

/// 目录内容识别结果。
/// 故意做成"打分 + 证据"，因为仅凭存在一个 .xp3 并不能断定是 KRKR。
struct DetectionResult {
    enum Confidence: String {
        case strong = "高"
        case likely = "中"
        case weak = "低"
    }

    var kind: Int
    var confidence: Confidence
    var score: Int
    var evidence: [String]
    var alternatives: [Int]
}

enum GameDetector {

    /// 只扫两层（游戏根 + 一层子目录），避免在大目录上做无意义的全量遍历。
    static func listNames(in dir: URL, depth: Int = 2) -> [String] {
        var out: [String] = []
        let fm = FileManager.default
        func walk(_ u: URL, _ level: Int) {
            guard level <= depth else { return }
            let items = (try? fm.contentsOfDirectory(at: u,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles])) ?? []
            for it in items {
                out.append(it.lastPathComponent.lowercased())
                let isDir = (try? it.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { walk(it, level + 1) }
            }
        }
        walk(dir, 1)
        return out
    }

    static func detect(_ dir: URL) -> DetectionResult {
        let names = listNames(in: dir)
        let set = Set(names)

        var krkrScore = 0
        var krkrEvidence: [String] = []

        if set.contains("startup.tjs") { krkrScore += 60; krkrEvidence.append("根目录有 startup.tjs") }
        if set.contains("data.xp3") { krkrScore += 30; krkrEvidence.append("有 data.xp3") }
        let xp3 = names.filter { $0.hasSuffix(".xp3") }
        if !xp3.isEmpty {
            krkrScore += min(30, 10 * xp3.count)
            krkrEvidence.append("包含 \(min(xp3.count, 9)) 个 .xp3")
        }
        if names.contains(where: { $0.hasSuffix(".ks") }) { krkrScore += 10; krkrEvidence.append("有 .ks 脚本") }
        if names.contains(where: { $0.hasSuffix(".tjs") }) && !set.contains("startup.tjs") {
            krkrScore += 8; krkrEvidence.append("有 .tjs 脚本")
        }

        var onsScore = 0
        var onsEvidence: [String] = []

        if set.contains("nscript.dat") { onsScore += 60; onsEvidence.append("有 nscript.dat") }
        if set.contains("nscript.___") || set.contains("nscript.dat.bak") { onsScore += 40; onsEvidence.append("有 nscript 数据文件") }
        if set.contains("arc.nsa") { onsScore += 30; onsEvidence.append("有 arc.nsa") }
        let nsa = names.filter { $0.hasSuffix(".nsa") }
        if !nsa.isEmpty { onsScore += min(20, 8 * nsa.count); onsEvidence.append("包含 .nsa 资源包") }
        let ns2 = names.filter { $0.hasSuffix(".ns2") || $0.hasSuffix(".ns3") }
        if !ns2.isEmpty { onsScore += 25; onsEvidence.append("有 .ns2/.ns3 脚本") }
        if set.contains("0.txt") && set.contains("1.txt") { onsScore += 10; onsEvidence.append("有 0.txt / 1.txt 脚本") }

        // 谁分高按谁判；都低就按"看着像哪个"给个弱判定
        let krkr = DetectionResult(kind: Game.krkr,
                                   confidence: confidence(krkrScore),
                                   score: krkrScore,
                                   evidence: krkrEvidence,
                                   alternatives: onsScore > 0 ? [Game.ons] : [])
        let ons = DetectionResult(kind: Game.ons,
                                  confidence: confidence(onsScore),
                                  score: onsScore,
                                  evidence: onsEvidence,
                                  alternatives: krkrScore > 0 ? [Game.krkr] : [])
        return krkrScore >= onsScore ? krkr : ons
    }

    private static func confidence(_ score: Int) -> DetectionResult.Confidence {
        if score >= 60 { return .strong }
        if score >= 25 { return .likely }
        return .weak
    }

    /// 给 UI 显示的一句话
    static func summary(_ r: DetectionResult) -> String {
        let name = r.kind == Game.krkr ? "KRKR（KiriKiri）" : "ONS（ONScripter）"
        if r.evidence.isEmpty { return "没有发现明显特征，请手动选择类型" }
        return "识别为 \(name)，置信度\(r.confidence.rawValue)：\(r.evidence.joined(separator: "、"))"
    }
}
