import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: AnyObject {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public final class URLSessionTransport: HTTPTransport {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (data ?? Data(), (response as? HTTPURLResponse)?.statusCode ?? 0))
            }.resume()
        }
    }
}

/// Remembers, per Google account, that the one free Google Calendar sync
/// was used, so reinstalling or another phone cannot reuse it.
public protocol FreeSyncRegistry: AnyObject {
    /// Throws when the registry cannot be reached.
    func isUsed(googleIdToken: String) async throws -> Bool
    /// Records the free sync of [month] (first write wins).
    func record(googleIdToken: String, month: CivilDate) async throws
}

/// The same free Cloud Firestore (Spark) registry as Android, over HTTPS. The
/// Google ID token from the existing sign-in is exchanged for a Firebase ID
/// token, so there is no extra consent screen; firebase/firestore.rules let an
/// account only read or create its own record.
public final class FirestoreFreeSyncRegistry: FreeSyncRegistry {
    let apiKey: String
    let projectId: String
    let transport: HTTPTransport
    static let timeout: TimeInterval = 20

    public init(apiKey: String, projectId: String, transport: HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.transport = transport
    }

    /// Nil unless the public Firebase settings were provided at build time.
    public static func fromConfiguration(apiKey: String?, projectId: String?, transport: HTTPTransport = URLSessionTransport())
        -> FirestoreFreeSyncRegistry? {
        guard let apiKey, let projectId, !apiKey.isEmpty, !projectId.isEmpty else { return nil }
        return FirestoreFreeSyncRegistry(apiKey: apiKey, projectId: projectId, transport: transport)
    }

    private func signIn(_ googleIdToken: String) async throws -> (uid: String, token: String) {
        var components = URLComponents(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "postBody": "id_token=\(googleIdToken)&providerId=google.com",
            "requestUri": "http://localhost",
            "returnSecureToken": true,
        ])
        let (data, status) = try await transport.send(request)
        guard status == 200, let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = body["localId"] as? String, let token = body["idToken"] as? String else {
            throw CoreError.invalidData("Free sync sign-in failed (\(status): \(Self.errorMessage(data)))")
        }
        return (uid, token)
    }

    /// Firebase's error reason, which contains no secrets.
    static func errorMessage(_ data: Data) -> String {
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = (body["error"] as? [String: Any])?["message"] as? String {
            return message
        }
        return String(String(decoding: data, as: UTF8.self).prefix(200))
    }

    private func documents(_ path: String = "", query: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "firestore.googleapis.com"
        components.path = "/v1/projects/\(projectId)/databases/(default)/documents/freeGoogleSyncs\(path)"
        components.queryItems = query
        return components.url!
    }

    public func isUsed(googleIdToken: String) async throws -> Bool {
        let auth = try await signIn(googleIdToken)
        var request = URLRequest(url: documents("/\(auth.uid)"), timeoutInterval: Self.timeout)
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        let (data, status) = try await transport.send(request)
        if status == 200 { return true }
        if status == 404 { return false }
        throw CoreError.invalidData("Free sync registry unavailable (\(status): \(Self.errorMessage(data)))")
    }

    public func record(googleIdToken: String, month: CivilDate) async throws {
        let auth = try await signIn(googleIdToken)
        var request = URLRequest(url: documents(query: [URLQueryItem(name: "documentId", value: auth.uid)]),
                                 timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": [
                "month": ["stringValue": String(month.iso.prefix(7))],
                "createdAt": ["timestampValue": ISO8601.string(Date())],
            ],
        ])
        let (_, status) = try await transport.send(request)
        // 409: already recorded (another phone or an earlier install).
        guard status == 200 || status == 409 else { throw CoreError.invalidData("Free sync not recorded (\(status))") }
    }
}
