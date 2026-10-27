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
        case .chatGPT: "C"
        case .cursor: "Cu"
        }
    }

    var accent: Color {
        switch self {
        case .gemini: Color(red: 0.25, green: 0.55, blue: 0.95)
        case .chatGPT: Color(red: 0.15, green: 0.72, blue: 0.55)
        case .cursor: Color(red: 0.95, green: 0.55, blue: 0.20)
        }
    }
}
