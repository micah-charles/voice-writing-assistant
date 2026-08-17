import Foundation

actor SettingsStore {
    private let key = "ZeroTypeLocal.settings.v1"
    private let historyMigrationKey = "ZeroTypeLocal.historyEnabled.v1"
    private let localLLMMigrationKey = "ZeroTypeLocal.localLLMConfigured.v1"
    private let processingTimeoutMigrationKey = "VoiceWritingAssistant.processingTimeout45.v1"
    func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key) else { return AppSettings() }
        if let settings = try? JSONDecoder().decode(AppSettings.self, from: data) { return settings }
        guard var values = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return AppSettings() }
        // Older settings predate the floating control; preserve every existing choice.
        values["showFloatingControl"] = true
        guard let migrated = try? JSONSerialization.data(withJSONObject: values), let settings = try? JSONDecoder().decode(AppSettings.self, from: migrated) else { return AppSettings() }
        save(settings)
        return settings
    }
    func save(_ settings: AppSettings) { UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: key) }
    func loadWithHistoryEnabled() -> AppSettings {
        var settings = load()
        if !UserDefaults.standard.bool(forKey: historyMigrationKey) {
            settings.storeHistory = true
            UserDefaults.standard.set(true, forKey: historyMigrationKey)
        }
        if !UserDefaults.standard.bool(forKey: localLLMMigrationKey) {
            if settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { settings.ollamaModel = "qwen3:8b" }
            UserDefaults.standard.set(true, forKey: localLLMMigrationKey)
        }
        if !UserDefaults.standard.bool(forKey: processingTimeoutMigrationKey) {
            // The previous 20-second default regularly expired while a local model was warming.
            if settings.processingTimeoutSeconds == 20 { settings.processingTimeoutSeconds = 45 }
            UserDefaults.standard.set(true, forKey: processingTimeoutMigrationKey)
        }
        save(settings)
        return settings
    }
}
