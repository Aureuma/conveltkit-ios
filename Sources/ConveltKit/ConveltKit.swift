import Foundation
#if canImport(StoreKit)
import StoreKit
#endif
import CryptoKit

public enum ConveltEnvironment: String, Sendable, Codable {
    case sandbox
    case production
}

public struct ConveltConfiguration: Sendable {
    public let baseURL: URL
    public let publicSDKKey: String
    public let appEnvironmentID: UUID
    public let appCode: String
    public let bundleID: String
    public let appVersion: String
    public let buildNumber: String

    public init(
        baseURL: URL,
        publicSDKKey: String,
        appEnvironmentID: UUID,
        appCode: String = "lingospeak",
        bundleID: String,
        appVersion: String,
        buildNumber: String
    ) {
        self.baseURL = baseURL
        self.publicSDKKey = publicSDKKey
        self.appEnvironmentID = appEnvironmentID
        self.appCode = appCode
        self.bundleID = bundleID
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}

public struct ConveltBootstrapResponse: Sendable, Codable {
    public let contractVersion: String
    public let configVersion: String
    public let appEnvironmentID: UUID
    public let placement: String
    public let productIDs: [String]
    public let entitlementKeys: [String]
    public let snapshot: ConveltEntitlementSnapshot?
}

public struct ConveltEntitlementSnapshot: Sendable, Codable {
    public let customerID: UUID
    public let externalUserID: String?
    public let appEnvironmentID: UUID
    public let environment: ConveltEnvironment
    public let snapshotVersion: Int64
    public let signatureAlgorithm: String?
    public let signature: String?
    public let issuedAt: Date
    public let expiresAt: Date
    public let entitlements: [ConveltEntitlementEntry]
}

public struct ConveltEntitlementEntry: Sendable, Codable {
    public let key: String
    public let providerState: String
    public let accessState: String
    public let active: Bool
    public let productID: String?
    public let renewsAt: Date?
    public let expiresAt: Date?
    public let isSandbox: Bool
    public let ownershipStatus: String
    public let verification: String
}

public struct ConveltOutcomeResponse: Sendable, Codable {
    public let outcome: String
    public let displayClass: String
    public let retryable: Bool
    public let readyToFinish: Bool
    public let failureReason: String?
    public let requestID: String?
    public let snapshot: ConveltEntitlementSnapshot?

    public init(
        outcome: String,
        displayClass: String,
        retryable: Bool,
        readyToFinish: Bool,
        failureReason: String? = nil,
        requestID: String? = nil,
        snapshot: ConveltEntitlementSnapshot?
    ) {
        self.outcome = outcome
        self.displayClass = displayClass
        self.retryable = retryable
        self.readyToFinish = readyToFinish
        self.failureReason = failureReason
        self.requestID = requestID
        self.snapshot = snapshot
    }

    public var resolvedOutcome: ConveltResolvedOutcome {
        switch outcome {
        case "access_granted", "already_active":
            return .active
        case "already_processed":
            return .alreadyProcessed
        case "store_user_cancelled":
            return .purchaseCancelled
        case "no_purchases_found":
            return .noActivePurchases
        case "store_pending_approval":
            return .pendingApproval
        case "billing_retry_in_progress", "verification_retry_scheduled":
            return .retrying
        case "verification_failed_terminal", "ownership_conflict":
            return .terminalFailure
        default:
            return .unknown(outcome)
        }
    }
}

public enum ConveltResolvedOutcome: Sendable, Equatable {
    case active
    case alreadyProcessed
    case purchaseCancelled
    case noActivePurchases
    case pendingApproval
    case retrying
    case terminalFailure
    case unknown(String)
}

public struct ConveltUserIdentity: Sendable, Equatable {
    public let externalUserID: String
    public let customerID: UUID
    public let appAccountToken: UUID

