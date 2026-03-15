import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PDFImportView: View {
    let currency: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var currentStep: ImportStep = .pickFile
    @State private var parsedTransactions: [ImportableTransaction] = []
    @State private var selectedAccount: Account?
    @State private var importedCount = 0
    @State private var isLoading = false

    enum ImportStep {
        case pickFile
        case review
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with step indicator
            VStack(spacing: 8) {
                Text("Import from PDF")
                    .font(.headline)

                HStack(spacing: 20) {
                    stepIndicator(step: 1, label: "Select File", isActive: currentStep == .pickFile)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                    stepIndicator(step: 2, label: "Review", isActive: currentStep == .review)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                    stepIndicator(step: 3, label: "Done", isActive: currentStep == .done)
                }
                .font(.caption)
            }
            .padding()

            Divider()

            // Content
            switch currentStep {
            case .pickFile:
                pickFileStep
            case .review:
                reviewStep
            case .done:
                doneStep
            }
        }
    }

    // MARK: - Step Indicator

    private func stepIndicator(step: Int, label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(step)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                )
            Text(label)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    // MARK: - Step 1: Pick File

    private var pickFileStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Select a bank statement PDF to import transactions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                openPDFPicker()
            } label: {
                Label("Choose PDF File", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if isLoading {
                ProgressView("Parsing PDF...")
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            // Account picker for all imports
            HStack {
                Picker("Import to account:", selection: $selectedAccount) {
                    Text("No Account").tag(Account?.none)
                    ForEach(accounts) { account in
                        Text(account.displayName).tag(Account?.some(account))
                    }
                }
                .frame(width: 300)

                Spacer()

                let selectedCount = parsedTransactions.filter(\.isSelected).count
                Text("\(selectedCount) of \(parsedTransactions.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Select All") {
                    for i in parsedTransactions.indices {
                        parsedTransactions[i].isSelected = true
                    }
                }
                .font(.caption)

                Button("Deselect All") {
                    for i in parsedTransactions.indices {
                        parsedTransactions[i].isSelected = false
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Transactions table
            Table(of: ImportableTransaction.self) {
                TableColumn("") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        Toggle("", isOn: $parsedTransactions[index].isSelected)
                            .labelsHidden()
                    }
                }
                .width(30)

                TableColumn("Date") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        DatePicker("", selection: $parsedTransactions[index].date, displayedComponents: .date)
                            .labelsHidden()
                            .frame(width: 110)
                    }
                }
                .width(min: 120, ideal: 130)

                TableColumn("Description") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        TextField("Description", text: $parsedTransactions[index].descriptionText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .width(min: 150, ideal: 200)

                TableColumn("Amount") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        TextField("0.00", text: $parsedTransactions[index].amountText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                .width(90)

                TableColumn("Type") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        Picker("", selection: $parsedTransactions[index].isExpense) {
                            Text("Expense").tag(true)
                            Text("Income").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }
                }
                .width(100)

                TableColumn("Category") { transaction in
                    let cat = DefaultCategories.category(withId: transaction.categoryId)
                    Text("\(cat.icon) \(cat.name)")
                        .font(.caption)
                }
                .width(min: 80, ideal: 120)
            } rows: {
                ForEach(parsedTransactions) { transaction in
                    TableRow(transaction)
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import Selected") {
                    importSelectedTransactions()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedTransactions.filter(\.isSelected).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Import Complete")
                .font(.title2.weight(.semibold))

            Text("\(importedCount) transaction\(importedCount == 1 ? "" : "s") imported successfully.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func openPDFPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF bank statement"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = PDFImportService.extractTransactions(from: url)

            let importable = parsed.map { p in
                let type: TransactionType = p.isExpense ? .expense : .income
                let detected = DefaultCategories.detectCategory(from: p.description, transactionType: type)
                return ImportableTransaction(
                    date: p.date ?? Date(),
                    descriptionText: p.description,
                    amountText: p.amount.map { String(format: "%.2f", $0) } ?? "",
                    isExpense: p.isExpense,
                    categoryId: detected.id,
                    isSelected: true
                )
            }

            DispatchQueue.main.async {
                parsedTransactions = importable
                isLoading = false
                if !importable.isEmpty {
                    currentStep = .review
                    selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
                }
            }
        }
    }

    private func importSelectedTransactions() {
        let dataService = DataService(modelContext: modelContext)
        let selected = parsedTransactions.filter(\.isSelected)

        for item in selected {
            guard let amount = Double(item.amountText), amount > 0 else { continue }

            let transaction = Transaction(
                type: item.isExpense ? .expense : .income,
                amount: amount,
                currency: currency,
                descriptionText: item.descriptionText,
                date: item.date,
                categoryId: item.categoryId,
                account: selectedAccount
            )
            dataService.addTransaction(transaction)
        }

        importedCount = selected.count
        currentStep = .done
    }
}

// MARK: - Importable Transaction

struct ImportableTransaction: Identifiable {
    let id = UUID()
    var date: Date
    var descriptionText: String
    var amountText: String
    var isExpense: Bool
    var categoryId: String
    var isSelected: Bool
}
