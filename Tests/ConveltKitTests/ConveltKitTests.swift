import Testing
@testable import ConveltKit
import Foundation

@Test func configurationBuilds() async throws {
    let config = ConveltConfiguration(
        baseURL: URL(string: "https://example.com")!,
        publicSDKKey: "key",
        appEnvironmentID: UUID(),
        bundleID: "ai.lingospeak.one",
        appVersion: "1.0.0",
        buildNumber: "1"
    )
    let _ = ConveltClient(configuration: config)
}

@Test func outcomeMappingIsDeterministic() async throws {
    let cases: [(String, ConveltResolvedOutcome)] = [
        ("access_granted", .active),
        ("already_active", .active),
        ("already_processed", .alreadyProcessed),
        ("store_user_cancelled", .purchaseCancelled),
        ("no_purchases_found", .noActivePurchases),
        ("store_pending_approval", .pendingApproval),
        ("billing_retry_in_progress", .retrying),
        ("verification_retry_scheduled", .retrying),
        ("verification_failed_terminal", .terminalFailure),
        ("ownership_conflict", .terminalFailure),
    ]

    for (outcome, expected) in cases {
        let response = ConveltOutcomeResponse(
            outcome: outcome,
            displayClass: "test",
            retryable: false,
            readyToFinish: true,
            snapshot: nil
        )
        #expect(response.resolvedOutcome == expected)
    }

    let unknown = ConveltOutcomeResponse(
        outcome: "custom_future_outcome",
        displayClass: "test",
        retryable: false,
        readyToFinish: true,
        snapshot: nil
    )
    #expect(unknown.resolvedOutcome == .unknown("custom_future_outcome"))
}

@Test func userIdentityResolverReusesCustomerIDAndAppAccountToken() async throws {
    let suiteName = "convelt-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let resolver = ConveltUserIdentityResolver(
        defaults: defaults,
        keyPrefix: "convelt.test.customer.",
        salt: "convelt.test.salt"
    )

    let first = try await resolver.resolve(externalUserID: " google:user-1 ")
    let second = try await resolver.resolve(externalUserID: "google:user-1")

    #expect(first.externalUserID == "google:user-1")
    #expect(first.customerID == second.customerID)
    #expect(first.appAccountToken == first.customerID)
}

@Test func fileOutboxStoreRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("outbox.json")
    let store = FileConveltOutboxStore(fileURL: url)

    let upload = ConveltAppleTransactionUpload(
        installationID: UUID(),
        customerID: UUID(),
        externalUserID: "google:user-1",
        transactionID: "tx-1",
        originalTransactionID: "otx-1",
        productID: "ai.lingospeak.pro.monthly",
        signedPayload: "signed",
        appAccountToken: UUID(),
        environment: .sandbox,
        idempotencyKey: "idem-1"
    )
    let entries = [
        ConveltPendingTransactionUpload(
            queuedAt: Date(),
            upload: ConveltAppleTransactionUploadCodable(from: upload)
        )
    ]
    try await store.save(entries)

    let loaded = try await store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].upload.transactionID == "tx-1")
}

@Test func fileOutboxStoreLoadsSnakeCaseFixture() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let url = directory.appendingPathComponent("outbox.json")
    let store = FileConveltOutboxStore(fileURL: url)

    let json = """
    [
      {
        "queued_at": "2026-05-06T21:06:29Z",
        "upload": {
          "installation_id": "11111111-1111-1111-1111-111111111111",
          "customer_id": "22222222-2222-2222-2222-222222222222",
          "external_user_id": "google:user-1",
          "transaction_id": "tx-1",
          "original_transaction_id": "otx-1",
          "product_id": "ai.lingospeak.pro.monthly",
          "signed_payload": "signed",
          "app_account_token": "33333333-3333-3333-3333-333333333333",
          "environment": "sandbox",
          "idempotency_key": "idem-1"
        }
      }
    ]
    """
    guard let data = json.data(using: .utf8) else {
        throw NSError(domain: "ConveltKitTests", code: 1)
    }
    try data.write(to: url)

    let loaded = try await store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].upload.installationID.uuidString == "11111111-1111-1111-1111-111111111111")
    #expect(loaded[0].upload.customerID.uuidString == "22222222-2222-2222-2222-222222222222")
    #expect(loaded[0].upload.appAccountToken.uuidString == "33333333-3333-3333-3333-333333333333")
}

@Test func userBindingMismatchBlocksOutboxEnqueue() async throws {
    let config = ConveltConfiguration(
        baseURL: URL(string: "https://example.com")!,
        publicSDKKey: "key",
        appEnvironmentID: UUID(),
        bundleID: "ai.lingospeak.one",
        appVersion: "1.0.0",
        buildNumber: "1"
    )
    let client = ConveltClient(
        configuration: config,
        outboxStore: InMemoryConveltOutboxStore()
    )
    await client.bindSignedInUser(externalUserID: "google:user-1")

    let upload = ConveltAppleTransactionUpload(
        installationID: UUID(),
        customerID: UUID(),
        externalUserID: "google:user-2",
        transactionID: "tx-2",
        originalTransactionID: "otx-2",
        productID: "ai.lingospeak.pro.monthly",
        signedPayload: "signed",
        appAccountToken: UUID(),
        environment: .sandbox,
        idempotencyKey: "idem-2"
    )

    do {
        try await client.enqueueAppleTransactionUpload(upload)
        Issue.record("expected userBindingMismatch error")
    } catch let error as ConveltClientError {
        if case .userBindingMismatch = error {
            // expected
        } else {
            Issue.record("unexpected ConveltClientError case: \(error)")
        }
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
}