    public init(
        externalUserID: String,
        customerID: UUID,
        appAccountToken: UUID? = nil
    ) {
        self.externalUserID = externalUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.customerID = customerID
        self.appAccountToken = appAccountToken ?? customerID
    }
}

public actor ConveltUserIdentityResolver {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let salt: String

    public init(
        defaults: UserDefaults = .standard,
        keyPrefix: String,
        salt: String
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.salt = salt
    }

    public func resolve(externalUserID rawExternalUserID: String) throws -> ConveltUserIdentity {
        let externalUserID = rawExternalUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !externalUserID.isEmpty else {
            throw ConveltClientError.userIdentityUnavailable
        }

        let key = keyPrefix + externalUserID
        if let existing = defaults.string(forKey: key),
           let parsed = UUID(uuidString: existing) {
            return ConveltUserIdentity(externalUserID: externalUserID, customerID: parsed)
        }

        let created = Self.deterministicCustomerID(externalUserID: externalUserID, salt: salt)
        defaults.set(created.uuidString, forKey: key)
        return ConveltUserIdentity(externalUserID: externalUserID, customerID: created)
    }

    @discardableResult
    public func adoptCanonicalCustomerID(
        externalUserID rawExternalUserID: String,
        customerID: UUID
    ) throws -> Bool {
        let externalUserID = rawExternalUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !externalUserID.isEmpty else {
            throw ConveltClientError.userIdentityUnavailable
        }
        let key = keyPrefix + externalUserID
        let existing = defaults.string(forKey: key)
        if existing == customerID.uuidString {
            return false
        }
        defaults.set(customerID.uuidString, forKey: key)
        return true
    }

    public nonisolated static func deterministicCustomerID(
        externalUserID: String,
        salt: String
    ) -> UUID {
        let digest = SHA256.hash(data: Data("\(salt):\(externalUserID)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

public struct ConveltAppleTransactionUpload: Sendable {
    public let installationID: UUID
    public let customerID: UUID
    public let externalUserID: String?
    public let transactionID: String
    public let originalTransactionID: String
    public let productID: String
    public let signedPayload: String
    public let appAccountToken: UUID
    public let environment: ConveltEnvironment
    public let idempotencyKey: String

    public init(
        installationID: UUID,
        customerID: UUID,
        externalUserID: String?,
        transactionID: String,
        originalTransactionID: String,
        productID: String,
        signedPayload: String,
        appAccountToken: UUID,
        environment: ConveltEnvironment,
        idempotencyKey: String
    ) {
        self.installationID = installationID
        self.customerID = customerID
        self.externalUserID = externalUserID
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.productID = productID
        self.signedPayload = signedPayload
        self.appAccountToken = appAccountToken
        self.environment = environment
        self.idempotencyKey = idempotencyKey
    }
}

public struct ConveltPendingTransactionUpload: Sendable, Codable {
    public let queuedAt: Date
    public let upload: ConveltAppleTransactionUploadCodable
}

public struct ConveltAppleTransactionUploadCodable: Sendable, Codable {
    public let installationID: UUID
    public let customerID: UUID
    public let externalUserID: String?
    public let transactionID: String
    public let originalTransactionID: String
    public let productID: String
    public let signedPayload: String
    public let appAccountToken: UUID
    public let environment: ConveltEnvironment
    public let idempotencyKey: String

    init(from upload: ConveltAppleTransactionUpload) {
        installationID = upload.installationID
        customerID = upload.customerID
        externalUserID = upload.externalUserID
        transactionID = upload.transactionID
        originalTransactionID = upload.originalTransactionID
        productID = upload.productID
        signedPayload = upload.signedPayload
        appAccountToken = upload.appAccountToken
        environment = upload.environment
        idempotencyKey = upload.idempotencyKey
    }

    var upload: ConveltAppleTransactionUpload {
        ConveltAppleTransactionUpload(
            installationID: installationID,
            customerID: customerID,
            externalUserID: externalUserID,
            transactionID: transactionID,
            originalTransactionID: originalTransactionID,
            productID: productID,
            signedPayload: signedPayload,
            appAccountToken: appAccountToken,
            environment: environment,
            idempotencyKey: idempotencyKey
        )
    }
}

public protocol ConveltOutboxStore: Sendable {
    func load() async throws -> [ConveltPendingTransactionUpload]
    func save(_ entries: [ConveltPendingTransactionUpload]) async throws
}

public actor FileConveltOutboxStore: ConveltOutboxStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() async throws -> [ConveltPendingTransactionUpload] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.convelt.decode([ConveltPendingTransactionUpload].self, from: data)
    }

    public func save(_ entries: [ConveltPendingTransactionUpload]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try JSONEncoder.convelt.encode(entries)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    public static func defaultURL(appGroupIdentifier: String? = nil) -> URL {
        let baseDirectory: URL
        if let appGroupIdentifier,
           let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
           ) {
            baseDirectory = groupURL
        } else {
            baseDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
        }
        return baseDirectory
            .appendingPathComponent("convelt", isDirectory: true)
            .appendingPathComponent("transaction-outbox.json", isDirectory: false)
    }
}

public actor InMemoryConveltOutboxStore: ConveltOutboxStore {
    private var entries: [ConveltPendingTransactionUpload] = []

    public init() {}

    public func load() async throws -> [ConveltPendingTransactionUpload] {
        entries
    }

    public func save(_ entries: [ConveltPendingTransactionUpload]) async throws {
        self.entries = entries
    }
}

public actor ConveltClient {
    private let configuration: ConveltConfiguration
    private let outboxStore: any ConveltOutboxStore
    private var latestSnapshotByCustomerID: [UUID: ConveltEntitlementSnapshot] = [:]
    private var boundExternalUserID: String?
    private var authorizationBearerToken: String?
    private var pendingUploads: [ConveltPendingTransactionUpload] = []
    private var outboxLoaded = false

    public init(
        configuration: ConveltConfiguration,
        outboxStore: any ConveltOutboxStore = InMemoryConveltOutboxStore()
    ) {
        self.configuration = configuration
        self.outboxStore = outboxStore
    }

    public func bindSignedInUser(externalUserID: String?) {
        boundExternalUserID = externalUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func bindAuthorizationBearerToken(_ token: String?) {
        let normalized = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        authorizationBearerToken = normalized?.isEmpty == false ? normalized : nil
    }

    public func bootstrap(installationID: UUID) async throws -> ConveltBootstrapResponse {
        struct Request: Codable {
            let appEnvironmentID: UUID
            let appCode: String
            let bundleID: String
            let appVersion: String
            let buildNumber: String
            let installationID: UUID
            let sdkKey: String
            let sdkVersion: String?
            let supportedContractVersions: [String]
        }

        let payload = Request(
            appEnvironmentID: configuration.appEnvironmentID,
            appCode: configuration.appCode,
            bundleID: configuration.bundleID,
            appVersion: configuration.appVersion,
            buildNumber: configuration.buildNumber,
            installationID: installationID,
            sdkKey: configuration.publicSDKKey,
            sdkVersion: ConveltSDKBuildInfo.workspaceVersion,
            supportedContractVersions: ["1.0.0"]
        )

        let response: ConveltBootstrapResponse = try await request(
            path: "/v1/client/bootstrap",
            method: "POST",
            body: payload
        )

        if let snapshot = response.snapshot {
            latestSnapshotByCustomerID[snapshot.customerID] = snapshot
        }
        return response
    }

    public func enqueueAppleTransactionUpload(
        _ upload: ConveltAppleTransactionUpload
    ) async throws {
        try assertUserBindingMatches(uploadExternalUserID: upload.externalUserID)
        try await ensureOutboxLoaded()
        pendingUploads.append(
            ConveltPendingTransactionUpload(
                queuedAt: Date(),
                upload: ConveltAppleTransactionUploadCodable(from: upload)
            )
        )
        try await outboxStore.save(pendingUploads)
    }

    public func drainPendingTransactionUploads() async throws -> [ConveltOutcomeResponse] {
        try await ensureOutboxLoaded()
        if pendingUploads.isEmpty {
            return []
        }

        var remaining: [ConveltPendingTransactionUpload] = []
        var outcomes: [ConveltOutcomeResponse] = []

        for (index, pending) in pendingUploads.enumerated() {
            do {
                let outcome = try await uploadAppleTransaction(pending.upload.upload)
                outcomes.append(outcome)
                if outcome.retryable && !outcome.readyToFinish {
                    remaining.append(pending)
                    if index + 1 < pendingUploads.count {
                        remaining.append(contentsOf: pendingUploads[(index + 1)...])
                    }
                    break
                }
            } catch {
                if let clientError = error as? ConveltClientError {
                    let outcome = Self.outcomeForClientError(clientError)
                    outcomes.append(outcome)
                    if outcome.retryable && !outcome.readyToFinish {
                        remaining.append(pending)
                        if index + 1 < pendingUploads.count {
                            remaining.append(contentsOf: pendingUploads[(index + 1)...])
                        }
                        break
                    }
                    continue
                }
                remaining.append(pending)
                if index + 1 < pendingUploads.count {
                    remaining.append(contentsOf: pendingUploads[(index + 1)...])
                }
                break
            }
        }

        pendingUploads = remaining
        try await outboxStore.save(remaining)
        return outcomes
    }

    public func uploadAppleTransaction(
        _ upload: ConveltAppleTransactionUpload
    ) async throws -> ConveltOutcomeResponse {
        try assertUserBindingMatches(uploadExternalUserID: upload.externalUserID)

        struct Request: Codable {
            let appEnvironmentID: UUID
            let installationID: UUID
            let customerID: UUID
            let externalUserID: String?
            let transactionID: String
            let originalTransactionID: String
            let productID: String
            let signedPayload: String
            let appAccountToken: UUID
            let environment: ConveltEnvironment
            let idempotencyKey: String
        }

        let body = Request(
            appEnvironmentID: configuration.appEnvironmentID,
            installationID: upload.installationID,
            customerID: upload.customerID,
            externalUserID: upload.externalUserID ?? boundExternalUserID,
            transactionID: upload.transactionID,
            originalTransactionID: upload.originalTransactionID,
            productID: upload.productID,
            signedPayload: upload.signedPayload,
            appAccountToken: upload.appAccountToken,
            environment: upload.environment,
            idempotencyKey: upload.idempotencyKey
        )

        let outcome: ConveltOutcomeResponse = try await request(
            path: "/v1/client/apple/transactions",
            method: "POST",
            body: body,
            idempotencyKey: upload.idempotencyKey
        )
        if let snapshot = outcome.snapshot {
            latestSnapshotByCustomerID[snapshot.customerID] = snapshot
        }
        return outcome
    }

    public func syncEntitlements(
        customerID: UUID,
        externalUserID: String?,
        reason: String
    ) async throws -> ConveltOutcomeResponse {
        let requestExternalUserID = externalUserID ?? boundExternalUserID
        try assertUserBindingMatches(uploadExternalUserID: requestExternalUserID)

        struct Request: Codable {
            let appEnvironmentID: UUID
            let customerID: UUID
            let externalUserID: String?
            let reason: String
        }

        let body = Request(
            appEnvironmentID: configuration.appEnvironmentID,
            customerID: customerID,
            externalUserID: requestExternalUserID,
            reason: reason
        )
        let outcome: ConveltOutcomeResponse = try await request(
            path: "/v1/client/entitlements/sync",
            method: "POST",
            body: body
        )
        if let snapshot = outcome.snapshot {
            latestSnapshotByCustomerID[snapshot.customerID] = snapshot
        }
        return outcome
    }

    public func syncEntitlements(
        identity: ConveltUserIdentity,
        reason: String
    ) async throws -> ConveltOutcomeResponse {
        try await syncEntitlements(
            customerID: identity.customerID,
            externalUserID: identity.externalUserID,
            reason: reason
        )
    }

    public func currentEntitlements(customerID: UUID) async throws -> ConveltEntitlementSnapshot? {
        let requestExternalUserID = boundExternalUserID
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent("/v1/client/entitlements/current"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "app_environment_id", value: configuration.appEnvironmentID.uuidString),
            URLQueryItem(name: "customer_id", value: customerID.uuidString),
        ]
        if let requestExternalUserID, !requestExternalUserID.isEmpty {
            queryItems.append(
                URLQueryItem(name: "external_user_id", value: requestExternalUserID)
            )
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw ConveltClientError.invalidRequest
        }

        let snapshot: ConveltEntitlementSnapshot? = try await request(
            url: url,
            method: "GET",
            body: Optional<String>.none
        )
        if let snapshot {
            latestSnapshotByCustomerID[snapshot.customerID] = snapshot
        }
        return snapshot
    }

    public func cachedEntitlements(customerID: UUID) -> ConveltEntitlementSnapshot? {
        latestSnapshotByCustomerID[customerID]
    }

    public func pendingUploadCount() async throws -> Int {
        try await ensureOutboxLoaded()
        return pendingUploads.count
    }

#if canImport(StoreKit)
    public func loadStoreKitProducts(productIDs: [String]) async throws -> [Product] {
        let uniqueIDs = Array(Set(productIDs)).sorted()
        guard !uniqueIDs.isEmpty else {
            return []
        }
        return try await Product.products(for: uniqueIDs)
    }

    public func purchaseStoreKitProduct(
        _ product: Product,
        installationID: UUID,
        customerID: UUID,
        externalUserID: String?,
        appAccountToken: UUID,
        idempotencyKey: String = UUID().uuidString
    ) async throws -> ConveltOutcomeResponse {
        _ = idempotencyKey
        let purchaseResult: Product.PurchaseResult
        do {
            purchaseResult = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        } catch {
            return Self.retryingOutcome()
        }

        switch purchaseResult {
        case .pending:
            return Self.pendingApprovalOutcome()
        case .userCancelled:
            return Self.cancelledOutcome()
        case .success(let verification):
            do {
                let transaction = try self.verifiedTransaction(from: verification)
                let signedPayload = verification.jwsRepresentation
                return try await processVerifiedStoreKitTransaction(
                    transaction,
                    signedPayload: signedPayload,
                    installationID: installationID,
                    customerID: customerID,
                    externalUserID: externalUserID,
                    appAccountToken: appAccountToken
                )
            } catch let error as ConveltClientError {
                return Self.outcomeForClientError(error)
            } catch {
                return Self.retryingOutcome(failureReason: "purchase_processing_error")
            }
        @unknown default:
            return Self.retryingOutcome()
        }
    }

    public func purchaseStoreKitProduct(
        _ product: Product,
        installationID: UUID,
        identity: ConveltUserIdentity,
        idempotencyKey: String = UUID().uuidString
    ) async throws -> ConveltOutcomeResponse {
        try await purchaseStoreKitProduct(
            product,
            installationID: installationID,
            customerID: identity.customerID,
            externalUserID: identity.externalUserID,
            appAccountToken: identity.appAccountToken,
            idempotencyKey: idempotencyKey
        )
    }

    public func restoreFromCurrentEntitlements(
        installationID: UUID,
        customerID: UUID,
        externalUserID: String?,
        appAccountToken: UUID
    ) async throws -> ConveltOutcomeResponse {
        var outcome: ConveltOutcomeResponse = Self.noPurchasesFoundOutcome()
        var sawAnyVerifiedTransaction = false
        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: verification) else {
                continue
            }
            let signedPayload = verification.jwsRepresentation
            sawAnyVerifiedTransaction = true
            let candidate = try await processVerifiedStoreKitTransaction(
                transaction,
                signedPayload: signedPayload,
                installationID: installationID,
                customerID: customerID,
                externalUserID: externalUserID,
                appAccountToken: appAccountToken
            )
            outcome = Self.preferredRestoreOutcome(current: outcome, candidate: candidate)
        }
        if !sawAnyVerifiedTransaction {
            return Self.noPurchasesFoundOutcome()
        }
        return outcome
    }

    public func restoreFromCurrentEntitlements(
        installationID: UUID,
        identity: ConveltUserIdentity
    ) async throws -> ConveltOutcomeResponse {
        try await restoreFromCurrentEntitlements(
            installationID: installationID,
            customerID: identity.customerID,
            externalUserID: identity.externalUserID,
            appAccountToken: identity.appAccountToken
        )
    }

    public func startTransactionUpdatesObserver(
        installationID: UUID,
        customerID: UUID,
        externalUserID: String?,
        appAccountToken: UUID,
        onOutcome: @escaping @Sendable (Result<ConveltOutcomeResponse, Error>) -> Void
    ) -> Task<Void, Never> {
        Task {
            for await verification in Transaction.updates {
                do {
                    let transaction = try self.verifiedTransaction(from: verification)
                    let signedPayload = verification.jwsRepresentation
                    let outcome = try await self.processVerifiedStoreKitTransaction(
                        transaction,
                        signedPayload: signedPayload,
                        installationID: installationID,
                        customerID: customerID,
                        externalUserID: externalUserID,
                        appAccountToken: appAccountToken
                    )
                    onOutcome(.success(outcome))
                } catch {
                    onOutcome(.failure(error))
                }
            }
        }
    }

    public func startTransactionUpdatesObserver(
        installationID: UUID,
        identityProvider: @escaping @Sendable () async throws -> ConveltUserIdentity,
        onOutcome: @escaping @Sendable (Result<ConveltOutcomeResponse, Error>) -> Void
    ) -> Task<Void, Never> {
        Task {
            for await verification in Transaction.updates {
                do {
                    let identity = try await identityProvider()
                    let transaction = try self.verifiedTransaction(from: verification)
                    let signedPayload = verification.jwsRepresentation
                    let outcome = try await self.processVerifiedStoreKitTransaction(
                        transaction,
                        signedPayload: signedPayload,
                        installationID: installationID,
                        customerID: identity.customerID,
                        externalUserID: identity.externalUserID,
                        appAccountToken: identity.appAccountToken
                    )
                    onOutcome(.success(outcome))
                } catch {
                    onOutcome(.failure(error))
                }
            }
        }
    }

    private func processVerifiedStoreKitTransaction(
        _ transaction: Transaction,
        signedPayload: String,
        installationID: UUID,
        customerID: UUID,
        externalUserID: String?,
        appAccountToken: UUID
    ) async throws -> ConveltOutcomeResponse {
        let idempotencyKey = Self.stableStoreKitUploadIdempotencyKey(
            appEnvironmentID: configuration.appEnvironmentID,
            originalTransactionID: String(transaction.originalID),
            transactionID: String(transaction.id),
            productID: transaction.productID
        )
        let upload = ConveltAppleTransactionUpload(
            installationID: installationID,
            customerID: customerID,
            externalUserID: externalUserID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            productID: transaction.productID,
            signedPayload: signedPayload,
            appAccountToken: appAccountToken,
            environment: mapStoreKitEnvironment(transaction.environment),
            idempotencyKey: idempotencyKey
        )

        try await enqueueAppleTransactionUpload(upload)
        let outcomes = try await drainPendingTransactionUploads()
        let latest = outcomes.last ?? Self.retryingOutcome()
        if latest.readyToFinish || !latest.retryable {
            await transaction.finish()
        }
        return latest
    }

    public static func stableStoreKitUploadIdempotencyKey(
        appEnvironmentID: UUID,
        originalTransactionID: String,
        transactionID: String,
        productID: String
    ) -> String {
        let normalizedOriginalTransactionID = originalTransactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTransactionID = transactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedProductID = productID.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = [
            "apple_tx",
            appEnvironmentID.uuidString.lowercased(),
            normalizedOriginalTransactionID,
            normalizedTransactionID,
            normalizedProductID
        ].joined(separator: ":")
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "apple-tx-\(hex)"
    }

    private func verifiedTransaction(
        from verification: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw ConveltClientError.storeKitVerificationFailed
        }
    }

