import SwiftUI

struct SymbolSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let preferredAssetType: AssetType
    let onSelect: (SymbolSearchResult) -> Void

    @State private var query = ""
    @State private var results: [SymbolSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if trimmedQuery.isEmpty {
                    Section("Populares") {
                        ForEach(PopularSymbols.suggestions(for: preferredAssetType), id: \.symbol) { suggestion in
                            Button {
                                query = suggestion.symbol
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.symbol).font(.headline)
                                    Text(suggestion.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if results.isEmpty && !isSearching {
                    Text("Sin resultados para \"\(query)\"")
                        .foregroundStyle(.secondary)
                }

                if !trimmedQuery.isEmpty {
                    ForEach(results) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            SymbolResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Buscar símbolo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .searchable(text: $query, prompt: "Nombre o símbolo, ej. Apple, VWCE")
            .onChange(of: query) {
                scheduleSearch()
            }
            .overlay {
                if isSearching {
                    ProgressView()
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard trimmedQuery.count >= 2 else {
            results = []
            errorMessage = nil
            return
        }
        let text = trimmedQuery
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(text)
        }
    }

    private func search(_ text: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let matches = try await PriceService().searchSymbols(query: text)
            guard !Task.isCancelled else { return }
            results = prioritized(matches)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Sorts matches of the currently selected asset type first, without discarding the rest —
    /// Yahoo's `quoteType` labels are inconsistent enough that a hard filter would hide valid
    /// results.
    private func prioritized(_ matches: [SymbolSearchResult]) -> [SymbolSearchResult] {
        guard let preferredType = preferredAssetType.yahooQuoteType else { return matches }
        return matches.sorted { lhs, rhs in
            let lhsMatch = lhs.instrumentType?.localizedCaseInsensitiveContains(preferredType) ?? false
            let rhsMatch = rhs.instrumentType?.localizedCaseInsensitiveContains(preferredType) ?? false
            return lhsMatch && !rhsMatch
        }
    }
}

private struct SymbolResultRow: View {
    let result: SymbolSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(result.symbol)
                    .font(.headline)
                if let exchange = result.exchange {
                    Text(exchange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let name = result.instrumentName {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let type = result.instrumentType {
                Text(type)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
