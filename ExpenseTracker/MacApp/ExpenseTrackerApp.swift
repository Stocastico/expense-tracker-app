import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    /// The SwiftData models backing the app, in one place so the persistent
    /// store and the in-memory fallback stay in sync.
    private static let models: [any PersistentModel.Type] = [
        Transaction.self,
        Account.self,
        Budget.self,
        AppSettings.self,
        CategoryRule.self,
        ExpenseCategoryRecord.self,
        ExpenseSubcategoryRecord.self,
        ExpenseTagRecord.self,
        ExpenseTransactionRecord.self
    ]

    let modelContainer: ModelContainer
    /// SwiftData-backed repository for the pure two-level expense domain.
    let expenseRepository: SwiftDataExpenseRepository
    /// An error captured during launch (e.g. the persistent store failed to
    /// open), surfaced to the user on first appear.
    private let startupError: ExpensePresentableError?

    /// Surfaces failures from setup and persistence to the user.
    @State private var errorPresenter = ExpenseErrorPresenter()
    @State private var didRunStartup = false

    init() {
        let configuration = ModelConfiguration(
            "ExpenseTracker",
            schema: Schema(Self.models),
            cloudKitDatabase: .none
        )
        do {
            modelContainer = try ModelContainer(
                for: Schema(Self.models),
                configurations: configuration
            )
            startupError = nil
        } catch {
            // The persistent store couldn't be opened. Rather than crash, fall
            // back to an in-memory store so the app still launches, and tell the
            // user their changes won't be saved.
            modelContainer = try! ModelContainer(
                for: Schema(Self.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            startupError = ExpensePresentableError(
                title: "Couldn’t open your saved data",
                message: "ExpenseTracker is running without saving, so changes won’t be kept. Restarting the app may fix this."
            )
        }
        expenseRepository = SwiftDataExpenseRepository(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.expenseRepository, expenseRepository)
                .environment(errorPresenter)
                .alert(
                    errorPresenter.currentError?.title ?? "",
                    isPresented: Binding(
                        get: { errorPresenter.currentError != nil },
                        set: { if !$0 { errorPresenter.dismiss() } }
                    ),
                    presenting: errorPresenter.currentError
                ) { _ in
                    Button("OK", role: .cancel) { errorPresenter.dismiss() }
                } message: { error in
                    Text(error.message)
                }
                .onAppear(perform: runStartupIfNeeded)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("Expense Tracker", systemImage: "dollarsign.circle.fill") {
            MenuBarQuickAdd()
                .modelContainer(modelContainer)
                .environment(\.expenseRepository, expenseRepository)
                .environment(errorPresenter)
        }
        .menuBarExtraStyle(.window)
    }

    /// Runs first-launch setup once, routing every step through the presenter so
    /// failures surface to the user instead of being swallowed.
    @MainActor
    private func runStartupIfNeeded() {
        guard !didRunStartup else { return }
        didRunStartup = true

        if let startupError {
            errorPresenter.currentError = startupError
        }
        errorPresenter.perform("Setting up accounts") { try createDefaultAccountsIfNeeded() }
        errorPresenter.perform("Loading categories") { try expenseRepository.seedDefaultsIfEmpty() }
        errorPresenter.perform("Importing your data") {
            try LegacyExpenseMigrationRunner.run(in: modelContainer.mainContext)
        }
    }

    @MainActor
    private func createDefaultAccountsIfNeeded() throws {
        let context = modelContainer.mainContext
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard accounts.isEmpty else { return }

        context.insert(Account(name: "Personal", icon: "person.fill", color: "#007AFF", isDefault: true))
        context.insert(Account(name: "Family", icon: "house.fill", color: "#34C759", isDefault: false))
        try context.save()
    }
}
