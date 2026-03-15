import SwiftUI
import SwiftData

struct MobileBudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var settingsResults: [AppSettings]

    @State private var showAddBudget = false

    private var settings: AppSettings { settingsResults.first ?? AppSettings() }
    private var currency: String { settings.currency }

    private var totalBudgeted: Double {
        budgets.filter { $0.period == .monthly }.reduce(0.0) { $0 + $1.storedAmount }
    }

    private var totalSpentThisMonth: Double {
        let start = Date().startOfMonth
        let end = Date().endOfMonth
        return allTransactions
            .filter { $0.type == .expense && $0.date >= start && $0.date <= end }
            .reduce(0.0) { $0 + $1.storedAmount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if budgets.isEmpty {
                    emptyState
                } else {
                    budgetList
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                MobileAddBudgetView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No Budgets Yet")
                .font(.title3.weight(.semibold))
            Text("Set spending limits for each category to track your budget progress.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showAddBudget = true
            } label: {
                Label("Add Budget", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Budget List

    private var budgetList: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Budgeted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(totalBudgeted.currencyFormatted(code: currency))
                            .font(.title3.weight(.bold).monospacedDigit())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Spent This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(totalSpentThisMonth.currencyFormatted(code: currency))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(totalSpentThisMonth > totalBudgeted ? .red : .primary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Category Budgets") {
                ForEach(budgets) { budget in
                    MobileBudgetRow(budget: budget, transactions: allTransactions, currency: currency)
                }
                .onDelete(perform: deleteBudgets)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(budgets[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Budget Row

struct MobileBudgetRow: View {
    let budget: Budget
    let transactions: [Transaction]
    let currency: String

    private var category: Category {
        DefaultCategories.category(withId: budget.categoryId)
    }

    private var periodRange: (start: Date, end: Date) {
        budget.currentPeriodRange()
    }

    private var spent: Double {
        transactions.filter {
            $0.type == .expense
                && $0.categoryId == budget.categoryId
                && $0.date >= periodRange.start
                && $0.date < periodRange.end
        }.reduce(0.0) { $0 + $1.storedAmount }
    }

    private var percentage: Double {
        guard budget.storedAmount > 0 else { return 0 }
        return (spent / budget.storedAmount) * 100.0
    }

    private var statusColor: Color {
        percentage > 100 ? .red : percentage >= 80 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.icon)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.subheadline.weight(.medium))
                    Text(budget.period.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f%%", percentage))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(statusColor)
                    Image(systemName: percentage > 100 ? "xmark.circle.fill" : percentage >= 80 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }

            ProgressView(value: min(percentage / 100, 1.0))
                .tint(statusColor)

            HStack {
                Text("\(spent.currencyFormatted(code: currency)) of \(budget.storedAmount.currencyFormatted(code: currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                let remaining = budget.storedAmount - spent
                if remaining >= 0 {
                    Text("\(remaining.currencyFormatted(code: currency)) left")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                } else {
                    Text("\(abs(remaining).currencyFormatted(code: currency)) over")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Budget View (iOS)

struct MobileAddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingBudgets: [Budget]
    @Query private var settingsResults: [AppSettings]

    @State private var selectedCategoryId: String = ""
    @State private var amountText: String = ""
    @State private var period: BudgetPeriod = .monthly

    private var settings: AppSettings { settingsResults.first ?? AppSettings() }
    private var currency: String { settings.currency }

    private var existingCategoryIds: Set<String> {
        Set(existingBudgets.map(\.categoryId))
    }

    private var availableCategories: [Category] {
        DefaultCategories.expenseCategories.filter { !existingCategoryIds.contains($0.id) }
    }

    private var isValid: Bool {
        !selectedCategoryId.isEmpty && (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("Select a category").tag("")
                        ForEach(availableCategories) { category in
                            Label(category.name, systemImage: "")
                                .tag(category.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Amount") {
                    HStack {
                        Text(currency)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Period") {
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !availableCategories.isEmpty && selectedCategoryId.isEmpty {
                    Section {
                        Text("Select a category and enter an amount to create a budget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if availableCategories.isEmpty {
                    Section {
                        Text("All expense categories already have budgets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveBudget()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            if selectedCategoryId.isEmpty, let first = availableCategories.first {
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
