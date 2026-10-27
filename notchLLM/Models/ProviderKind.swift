import Foundation
import SwiftUI

/// Built-in LLM usage providers. Real adapters land in Phase 3.
enum ProviderKind: String, CaseIterable, Identifiable, Sendable {
    case gemini
    case chatGPT
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: "Gemini"
        case .chatGPT: "ChatGPT"
        case .cursor: "Cursor"
        }
    }

    var shortLabel: String {
        switch self {
        case .gemini: "G"
        case .chatGPT: "GPT"
        case .cursor: "Cu"
        }
    }

    /// SF Symbol stand-in for each brand (custom artwork can replace later).
    var systemImage: String {
        switch self {
        case .gemini: "sparkles"
        case .chatGPT: "bubble.left.and.bubble.right.fill"
        case .cursor: "cursorarrow.rays"
        }
    }

    var accent: Color {
        switch self {
        case .gemini: Color(red: 0.35, green: 0.55, blue: 0.98)
        case .chatGPT: Color(red: 0.20, green: 0.72, blue: 0.58)
        case .cursor: Color(red: 0.95, green: 0.58, blue: 0.22)
        }
    }
}
