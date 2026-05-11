//
//  ArgoSupport.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import CryptoKit
import Foundation

public let argoClientId = "72fd6dea-d0ab-4bb9-8eaa-3ac24c84886c"
public let argoDefaultVersion = "1.29.2"
public let argoBaseURL = "https://www.portaleargo.it"
public let argoAuthURL = "https://auth.portaleargo.it"
public let argoRedirectURI = "it.argosoft.didup.famiglia.new://login-callback"
public let argoSSOLoginURL = "https://www.portaleargo.it/auth/sso/login"

public enum ArgoError: LocalizedError {
    case notLoggedIn
    case missingCredentials
    case apiError(String)
    case tokenError(String)
    case invalidLoginURL
    case invalidLoginChallenge
    case invalidLoginCode
    case invalidResponse(String)
    
    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Il client non ha effettuato il login."
        case .missingCredentials:
            return "Credenziali mancanti (codice scuola, username o password)."
        case .apiError(let message):
            return message
        case .tokenError(let message):
            return "Errore token: \(message)"
        case .invalidLoginURL:
            return "URL di login non valido."
        case .invalidLoginChallenge:
            return "Login challenge non trovato."
        case .invalidLoginCode:
            return "Codice di autorizzazione non trovato."
        case .invalidResponse(let message):
            return "Risposta non valida: \(message)"
        }
    }
}

public struct Credentials: Equatable {
    public let schoolCode: String
    public let username: String
    public let password: String
    
    public init(schoolCode: String, username: String, password: String) {
        self.schoolCode = schoolCode
        self.username = username
        self.password = password
    }
}

let argoJSONDecoder = JSONDecoder()
let argoJSONEncoder = JSONEncoder()

private enum ArgoDateFormatters {
    static let httpDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

private extension CharacterSet {
    static let argoQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+")
        return set
    }()
}

private let argoBrowserUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.4 Mobile/15E148 Safari/604.1"
private let argoAppUA = "didUPFamiglia/420 CFNetwork/3860.500.112 Darwin/25.4.0"

func argoFormatDate(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
    let milliseconds = (components.nanosecond ?? 0) / 1_000_000
    return String(
        format: "%04d-%02d-%02d %02d:%02d:%02d.%03d",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0,
        components.hour ?? 0,
        components.minute ?? 0,
        components.second ?? 0,
        milliseconds
    )
}

func argoRandomString(_ length: Int) -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    return String((0..<length).compactMap { _ in characters.randomElement() })
}

func pkceChallengeFromVerifier(_ verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func parseHTTPDate(_ string: String?) -> Date? {
    guard let string else { return nil }
    return ArgoDateFormatters.httpDate.date(from: string)
}

func formEncode(_ params: [(String, String)]) -> Data {
    params
        .map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .argoQueryValueAllowed) ?? value
            return "\(key)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
}

func queryValue(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == name })?
        .value
}

func resolveRedirectURL(_ location: String, baseURL: URL?) -> URL? {
    if let absolute = URL(string: location), absolute.scheme != nil {
        return absolute
    }
    guard let baseURL else { return nil }
    return URL(string: location, relativeTo: baseURL)?.absoluteURL
}

func applyBrowserHeaders(_ request: inout URLRequest, secFetchSite: String = "same-site") {
    request.setValue(argoBrowserUA, forHTTPHeaderField: "User-Agent")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.setValue(secFetchSite, forHTTPHeaderField: "Sec-Fetch-Site")
    request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
    request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
    request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
    request.setValue("u=0, i", forHTTPHeaderField: "Priority")
}

func applyAppHeaders(_ request: inout URLRequest) {
    request.setValue(argoAppUA, forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    request.setValue("u=3", forHTTPHeaderField: "Priority")
}

struct TokenPartial: Decodable {
    let access_token: String
    let expires_in: Int
    let id_token: String?
    let refresh_token: String?
    let scope: String?
    let token_type: String?
}

struct TokenError: Decodable {
    let error: String
    let error_description: String
}

func handleOperation<T: PKIdentifiable>(_ incoming: [APIOperation<T>], old: [T]?) -> [T] {
    var result: [T] = old ?? []
    var toDelete: [String] = []
    
    for item in incoming {
        switch item {
        case .delete(let pk):
            toDelete.append(pk)
        case .insert(let value):
            if let index = result.firstIndex(where: { $0.pk == value.pk }) {
                result[index] = value
            } else {
                result.append(value)
            }
        }
    }
    
    return result.filter { !toDelete.contains($0.pk) }
}

func handleOperationCustomPK<T>(_ incoming: [APIOperationCustomPK<T>], old: [T]?, pk: (T) -> String) -> [T] {
    var result: [T] = old ?? []
    var toDelete: [String] = []
    
    for item in incoming {
        switch item {
        case .delete(let pkValue):
            toDelete.append(pkValue)
        case .insert(let value):
            let key = pk(value)
            if let index = result.firstIndex(where: { pk($0) == key }) {
                result[index] = value
            } else {
                result.append(value)
            }
        }
    }
    
    return result.filter { !toDelete.contains(pk($0)) }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) { completionHandler(nil) }
}