    private func mapStoreKitEnvironment(_ environment: AppStore.Environment) -> ConveltEnvironment {
        switch environment {
        case .production:
            return .production
        case .sandbox:
            return .sandbox
        default:
            return .sandbox
        }
    }
#endif

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        try await request(
            url: configuration.baseURL.appendingPathComponent(path),
            method: method,
            body: body,
            idempotencyKey: idempotencyKey
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        url: URL,
        method: String,
        body: Body,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publicSDKKey, forHTTPHeaderField: "x-convelt-sdk-key")
        if let authorizationBearerToken {
            request.setValue("Bearer \(authorizationBearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if method != "GET" {
            request.httpBody = try JSONEncoder.convelt.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ConveltClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw ConveltClientError.httpStatus(
                http.statusCode,
                extractErrorCode(from: data)
            )
        }

        do {
            return try JSONDecoder.convelt.decode(Response.self, from: data)
        } catch {
            throw ConveltClientError.decodeFailed
        }
    }

    private func ensureOutboxLoaded() async throws {
        if outboxLoaded {
            return
        }
        pendingUploads = try await outboxStore.load()
        outboxLoaded = true
    }

    private func assertUserBindingMatches(uploadExternalUserID: String?) throws {
        guard let boundExternalUserID, !boundExternalUserID.isEmpty else {
            return
        }
        if let uploadExternalUserID,
           !uploadExternalUserID.isEmpty,
           uploadExternalUserID != boundExternalUserID {
            throw ConveltClientError.userBindingMismatch
        }
    }

