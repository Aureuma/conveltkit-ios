import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ConveltKit

final class ConveltBootstrapURLProtocolMock: URLProtocol {
    private static let lock = NSLock()
    private static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func installHandler(
        _ value: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        handler = value
        lock.unlock()
    }

    static func clearHandler() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "example.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let activeHandler = Self.handler
        Self.lock.unlock()

        guard let activeHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try activeHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Test func bootstrapSendsGeneratedSdkVersionAndContractSupport() async throws {
    defer { ConveltBootstrapURLProtocolMock.clearHandler() }

    let appEnvironmentID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let installationID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    ConveltBootstrapURLProtocolMock.installHandler { request in
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/client/bootstrap")

        guard let body = requestBodyData(from: request) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["sdk_version"] as? String == ConveltKitVersion.value)
        #expect(json?["supported_contract_versions"] as? [String] == ["1.0.0"])

        let payload = """
        {
          "contract_version": "1.0.0",
          "config_version": "cfg-1",
          "app_environment_id": "\(appEnvironmentID.uuidString.lowercased())",
          "placement": "paywall",
          "product_ids": ["com.example.app.pro.monthly"],
          "entitlement_keys": ["pro"],
          "snapshot": null
        }
        """
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Length": "\(payload.utf8.count)",
                "Content-Type": "application/json",
            ]
        )!
        return (response, Data(payload.utf8))
    }

    let config = ConveltConfiguration(
        baseURL: URL(string: "https://example.com")!,
        publicSDKKey: "sdk-public-key",
        appEnvironmentID: appEnvironmentID,
        appCode: "example-app",
        bundleID: "com.example.app",
        appVersion: "1.0.0",
        buildNumber: "1"
    )
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [ConveltBootstrapURLProtocolMock.self]
    let client = ConveltClient(
        configuration: config,
        urlSession: URLSession(configuration: sessionConfiguration)
    )
    let response = try await client.bootstrap(installationID: installationID)

    #expect(response.contractVersion == "1.0.0")
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 {
            return nil
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }

    return data
}
