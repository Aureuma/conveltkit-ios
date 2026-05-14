import Testing
@testable import ConveltKit
import Foundation

@Test func publicOutcomeFailureReasonCompiles() async throws {
    let response = ConveltOutcomeResponse(
        outcome: "verification_failed_terminal",
        displayClass: "warning",
        retryable: false,
        readyToFinish: true,
        failureReason: "provider_failed",
        requestID: "req-1",
        snapshot: nil
    )
    #expect(response.failureReason == "provider_failed")
}

@Test func publicClientErrorSurfaceCompiles() async throws {
    let status: ConveltClientError = .httpStatus(500, "backend_unavailable")
    switch status {
    case .httpStatus(let code, let body):
        #expect(code == 500)
        #expect(body == "backend_unavailable")
    default:
        Issue.record("unexpected case")
    }

    let decode: ConveltClientError = .decodeFailed
    switch decode {
    case .decodeFailed:
        break
    default:
        Issue.record("unexpected case")
    }
}

@Test func identityResolverSurfaceCompiles() async throws {
    let suite = "convelt-api-surface-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let resolver = ConveltUserIdentityResolver(
        defaults: defaults,
        keyPrefix: "convelt.user.",
        salt: "convelt.salt"
    )
    let resolved = try await resolver.resolve(externalUserID: "google:user-1")
    #expect(!resolved.externalUserID.isEmpty)
}

@Test func fileOutboxDefaultURLCompiles() async throws {
    let url = FileConveltOutboxStore.defaultURL(appCode: "lingospeak")
    #expect(url.lastPathComponent == "convelt-outbox.json")
}