    private static func cancelledOutcome() -> ConveltOutcomeResponse {
        ConveltOutcomeResponse(
            outcome: "store_user_cancelled",
            displayClass: "cancelled",
            retryable: false,
            readyToFinish: true,
            snapshot: nil
        )
    }

    private static func pendingApprovalOutcome() -> ConveltOutcomeResponse {
        ConveltOutcomeResponse(
            outcome: "store_pending_approval",
            displayClass: "pending",
            retryable: true,
            readyToFinish: false,
            snapshot: nil
        )
    }

    private static func retryingOutcome(
        failureReason: String? = nil
    ) -> ConveltOutcomeResponse {
        ConveltOutcomeResponse(
            outcome: "verification_retry_scheduled",
            displayClass: "retrying",
            retryable: true,
            readyToFinish: false,
            failureReason: failureReason,
            snapshot: nil
        )
    }

    private static func terminalFailureOutcome(
        failureReason: String? = nil
    ) -> ConveltOutcomeResponse {
        ConveltOutcomeResponse(
            outcome: "verification_failed_terminal",
            displayClass: "terminal",
            retryable: false,
            readyToFinish: true,
            failureReason: failureReason,
            snapshot: nil
        )
    }

    private static func noPurchasesFoundOutcome() -> ConveltOutcomeResponse {
        ConveltOutcomeResponse(
            outcome: "no_purchases_found",
            displayClass: "inactive",
            retryable: false,
            readyToFinish: true,
            snapshot: nil
        )
    }

