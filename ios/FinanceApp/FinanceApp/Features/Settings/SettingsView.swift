import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportedFile: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    @State private var alertMessage: String?
    @State private var showingImportSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CategoriesSettingsView()
                    } label: {
                        Label("Categorías", systemImage: "tag")
                    }
                }
                .listRowBackground(Color.appCard)

                Section {
                    Button {
                        export()
                    } label: {
                        Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Genera un archivo con todas tus cuentas, movimientos, categorías, inversiones y recurrentes. Guárdalo en iCloud Drive, Archivos o donde prefieras para poder recuperarlo en otro móvil.")
                }
                .listRowBackground(Color.appCard)

                Section {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Importar copia de seguridad", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Importar sustituye todos los datos actuales de la app por los del archivo elegido.")
                }
                .listRowBackground(Color.appCard)
            }
            .navigationTitle("Ajustes")
            .themedListBackground()
            .fileExporter(
                isPresented: $isExporting,
                document: exportedFile,
                contentType: .json,
                defaultFilename: defaultFilename()
            ) { result in
                if case .failure(let error) = result {
                    alertMessage = "No se pudo guardar el archivo: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    showingImportConfirmation = true
                case .failure(let error):
                    alertMessage = "No se pudo abrir el archivo: \(error.localizedDescription)"
                }
            }
            .confirmationDialog(
                "¿Sustituir todos los datos?",
                isPresented: $showingImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Importar y sustituir", role: .destructive) {
                    if let url = pendingImportURL {
                        performImport(from: url)
                    }
                }
                Button("Cancelar", role: .cancel) {
                    pendingImportURL = nil
                }
            } message: {
                Text("Esto borrará las cuentas, movimientos, inversiones y recurrentes actuales de la app y los reemplazará por los del archivo.")
            }
            .alert(
                "Aviso",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("Importación completada", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tus datos se han restaurado correctamente.")
            }
        }
    }

    private func export() {
        do {
            let data = try BackupService.export(context: modelContext)
            exportedFile = BackupDocument(data: data)
            isExporting = true
        } catch {
            alertMessage = "No se pudo generar la copia de seguridad: \(error.localizedDescription)"
        }
    }

    private func performImport(from url: URL) {
        pendingImportURL = nil
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            try BackupService.importBackup(data: data, context: modelContext)
            showingImportSuccess = true
        } catch {
            alertMessage = "No se pudo importar la copia de seguridad: \(error.localizedDescription)"
        }
    }

    private func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "FinanceApp-backup-\(formatter.string(from: .now))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
