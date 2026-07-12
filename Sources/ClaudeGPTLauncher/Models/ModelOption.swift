import Foundation

enum ModelOption: String, CaseIterable, Identifiable, Codable {
    case sol = "gpt-5.6-sol"
    case terra = "gpt-5.6-terra"
    case luna = "gpt-5.6-luna"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sol: "GPT-5.6 Sol"
        case .terra: "GPT-5.6 Terra"
        case .luna: "GPT-5.6 Luna"
        }
    }

    var summary: String {
        switch self {
        case .sol: "Flagship reasoning and coding"
        case .terra: "Balanced capability and usage"
        case .luna: "Fast, efficient project work"
        }
    }

    var smallModel: String { ModelOption.luna.rawValue }
}
