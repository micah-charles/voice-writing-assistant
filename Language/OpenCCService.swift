import Foundation

/// A conservative built-in fallback. Phase 8 can replace this seam with a licence-reviewed OpenCC package.
struct OpenCCService {
    func convert(_ input: String, profile: OpenCCProfile) -> String {
        guard profile != .preserve else { return input }
        let map: [Character: Character] = ["这":"這", "个":"個", "们":"們", "为":"為", "说":"說", "会":"會", "时":"時", "间":"間"]
        return String(input.map { map[$0] ?? $0 })
    }
}
