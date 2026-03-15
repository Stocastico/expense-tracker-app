import SwiftUI
import SwiftData

struct BudgetFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existingBudgets: [Budget]
    @Query private var settings: [AppSettings]

    @State private var selectedCategoryId: String = ""
    @State private var amountText: String = ""
    @State private var period: BudgetPeriod = .monthly

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var currency: String {
        currentSettings?.currency ?? "USD"
    }

    private var allCategories: [Category] {
        currentSettings?.allCategories ?? DefaultCategories.all
    }

    private var existingCategoryIds: Set<String> {
        Set(existingBudgets.map(\.categoryId))
    }

    private var availableCategories: [Category] {
        allCategories.expenseCategories.filter { !existingCategoryIds.contains($0.id) }
    }

    private var isValid: Bool {
        !selectedCategoryId.isEmpty && (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Budget")
                .font(.headline)
                .padding()

            Form {
                Picker("Category", selection: $selectedCategoryId) {
                    Text("Select a category").tag("")
                    ForEach(availableCategories) { category in
                        Text(category.displayName).tag(category.id)
                    }
                }

                TextField("Amount", text: $amountText)
                    .textFieldStyle(.roundedBorder)

                Picker("Period", selection: $period) {
                    ForEach(BudgetPeriod.allCases) { budgetPeriod in
                        Text(budgetPeriod.displayName).tag(budgetPeriod)
                    }
                }

                Text("Currency: \(currency)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveBudget()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 380, height: 320)
        .onAppear {
            if let first = availableCategories.first {
                selectedCategoryId = first.id
            }
        }
    }

    private func saveBudget() {
        guard let amount = Double(amountText), amount > 0 else { return }

        let budget = Budget(
            categoryId: selectedCategoryId,
            amount: amount,
            currency: currency,
            period: period
        )

        modelContext.insert(budget)
        try? modelContext.save()
        dismiss()
    }
}
