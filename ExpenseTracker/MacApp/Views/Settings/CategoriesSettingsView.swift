import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @State private var showingAddCategory = false

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var defaultCategories: [Category] {
        DefaultCategories.all
    }

    private var customCategories: [Category] {
        currentSettings?.customCategories ?? []
    }

    var body: some View {
        List {
            Section("Default Categories") {
                ForEach(defaultCategories) { category in
                    categoryRow(category, isDeletable: false)
                }
            }

            Section("Custom Categories") {
                if customCategories.isEmpty {
                    Text("No custom categories yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customCategories) { category in
                        categoryRow(category, isDeletable: true)
                    }
                    .onDelete(perform: deleteCustomCategories)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryFormSheet()
        }
    }

    private func categoryRow(_ category: Category, isDeletable: Bool) -> some View {
        HStack(spacing: 10) {
            Text(category.icon)
                .font(.title3)

            Text(category.name)
                .font(.body)

            Spacer()

            Text(category.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(typeColor(category.type).opacity(0.15))
                .foregroundStyle(typeColor(category.type))
                .clipShape(Capsule())

            if category.isCustom {
                Text("Custom")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func typeColor(_ type: CategoryType) -> Color {
        switch type {
        case .expense: return .red
        case .income: return .green
        case .both: return .blue
        }
    }

    private func deleteCustomCategories(at offsets: IndexSet) {
        guard let settings = currentSettings else { return }
        let categoriesToDelete = offsets.map { customCategories[$0] }
        for category in categoriesToDelete {
            settings.removeCustomCategory(withId: category.id)
        }
        try? modelContext.save()
    }
}

// MARK: - Category Form Sheet

private struct CategoryFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var colorHex: String = "#007AFF"
    @State private var type: CategoryType = .expense
    @State private var keywordsText: String = ""

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !icon.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Custom Category")
                .font(.headline)
                .padding()

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Icon (emoji)", text: $icon)
                    .textFieldStyle(.roundedBorder)

                TextField("Color (hex, e.g. #FF6B6B)", text: $colorHex)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Preview:")
                    Text(icon.isEmpty ? "?" : icon)
                        .font(.title2)
                    Text(name.isEmpty ? "Category Name" : name)
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 14, height: 14)
                }

                Picker("Type", selection: $type) {
                    ForEach(CategoryType.allCases, id: \.self) { categoryType in
                        Text(categoryType.displayName).tag(categoryType)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Keywords (comma-separated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. coffee, starbucks, cafe", text: $keywordsText)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveCategory()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 440)
    }

    private func saveCategory() {
        guard let settings = currentSettings else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let keywords = keywordsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let categoryId = trimmedName.lowercased().replacingOccurrences(of: " ", with: "-")

        let category = Category(
            id: categoryId,
            name: trimmedName,
            icon: icon,
            color: colorHex,
            type: type,
            keywords: keywords,
            isCustom: true
        )

        settings.addCustomCategory(category)
        try? modelContext.save()
        dismiss()
    }
}
