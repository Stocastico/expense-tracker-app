import Foundation
import MultipeerConnectivity
import SwiftData
import Combine

// MARK: - Sync Payload Types

/// Lightweight Codable representations for transferring data between devices.
struct SyncPayload: Codable {
    let transactions: [SyncTransaction]
    let accounts: [SyncAccount]
    let sentAt: Date
}

struct SyncTransaction: Codable {
    let id: UUID
    let typeRaw: String
    let storedAmount: Double
    let currency: String
    let descriptionText: String
    let merchant: String?
    let date: Date
    let categoryId: String
    let accountId: UUID?
    let tagsString: String
    let notes: String?
    let isRecurring: Bool
    let recurringFrequencyRaw: String?
    let recurringEndDate: Date?
    let recurringParentId: UUID?
    let receiptData: Data?
    let createdAt: Date
    let updatedAt: Date
}

struct SyncAccount: Codable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let isDefault: Bool
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - SyncService

/// Provides local-network sync between macOS and iOS using MultipeerConnectivity.
///
/// - macOS acts as the **advertiser** (always visible on the network).
/// - iOS acts as the **browser** (discovers and connects to the Mac).
///
/// On connection, the iOS device sends its full data set to the Mac, which merges
/// using last-write-wins on `updatedAt` for transactions and `createdAt` for accounts.
/// The Mac then sends its merged data back so both sides end up consistent.
@MainActor
public final class SyncService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published public var isActive: Bool = false
    @Published public var connectedPeerName: String?
    @Published public var lastSyncDate: Date?
    @Published public var syncStatus: SyncStatus = .idle

    public enum SyncStatus: Equatable {
        case idle
        case advertising
        case browsing
        case connecting
        case syncing
        case completed
        case error(String)
    }

    public enum Role {
        case advertiser  // macOS
        case browser     // iOS
    }

    // MARK: - Private Properties

    private let role: Role
    private let serviceType = "exp-tracker"  // max 15 chars, lowercase + hyphens
    private let myPeerId: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var modelContext: ModelContext?

    // MARK: - Init

    public init(role: Role, displayName: String? = nil) {
        self.role = role
        #if os(macOS)
        let name = displayName ?? Host.current().localizedName ?? "Mac"
        #else
        let name = displayName ?? UIDevice.current.name
        #endif
        self.myPeerId = MCPeerID(displayName: name)
        super.init()
    }

    // MARK: - Public API

    /// Attach a SwiftData model context for reading/writing during sync.
    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Start advertising (macOS) or browsing (iOS).
    public func start() {
        guard !isActive else { return }

        let session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        switch role {
        case .advertiser:
            let adv = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
            adv.delegate = self
            adv.startAdvertisingPeer()
            self.advertiser = adv
            syncStatus = .advertising

        case .browser:
            let brs = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
            brs.delegate = self
            brs.startBrowsingForPeers()
            self.browser = brs
            syncStatus = .browsing
        }

        isActive = true
    }

    /// Stop advertising/browsing and disconnect.
    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        isActive = false
        connectedPeerName = nil
        syncStatus = .idle
    }

    /// Manually trigger a sync (iOS side sends data to Mac).
    public func syncNow() {
        guard role == .browser,
              let session = session,
              let peer = session.connectedPeers.first else { return }

        sendPayload(to: peer)
    }

    // MARK: - Data Transfer

    private func sendPayload(to peer: MCPeerID) {
        guard let context = modelContext else { return }

        syncStatus = .syncing

        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

        let payload = SyncPayload(
            transactions: transactions.map { t in
                SyncTransaction(
                    id: t.id,
                    typeRaw: t.typeRaw,
                    storedAmount: t.storedAmount,
                    currency: t.currency,
                    descriptionText: t.descriptionText,
                    merchant: t.merchant,
                    date: t.date,
                    categoryId: t.categoryId,
                    accountId: t.account?.id,
                    tagsString: t.tagsString,
                    notes: t.notes,
                    isRecurring: t.isRecurring,
                    recurringFrequencyRaw: t.recurringFrequencyRaw,
                    recurringEndDate: t.recurringEndDate,
                    recurringParentId: t.recurringParentId,
                    receiptData: t.receiptData,
                    createdAt: t.createdAt,
                    updatedAt: t.updatedAt
                )
            },
            accounts: accounts.map { a in
                SyncAccount(
                    id: a.id,
                    name: a.name,
                    icon: a.icon,
                    color: a.color,
                    isDefault: a.isDefault,
                    createdAt: a.createdAt,
                    updatedAt: a.updatedAt
                )
            },
            sentAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(payload)
            try session?.send(data, toPeers: [peer], with: .reliable)
        } catch {
            syncStatus = .error("Failed to send: \(error.localizedDescription)")
        }
    }

    private func handleReceivedPayload(_ data: Data, from peer: MCPeerID) {
        guard let context = modelContext else { return }

        do {
            let payload = try JSONDecoder().decode(SyncPayload.self, from: data)
            try SyncService.mergePayload(payload, into: context)
            lastSyncDate = Date()
            syncStatus = .completed

            // If we're the advertiser (Mac), send our merged data back
            if role == .advertiser {
                sendPayload(to: peer)
            }
        } catch {
            syncStatus = .error("Merge failed: \(error.localizedDescription)")
        }
    }

    /// Merges a decoded sync payload into the given model context.
    ///
    /// - Accounts are merged first (transactions reference them).
    /// - Transactions use last-write-wins based on `updatedAt`.
    /// - New records are inserted; existing records are updated only if the incoming data is newer.
    static func mergePayload(_ payload: SyncPayload, into context: ModelContext) throws {
        // Merge accounts first (transactions reference them)
        let existingAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let existingAccountMap = Dictionary(uniqueKeysWithValues: existingAccounts.map { ($0.id, $0) })

        for syncAccount in payload.accounts {
            if let existing = existingAccountMap[syncAccount.id] {
                // Last-write-wins: update only if the incoming record was modified more recently.
                if syncAccount.updatedAt > existing.updatedAt {
                    existing.name = syncAccount.name
                    existing.icon = syncAccount.icon
                    existing.color = syncAccount.color
                    existing.isDefault = syncAccount.isDefault
                    existing.updatedAt = syncAccount.updatedAt
                }
            } else {
                let account = Account(
                    id: syncAccount.id,
                    name: syncAccount.name,
                    icon: syncAccount.icon,
                    color: syncAccount.color,
                    isDefault: syncAccount.isDefault,
                    createdAt: syncAccount.createdAt,
                    updatedAt: syncAccount.updatedAt
                )
                context.insert(account)
            }
        }

        // Re-fetch accounts after merge to link transactions
        let allAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let accountMap = Dictionary(uniqueKeysWithValues: allAccounts.map { ($0.id, $0) })

        // Merge transactions
        let existingTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let existingTransactionMap = Dictionary(uniqueKeysWithValues: existingTransactions.map { ($0.id, $0) })

        for syncTx in payload.transactions {
            if let existing = existingTransactionMap[syncTx.id] {
                // Last-write-wins
                if syncTx.updatedAt > existing.updatedAt {
                    existing.typeRaw = syncTx.typeRaw
                    existing.storedAmount = syncTx.storedAmount
                    existing.currency = syncTx.currency
                    existing.descriptionText = syncTx.descriptionText
                    existing.merchant = syncTx.merchant
                    existing.date = syncTx.date
                    existing.categoryId = syncTx.categoryId
                    existing.account = syncTx.accountId.flatMap { accountMap[$0] }
                    existing.tagsString = syncTx.tagsString
                    existing.notes = syncTx.notes
                    existing.isRecurring = syncTx.isRecurring
                    existing.recurringFrequencyRaw = syncTx.recurringFrequencyRaw
                    existing.recurringEndDate = syncTx.recurringEndDate
                    existing.recurringParentId = syncTx.recurringParentId
                    existing.receiptData = syncTx.receiptData
                    existing.updatedAt = syncTx.updatedAt
                }
            } else {
                let transaction = Transaction(
                    id: syncTx.id,
                    type: TransactionType(rawValue: syncTx.typeRaw) ?? .expense,
                    amount: syncTx.storedAmount,
                    currency: syncTx.currency,
                    descriptionText: syncTx.descriptionText,
                    merchant: syncTx.merchant,
                    date: syncTx.date,
                    categoryId: syncTx.categoryId,
                    account: syncTx.accountId.flatMap { accountMap[$0] },
                    tags: syncTx.tagsString.isEmpty ? [] : syncTx.tagsString.components(separatedBy: ","),
                    notes: syncTx.notes,
                    isRecurring: syncTx.isRecurring,
                    recurringFrequency: syncTx.recurringFrequencyRaw.flatMap { RecurringFrequency(rawValue: $0) },
                    recurringEndDate: syncTx.recurringEndDate,
                    recurringParentId: syncTx.recurringParentId,
                    receiptData: syncTx.receiptData,
                    createdAt: syncTx.createdAt,
                    updatedAt: syncTx.updatedAt
                )
                context.insert(transaction)
            }
        }

        try context.save()
    }
}

// MARK: - MCSessionDelegate

extension SyncService: MCSessionDelegate {
    public nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                connectedPeerName = peerID.displayName
                syncStatus = .completed
                // iOS auto-sends on connect
                if role == .browser {
                    sendPayload(to: peerID)
                }
            case .notConnected:
                connectedPeerName = nil
                if isActive {
                    syncStatus = role == .advertiser ? .advertising : .browsing
                }
            case .connecting:
                syncStatus = .connecting
            @unknown default:
                break
            }
        }
    }

    public nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            handleReceivedPayload(data, from: peerID)
        }
    }

    public nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SyncService: MCNearbyServiceAdvertiserDelegate {
    public nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations from nearby peers
        Task { @MainActor in
            invitationHandler(true, session)
        }
    }

    public nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            syncStatus = .error("Advertising failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SyncService: MCNearbyServiceBrowserDelegate {
    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Auto-invite discovered peers
        Task { @MainActor in
            guard let session = session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            if connectedPeerName == peerID.displayName {
                connectedPeerName = nil
            }
        }
    }

    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            syncStatus = .error("Browsing failed: \(error.localizedDescription)")
        }
    }
}
