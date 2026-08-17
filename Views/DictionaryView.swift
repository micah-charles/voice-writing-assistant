import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject private var state: AppState
    @State private var term = ""
    @State private var preferred = ""
    var body: some View {
        VStack(alignment: .leading) {
            Text("Personal Dictionary").font(.title2)
            HStack { TextField("Term", text: $term); TextField("Preferred form", text: $preferred); Button("Add") { let entry = PersonalDictionaryEntry(term: term, preferredForm: preferred.isEmpty ? term : preferred, aliases: [term], category: nil); Task { await state.saveDictionaryEntry(entry) }; term = ""; preferred = "" }.disabled(term.isEmpty) }
            List { ForEach(state.dictionaryEntries) { entry in VStack(alignment: .leading) { Text(entry.preferredForm); Text("Aliases: \(entry.aliases.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) } }.onDelete { offsets in Task { await state.deleteDictionary(at: offsets) } } }
        }.padding()
    }
}
