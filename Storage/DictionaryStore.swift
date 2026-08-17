import Foundation

actor DictionaryStore {
    private let key = "ZeroTypeLocal.personalDictionary.v1"
    func load() -> [PersonalDictionaryEntry] { guard let data = UserDefaults.standard.data(forKey: key), let entries = try? JSONDecoder().decode([PersonalDictionaryEntry].self, from: data) else { return [] }; return entries }
    func save(_ entries: [PersonalDictionaryEntry]) { UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: key) }
}
