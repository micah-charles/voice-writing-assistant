import Foundation

struct ProviderDiagnostic: Identifiable, Equatable {
    let id: String
    let name: String
    let ready: Bool
    let detail: String
}
