import SwiftUI

struct AccountsListView: View {
    @ObservedObject var state: AppState
    let poller: UsagePoller
    @State private var addingAccount = false
    @State private var renamingID: UUID?
    @State private var renameDraft: String = ""
    @State private var pendingDeletion: Account?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts").font(.headline)
                Spacer()
                Button {
                    addingAccount = true
                } label: {
                    Label("Add account", systemImage: "plus")
                }
            }

            if state.accounts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(state.accounts) { account in
                        row(for: account)
                    }
                }
                .frame(minHeight: 200)
            }
        }
        .padding(20)
        .sheet(isPresented: $addingAccount) {
            AddAccountView(state: state, poller: poller)
        }
        .alert("Remove this account?",
               isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Remove", role: .destructive) {
                if let a = pendingDeletion { state.remove(accountID: a.id) }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("\(pendingDeletion?.displayName ?? "") will be removed and its saved tokens deleted.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No accounts configured")
                .font(.system(size: 13, weight: .semibold))
            Text("Click ‘Add account’ to import OAuth tokens from the official CLI or paste them in.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func row(for account: Account) -> some View {
        HStack(spacing: 10) {
            account.provider.logoView(size: 22)
                .frame(width: 32, height: 26, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                if renamingID == account.id {
                    TextField("Display name", text: $renameDraft, onCommit: {
                        commitRename(for: account)
                    })
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text(account.displayName).font(.system(size: 12, weight: .medium))
                }
                if let snapshot = state.statuses[account.id]?.snapshot {
                    Text("5h \(snapshot.fiveHour?.percentInt ?? 0)% · 7d \(snapshot.sevenDay?.percentInt ?? 0)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if case .failed(let msg) = state.statuses[account.id] {
                    Text(msg).font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
                } else {
                    Text(account.provider.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { account.showInMenuBar },
                set: { state.setMenuBarVisible(accountID: account.id, $0) }
            )) {
                Text("Show in Menubar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.checkbox)
            .help("Include this account in the menu bar tray summary")

            Button {
                Task { await state.refresh(accountID: account.id) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Button {
                renamingID = account.id
                renameDraft = account.displayName
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Rename")

            Button {
                pendingDeletion = account
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 4)
    }

    private func commitRename(for account: Account) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { state.rename(accountID: account.id, to: trimmed) }
        renamingID = nil
    }
}
