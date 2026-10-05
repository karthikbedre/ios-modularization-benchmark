import CoreModels
import Foundation
import Identity

extension UserProfile {
    static let fixture = UserProfile(
        id: "user-test",
        fullName: "Sam Lee",
        email: "sam@example.com",
        phone: "555-0199",
        residentID: "CIV-100200",
        address: Address(street: "1 Main Street", district: "Center", postalCode: "10000"),
        memberSince: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