    private static func preferredRestoreOutcome(
        current: ConveltOutcomeResponse,
        candidate: ConveltOutcomeResponse
    ) -> ConveltOutcomeResponse {
        let score = { (outcome: ConveltOutcomeResponse) -> Int in
            switch outcome.resolvedOutcome {
            case .active, .alreadyProcessed:
                return 100
            case .pendingApproval:
                return 70
            case .retrying:
                return 60
            case .terminalFailure:
                return 40
            case .noActivePurchases:
                return 20
            case .purchaseCancelled:
                return 10
            case .unknown:
                return 0
            }
        }
        return score(candidate) >= score(current) ? candidate : current
    }

    private static func outcomeForClientError(_ error: ConveltClientError) -> ConveltOutcomeResponse {
        switch error {
        case let .httpStatus(status, errorCode):
            if status >= 500 {
                return retryingOutcome(failureReason: errorCode ?? "backend_unavailable")
            }
            if status == 429 {
                return retryingOutcome(failureReason: errorCode ?? "rate_limited")
            }
            return terminalFailureOutcome(failureReason: errorCode ?? "client_http_\(status)")
        case .invalidResponse, .decodeFailed:
            return retryingOutcome(failureReason: "backend_invalid_response")
        case .invalidRequest, .userIdentityUnavailable, .userBindingMismatch:
            return terminalFailureOutcome(failureReason: "client_request_invalid")
        case .storeKitVerificationFailed:
            return terminalFailureOutcome(failureReason: "storekit_local_verification_failed")
        }
    }

