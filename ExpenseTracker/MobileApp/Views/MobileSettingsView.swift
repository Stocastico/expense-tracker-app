import SwiftUI
import SwiftData

struct MobileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncService: SyncService
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var settings: AppSettings?
    @State private var selectedCurrency: String = "EUR"
    @State private var defaultAccountId: UUID?
    @State private var showAddAccount: Bool = false
    @State private var newAccountName: String = ""
    @State private var editingAccount: Account?
    @State private var editAccountName: String = ""

    private let supportedCurrencies: [(code: String, name: String)] = [
        ("USD", "US Dollar"),
        ("EUR", "Euro"),
        ("GBP", "British Pound"),
        ("JPY", "Japanese Yen"),
        ("CAD", "Canadian Dollar"),
        ("AUD", "Australian Dollar"),
        ("CHF", "Swiss Franc"),
        ("CNY", "Chinese Yuan"),
        ("INR", "Indian Rupee"),
        ("SEK", "Swedish Krona"),
        ("NOK", "Norwegian Krone"),
        ("DKK", "Danish Krone"),
        ("PLN", "Polish Zloty"),
        ("BRL", "Brazilian Real"),
        ("MXN", "Mexican Peso"),
        ("KRW", "South Korean Won"),
        ("SGD", "Singapore Dollar"),
        ("HKD", "Hong Kong Dollar"),
        ("NZD", "New Zealand Dollar"),
        ("ZAR", "South African Rand"),
    ]

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                defaultAccountSection
                currencySection
                accountsSection
                syncSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSettings()
            }
            .alert("New Account", isPresented: $showAddAccount) {
                TextField("Account name", text: $newAccountName)
                Button("Cancel", role: .cancel) {
                    newAccountName = ""
                }
                Button("Add") {
                    addAccount()
                }
            } message: {
                Text("Enter a name for the new account.")
            }
            .alert("Rename Account", isPresented: Binding(
                get: { editingAccount != nil },
                set: { if !$0 { editingAccount = nil } }
            )) {
                TextField("Account name", text: $editAccountName)
                Button("Cancel", role: .cancel) {
                    editingAccount = nil
                    editAccountName = ""
                }
                Button("Save") {
                    renameAccount()
                }
            } message: {
                Text("Enter a new name for this account.")
            }
        }
    }

    // MARK: - Default Account Section

    private var defaultAccountSection: some View {
        Section("Default Account") {
            Picker("Default Account", selection: $defaultAccountId) {
                Text("None").tag(nil as UUID?)
                ForEach(accounts) { account in
                    Text(account.displayName).tag(account.id as UUID?)
                }
            }
            .onChange(of: defaultAccountId) { _, newValue in
                updateDefaultAccount(newValue)
            }
        }
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        Section("Currency") {
            Picker("Currency", selection: $selectedCurrency) {
                ForEach(supportedCurrencies, id: \.code) { currency in
                    Text("\(currency.code) - \(currency.name)")
                        .tag(currency.code)
                }
            }
            .onChange(of: selectedCurrency) { _, newValue in
                updateCurrency(newValue)
            }
        }
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        Section {
            ForEach(accounts) { account in
                HStack {
                    Text(account.icon)
                    Text(account.name)
                    Spacer()
                    if account.isDefault {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.systemGray5)))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editAccountName = account.name
                    editingAccount = account
                }
            }
            .onDelete { offsets in
                deleteAccounts(at: offsets)
            }

            Button {
                newAccountName = ""
                showAddAccount = true
            } label: {
                Label("Add Account", systemImage: "plus.circle")
            }
        } header: {
            Text("Accounts")
        } footer: {
            Text("Tap an account to rename it. Swipe to delete.")
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section("Sync") {
            HStack {
                Image(systemName: syncStatusIcon)
                    .foregroundStyle(syncStatusColor)
                Text("Local Network Sync")
                Spacer()
                Text(syncStatusLabel)
                    .foregroundStyle(syncStatusColor)
                    .font(.subheadline)
            }

            if let peerName = syncService.connectedPeerName {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.secondary)
                    Text("Connected to \(peerName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastSync = syncService.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                if syncService.isActive {
                    syncService.stop()
                } else {
                    syncService.start()
                }
            } label: {
                Label(
                    syncService.isActive ? "Stop Sync" : "Start Sync",
                    systemImage: syncService.isActive ? "stop.circle" : "play.circle"
                )
            }

            if syncService.connectedPeerName != nil {
                Button {
                    syncService.syncNow()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    private var syncStatusIcon: String {
        switch syncService.syncStatus {
        case .idle: return "wifi.slash"
        case .browsing: return "wifi"
        case .connecting, .syncing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .advertising: return "antenna.radiowaves.left.and.right"
        }
    }

    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .idle: return .secondary
        case .browsing, .advertising: return .blue
        case .connecting, .syncing: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }

    private var syncStatusLabel: String {
        switch syncService.syncStatus {
        case .idle: return "Off"
        case .browsing: return "Searching..."
        case .connecting: return "Connecting..."
        case .syncing: return "Syncing..."
        case .completed: return "Connected"
        case .error(let msg): return msg
        case .advertising: return "Waiting..."
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Platform")
                Spacer()
                Text("iOS")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            settings = existing
            selectedCurrency = existing.currency
            defaultAccountId = existing.defaultAccountId
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            settings = newSettings
            selectedCurrency = newSettings.currency
            defaultAccountId = newSettings.defaultAccountId
        }
    }

    private func updateDefaultAccount(_ accountId: UUID?) {
        guard let settings = settings else { return }
        settings.defaultAccountId = accountId

        // Update isDefault flag on accounts
        for account in accounts {
            account.isDefault = (account.id == accountId)
        }

        try? modelContext.save()
    }

    private func updateCurrency(_ currency: String) {
        guard let settings = settings else { return }
        settings.currency = currency
        try? modelContext.save()
    }

    private func addAccount() {
        let trimmed = newAccountName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let account = Account(name: trimmed)
        modelContext.insert(account)
        try? modelContext.save()
        newAccountName = ""
    }

    private func renameAccount() {
        guard let account = editingAccount else { return }
        let trimmed = editAccountName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        account.name = trimmed
        try? modelContext.save()
        editingAccount = nil
        editAccountName = ""
    }

    private func deleteAccounts(at offsets: IndexSet) {
        guard accounts.count > 1 else { return }

        for index in offsets {
            let account = accounts[index]
            // Prevent deleting if it is the only account
            if accounts.count - offsets.count < 1 { return }
            modelContext.delete(account)
        }
        try? modelContext.save()
    }
}
