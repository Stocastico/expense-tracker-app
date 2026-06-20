import SwiftUI
import SwiftData

/// Lists the learned "merchant/description → category" rules so the user can
/// review, re-map or delete them.
struct CategoryRulesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\CategoryRule.hitCount, order: .reverse),
                  SortDescriptor(\CategoryRule.key)])
    private var rules: [CategoryRule]

    @Query private var settingsResults: [AppSettings]

    private var categories: [Category] {
        (settingsResults.first ?? AppSettings()).allCategories
    }

    var body: some View {
        Group {
            if rules.isEmpty {
                ContentUnavailableView(
                    "No learned rules yet",
                    systemImage: "brain",
                    description: Text("When you assign a category to a transaction, the app remembers it here and reuses it for the same name.")
                )
            } else {
                List {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
        .navigationTitle("Learned Categories")
    }

    private func ruleRow(_ rule: CategoryRule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.key)
                Text("Used \(rule.hitCount) time\(rule.hitCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { rule.categoryId },
                set: { newValue in
                    CategoryRuleService(modelContext: modelContext).setCategory(rule, to: newValue)
                }
            )) {
                ForEach(categories, id: \.id) { cat in
                    Text("\(cat.icon) \(cat.name)").tag(cat.id)
                }
            }
            .labelsHidden()
            .frame(width: 200)
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        let service = CategoryRuleService(modelContext: modelContext)
        for index in offsets {
            service.delete(rules[index])
        }
    }
}