    private func extractErrorCode(from data: Data) -> String? {
        guard
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let raw = parsed["error"] as? String
        else {
            return nil
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

public enum ConveltClientError: Error, Sendable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int, String?)
    case userIdentityUnavailable
    case userBindingMismatch
    case storeKitVerificationFailed
    case decodeFailed
}

private extension JSONEncoder {
    static var convelt: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var convelt: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { codingPath in
            let lastKey = codingPath.last!
            let normalized = normalizeSnakeCaseKey(lastKey.stringValue)
            return AnyCodingKey(stringValue: normalized) ?? lastKey
        }
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private enum ConveltSDKBuildInfo {
    static let workspaceVersion: String? = {
        let fileURL = URL(fileURLWithPath: #filePath)
        // ConveltKit.swift -> ConveltKit -> Sources -> ConveltKit -> swift -> sdks -> repo root
        let repoRoot = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cargoURL = repoRoot.appendingPathComponent("Cargo.toml")
        guard let contents = try? String(contentsOf: cargoURL, encoding: .utf8) else {
            return nil
        }
        var inWorkspacePackage = false
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inWorkspacePackage = (line == "[workspace.package]")
                continue
            }
            guard inWorkspacePackage, line.hasPrefix("version") else {
                continue
            }
            guard let equals = line.firstIndex(of: "=") else {
                continue
            }
            let rawValue = line[line.index(after: equals)...]
            let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
                return String(trimmed.dropFirst().dropLast())
            }
        }
        return nil
    }()
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private func normalizeSnakeCaseKey(_ key: String) -> String {
    let parts = key
        .split(separator: "_")
        .map(String.init)
        .filter { !$0.isEmpty }
    guard let first = parts.first else {
        return key
    }

    var camel = first.lowercased()
    for part in parts.dropFirst() {
        camel += part.prefix(1).uppercased() + part.dropFirst().lowercased()
    }

    // Preserve acronym-heavy API field spellings used by the SDK models.
    let replacements = [
        "Id": "ID",
        "Url": "URL",
        "Uuid": "UUID",
        "Api": "API",
        "Sdk": "SDK",
    ]
    for (needle, replacement) in replacements {
        camel = camel.replacingOccurrences(of: needle, with: replacement)
    }
    return camel
}
