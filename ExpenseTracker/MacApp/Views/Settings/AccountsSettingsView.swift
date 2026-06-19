import SwiftUI
import SwiftData

struct AccountsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var showingAddAccount = false
    @State private var editingAccount: Account?
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            ForEach(accounts) { account in
                HStack(spacing: 12) {
                    Image(systemName: account.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: account.color))
                        .frame(width: 28)

                    Text(account.name)
                        .font(.body)

                    Circle()
                        .fill(Color(hex: account.color))
                        .frame(width: 12, height: 12)

                    if account.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(.accentColor)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        editingAccount = account
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                }
                .contextMenu {
                    Button("Edit") {
                        editingAccount = account
                    }
                    Button("Delete", role: .destructive) {
                        deleteAccount(account)
                    }
                    .disabled(accounts.count <= 1)
                }
            }
            .onDelete(perform: deleteAccounts)
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAccount = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AccountFormSheet(account: nil)
        }
        .sheet(item: $editingAccount) { account in
            AccountFormSheet(account: account)
        }
        .alert("Cannot Delete", isPresented: $showDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You must keep at least one account.")
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        guard accounts.count - offsets.count >= 1 else {
            showDeleteAlert = true
            return
        }
        for index in offsets {
            modelContext.delete(accounts[index])
        }
        try? modelContext.save()
    }

    private func deleteAccount(_ account: Account) {
        guard accounts.count > 1 else {
            showDeleteAlert = true
            return
        }
        modelContext.delete(account)
        try? modelContext.save()
    }
}

// MARK: - Account Form Sheet

private struct AccountFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account?

    @State private var name: String = ""
    @State private var icon: String = "creditcard"
    @State private var colorHex: String = "#007AFF"
    @State private var isDefault: Bool = false

    var isEditing: Bool {
        account != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Account" : "New Account")
                .font(.headline)
                .padding()

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("SF Symbol Name", text: $icon)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Preview:")
                    Image(systemName: icon.isEmpty ? "questionmark.circle" : icon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: colorHex))
                }

                TextField("Color (hex)", text: $colorHex)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Color Preview:")
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 20, height: 20)
                }

                Toggle("Default Account", isOn: $isDefault)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveAccount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
        .onAppear {
            if let account = account {
                name = account.name
                icon = account.icon
                colorHex = account.color
                isDefault = account.isDefault
            }
        }
    }

    private func saveAccount() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = account {
            existing.name = trimmedName
            existing.icon = icon
            existing.color = colorHex
            existing.isDefault = isDefault
        } else {
            let newAccount = Account(
                name: trimmedName,
                icon: icon,
                color: colorHex,
                isDefault: isDefault
            )
            modelContext.insert(newAccount)
        }

        try? modelContext.save()
        dismiss()
    }
}

extension Account: @retroactive Identifiable {}
