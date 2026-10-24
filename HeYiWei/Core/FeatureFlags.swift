import Foundation

/// 构建期开关：App Store 版可通过构建配置关掉站点搜索，不需要另写工程。
enum FeatureFlags {
    static var siteSearch: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "HMY_SITE_SEARCH") as? Bool) ?? true
    }
}
