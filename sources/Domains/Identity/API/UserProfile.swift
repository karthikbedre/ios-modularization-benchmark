import CoreModels
import Foundation

public struct UserProfile: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var fullName: String
    public var email: String
    public var phone: String
    public var residentID: String
    public var address: Address
    public var memberSince: Date

    public init(id: String, fullName: String, email: String, phone: String, residentID: String, address: Address, memberSince: Date) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.residentID = residentID
        self.address = address
        self.memberSince = memberSince
    }

    public var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }

    public var initials: String {
        fullName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

public struct ProfileUpdate: Hashable, Sendable {
    public var fullName: String
    public var email: String
    public var phone: String

    public init(fullName: String, email: String, phone: String) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
    }

    public init(_ profile: UserProfile) {
        self.init(fullName: profile.fullName, email: profile.email, phone: profile.phone)
    }
}

public enum IdentityError: Error, Hashable, Sendable {
    case emptyName
    case invalidEmail
    case invalidPhone
}
