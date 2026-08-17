import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID; let date: Date; let rawTranscript: String; let processedText: String; let provider: String; let mode: AppMode; let activeApplication: String?
    var latency: TimeInterval?
    var alternativeResults: [ProcessingResult]?
}
actor HistoryStore {
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ZeroTypeLocal/history.json")
    func load() -> [HistoryEntry] { guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return [] }; return value }
    func append(_ item: HistoryEntry) throws { var entries = load(); entries.insert(item, at: 0); try save(entries) }
    func updateAlternatives(id: UUID, alternatives: [ProcessingResult]) throws { var entries = load(); guard let index = entries.firstIndex(where: { $0.id == id }) else { return }; entries[index].alternativeResults = alternatives; try save(entries) }
    func clear() throws { try save([]) }
    private func save(_ entries: [HistoryEntry]) throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(entries).write(to: url, options: .atomic) }
}
