import Foundation

/// Where a usage snapshot came from — drives degraded UI labels.
enum UsageSource: String, Equatable, Sendable {
    case live
    case localSession
    case apiKeyValidated
    case manual
    case mock
    case degraded

    var detailPrefix: String {
        switch self {
        case .live: "Live"
        case .localSession: "Local session"
        case .apiKeyValidated: "API key"
        case .manual: "Manual cap"
        case .mock: "Demo mock"
        case .degraded: "Degraded"
        }
    }
}

/// Auth posture for a provider — never forces a login prompt loop.
enum ProviderAuthState: Equatable, Sendable {
    case authenticated
    case apiKeyPresent
    case manualOnly
    case unauthenticated
}
