import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var showDeleteConfirmation = false
    @State private var showingCSVExporter = false
    @State private var showingJSONExporter = false
    @State private var showingJSONImporter = false
    @State private var showingElectronImporter = false
    @State private var csvContent: String = ""
    @State private var jsonData: Data = Data()
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showImportSuccess = false

    private static let commonCurrencies = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF",
        "CNY", "SEK", "NOK", "DKK", "NZD", "SGD", "HKD",
        "KRW", "MXN", "BRL", "INR", "ZAR", "TRY", "PLN", "CZK"
    ]

    private var currentSettings: AppSettings {
        if let existing = settings.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        Form {
            generalSection
            navigationSection
            dataSection
            dangerSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Data has been imported successfully.")
        }
        .confirmationDialog(
            "Delete All Data",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all transactions, budgets, accounts, and settings. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingCSVExporter,
            document: CSVDocument(content: csvContent),
            contentType: .commaSeparatedText,
            defaultFilename: "expense-tracker-export.csv"
        ) { result in
            if case .failure(let error) = result {
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .fileExporter(
            isPresented: $showingJSONExporter,
            document: JSONDocument(data: jsonData),
            contentType: .json,
            defaultFilename: "expense-tracker-export.json"
        ) { result in
            if case .failure(let error) = result {
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .fileImporter(
            isPresented: $showingJSONImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleJSONImport(result: result, isElectron: false)
        }
        .fileImporter(
            isPresented: $showingElectronImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleJSONImport(result: result, isElectron: true)
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section("General") {
            Picker("Currency", selection: Binding(
                get: { currentSettings.currency },
                set: { newValue in
                    currentSettings.currency = newValue
                    try? modelContext.save()
                }
            )) {
                ForEach(Self.commonCurrencies, id: \.self) { code in
                    Text("\(code)").tag(code)
                }
            }

            HStack {
                Text("Dark Mode")
                Spacer()
                Text("Follows System Appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var navigationSection: some View {
        Section {
            NavigationLink("Accounts") {
                AccountsSettingsView()
            }
            NavigationLink("Categories") {
                CategoriesSettingsView()
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                let allCategories = currentSettings.allCategories
                csvContent = ExportService.exportToCSV(transactions: transactions, categories: allCategories)
                showingCSVExporter = true
            } label: {
                Label("Export CSV", systemImage: "doc.text")
            }

            Button {
                jsonData = ExportService.exportToJSON(
                    transactions: transactions,
                    budgets: budgets,
                    settings: currentSettings,
                    accounts: accounts
                )
                showingJSONExporter = true
            } label: {
                Label("Export JSON", systemImage: "doc.badge.arrow.up")
            }

            Button {
                showingJSONImporter = true
            } label: {
                Label("Import JSON", systemImage: "doc.badge.arrow.down")
            }

            Button {
                showingElectronImporter = true
            } label: {
                Label("Import Electron JSON", systemImage: "desktopcomputer")
            }
        }
    }

    private var dangerSection: some View {
        Section("Danger Zone") {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func handleJSONImport(result: Result<[URL], Error>, isElectron: Bool) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Could not access the selected file."
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                if isElectron {
                    try ExportService.importFromElectronJSON(data, context: modelContext)
                } else {
                    try ExportService.importFromJSON(data, context: modelContext)
                }
                showImportSuccess = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }

        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Budget.self)
            try modelContext.delete(model: Account.self)
            try modelContext.delete(model: AppSettings.self)
            try modelContext.save()
        } catch {
            print("Failed to delete all data: \(error.localizedDescription)")
        }
    }
}

// MARK: - File Documents

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(data: data, encoding: .utf8) ?? ""
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
