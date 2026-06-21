import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Batch receipt/invoice import: pick several photos, OCR each, run them through
/// `ReceiptImportPipeline`, then review/edit the categorized drafts before
/// saving. Mirrors `PDFImportView`'s three-step flow and reuses
/// `ImportableTransaction` + the same review table.
struct ReceiptScanImportView: View {
    let currency: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var currentStep: ImportStep = .pickFiles
    @State private var parsedTransactions: [ImportableTransaction] = []
    @State private var selectedAccount: Account?
    @State private var importedCount = 0
    @State private var isLoading = false
    @State private var showNoReceipts = false

    enum ImportStep {
        case pickFiles
        case review
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Scan Receipts")
                    .font(.headline)

                HStack(spacing: 20) {
                    stepIndicator(step: 1, label: "Select Images", isActive: currentStep == .pickFiles)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    stepIndicator(step: 2, label: "Review", isActive: currentStep == .review)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    stepIndicator(step: 3, label: "Done", isActive: currentStep == .done)
                }
                .font(.caption)
            }
            .padding()

            Divider()

            switch currentStep {
            case .pickFiles:
                pickFilesStep
            case .review:
                reviewStep
            case .done:
                doneStep
            }
        }
        .alert("No receipts read", isPresented: $showNoReceipts) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't read any amounts from the selected images. Make sure the receipts are well-lit and in focus.")
        }
    }

    // MARK: - Step indicator

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
            Text(label).foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    // MARK: - Step 1: pick images

    private var pickFilesStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Select one or more receipt/invoice photos. Each is read on-device and proposed as an expense for you to review.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                openImagePicker()
            } label: {
                Label("Choose Images", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading)

            if isLoading {
                ProgressView("Reading receipts…")
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

    // MARK: - Step 2: review

    private var reviewStep: some View {
        VStack(spacing: 0) {
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
                    for i in parsedTransactions.indices { parsedTransactions[i].isSelected = true }
                }
                .font(.caption)

                Button("Deselect All") {
                    for i in parsedTransactions.indices { parsedTransactions[i].isSelected = false }
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            Table(of: ImportableTransaction.self) {
                TableColumn("") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        Toggle("", isOn: $parsedTransactions[index].isSelected).labelsHidden()
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

                TableColumn("Merchant") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        TextField("Merchant", text: $parsedTransactions[index].descriptionText)
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

                TableColumn("Category") { transaction in
                    if let index = parsedTransactions.firstIndex(where: { $0.id == transaction.id }) {
                        Picker("", selection: $parsedTransactions[index].categoryId) {
                            ForEach(DefaultCategories.expenseCategories, id: \.id) { cat in
                                Text("\(cat.icon) \(cat.name)").tag(cat.id)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .width(min: 120, ideal: 160)
            } rows: {
                ForEach(parsedTransactions) { transaction in
                    TableRow(transaction)
                }
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import Selected") { importSelectedTransactions() }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedTransactions.filter(\.isSelected).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // MARK: - Step 3: done

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

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select one or more receipt photos"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let urls = panel.urls

        isLoading = true
        Task {
            var texts: [String] = []
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                if let text = try? await OCRService.recognizeText(from: data) {
                    texts.append(text)
                }
            }
            let drafts = await ReceiptImportPipeline.makeDrafts(fromTexts: texts)

            await MainActor.run {
                // Learned rules first, then the pipeline's heuristic suggestion,
                // then keyword detection, for each row's initial category.
                let ruleService = CategoryRuleService(modelContext: modelContext)
                parsedTransactions = drafts.map { draft in
                    let description = draft.merchant ?? "Receipt"
                    let categoryId = ruleService.suggestedCategoryId(merchant: draft.merchant, description: description)
                        ?? draft.categoryId
                        ?? DefaultCategories.detectCategory(from: description, transactionType: .expense).id
                    let amountText = draft.amount
                        .map { String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue) } ?? ""
                    return ImportableTransaction(
                        date: draft.date ?? Date(),
                        descriptionText: description,
                        amountText: amountText,
                        isExpense: true,
                        categoryId: categoryId,
                        // Pre-tick only rows we could read an amount for.
                        isSelected: draft.amount != nil
                    )
                }
                isLoading = false
                if parsedTransactions.isEmpty {
                    showNoReceipts = true
                } else {
                    currentStep = .review
                    selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
                }
            }
        }
    }

    private func importSelectedTransactions() {
        let dataService = DataService(modelContext: modelContext)
        let ruleService = CategoryRuleService(modelContext: modelContext)
        let selected = parsedTransactions.filter(\.isSelected)

        for item in selected {
            guard let amount = Double(item.amountText), amount > 0 else { continue }

            let transaction = Transaction(
                type: .expense,
                amount: amount,
                currency: currency,
                descriptionText: item.descriptionText,
                merchant: item.descriptionText,
                date: item.date,
                categoryId: item.categoryId,
                account: selectedAccount
            )
            dataService.addTransaction(transaction)
            ruleService.learn(merchant: item.descriptionText, description: item.descriptionText, categoryId: item.categoryId)
        }

        importedCount = selected.count
        currentStep = .done
    }
}
