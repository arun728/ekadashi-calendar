import Foundation
import UIKit
import GoogleSignIn
import EkadashiCore

/// The sync coordinator calls its gateway from a background task, and a
/// `@MainActor` class satisfying the nonisolated `GoogleAuthGateway` does not
/// hop to the main thread when called through the protocol (Swift 5 mode), so
/// Google's sign-in UI crashed with "Call must be made on main thread". Each
/// requirement here calls the main-actor client directly, which does hop.
final class GoogleSignInGateway: GoogleAuthGateway {
    private let client = GoogleSignInClient()

    func accountId() async -> String? { await client.accountId() }
    func isSignedIn() async -> Bool { await client.isSignedIn() }
    func signIn() async throws -> Bool { try await client.signIn() }
    func signOut() async { await client.signOut() }
    func idToken() async throws -> String? { try await client.idToken() }
    func accountEmail() async -> String? { await client.accountEmail() }
    func listCalendars() async throws -> [GoogleCalendarInfo] { try await client.listCalendars() }
    func fetchEvents(from: Date, to: Date, calendarIds: [String]) async throws -> [GoogleEvent] {
        try await client.fetchEvents(from: from, to: to, calendarIds: calendarIds)
    }
}

/// Google sign-in (read-only Calendar scope) and the Calendar REST API.
/// Sign-in is only for Calendar import; Premium never depends on it.
@MainActor
private final class GoogleSignInClient {
    static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
    private let session = URLSession.shared

    private var user: GIDGoogleUser? { GIDSignIn.sharedInstance.currentUser }

    private func restore() async -> GIDGoogleUser? {
        if let user { return user }
        return try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    func accountId() async -> String? { await restore()?.userID }
    func isSignedIn() async -> Bool {
        guard let user = await restore() else { return false }
        return user.grantedScopes?.contains(Self.calendarScope) == true
    }

    func signIn() async throws -> Bool {
        guard let presenter = UIApplication.shared.topViewController else { return false }
        do {
            if let user = await restore() {
                if user.grantedScopes?.contains(Self.calendarScope) == true { return true }
                let result = try await user.addScopes([Self.calendarScope], presenting: presenter)
                return result.user.grantedScopes?.contains(Self.calendarScope) == true
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil,
                                                                  additionalScopes: [Self.calendarScope])
            return result.user.grantedScopes?.contains(Self.calendarScope) == true
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain && error.code == -5 {
            // kGIDSignInErrorCodeCanceled: the user closed Google's sheet.
            return false
        }
    }

    func signOut() async { GIDSignIn.sharedInstance.signOut() }

    /// A fresh ID token: they expire after an hour and Firebase rejects old ones.
    func idToken() async throws -> String? {
        guard let user = await restore() else { return nil }
        return try await user.refreshTokensIfNeeded().idToken?.tokenString
    }

    func accountEmail() async -> String? { await restore()?.profile?.email }

    private func accessToken() async throws -> String {
        guard let user = await restore() else { throw CoreError.invalidArgument("No Google account") }
        return try await user.refreshTokensIfNeeded().accessToken.tokenString
    }

    private func get(_ path: String, _ query: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/\(path)")!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!, timeoutInterval: 30)
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    func listCalendars() async throws -> [GoogleCalendarInfo] {
        struct Page: Decodable {
            struct Item: Decodable { let id: String?; let summary: String?; let primary: Bool?; let selected: Bool? }
            let items: [Item]?
            let nextPageToken: String?
        }
        var all: [GoogleCalendarInfo] = []
        var token: String?
        repeat {
            var query = [URLQueryItem(name: "maxResults", value: "100")]
            if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
            let page = try JSONDecoder().decode(Page.self, from: try await get("users/me/calendarList", query))
            for item in page.items ?? [] {
                guard let id = item.id else { continue }
                all.append(GoogleCalendarInfo(id: id, summary: item.summary ?? id, primary: item.primary == true,
                                              selected: item.selected != false))
            }
            token = page.nextPageToken
        } while token != nil
        return all
    }

    func fetchEvents(from: Date, to: Date, calendarIds: [String]) async throws -> [GoogleEvent] {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@")
        var all: [GoogleEvent] = []
        for calendarId in calendarIds {
            let encoded = calendarId.addingPercentEncoding(withAllowedCharacters: allowed) ?? calendarId
            var token: String?
            repeat {
                var query = [URLQueryItem(name: "timeMin", value: ISO8601.string(from)),
                             URLQueryItem(name: "timeMax", value: ISO8601.string(to)),
                             URLQueryItem(name: "singleEvents", value: "true"),
                             URLQueryItem(name: "orderBy", value: "startTime"),
                             URLQueryItem(name: "maxResults", value: "250")]
                if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
                let page = try JSONDecoder().decode(GoogleEventPage.self, from: try await get("calendars/\(encoded)/events", query))
                for var event in page.items {
                    event.calendarId = calendarId
                    all.append(event)
                }
                token = page.nextPageToken
            } while token != nil
        }
        return all
    }
}

extension UIApplication {
    /// The top-most presented view controller of the key window.
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
