
enum ProfileValidator {
    static func validate(_ update: ProfileUpdate) throws(IdentityError) -> ProfileUpdate {
        let name = update.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = update.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let phone = update.phone.filter { $0.isNumber || $0 == "-" }

        guard !name.isEmpty else { throw .emptyName }
        guard isValidEmail(email) else { throw .invalidEmail }
        guard phone.filter(\.isNumber).count >= 7 else { throw .invalidPhone }
        return ProfileUpdate(fullName: name, email: email, phone: phone)
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }
}

extension IdentityError {
    var message: String {
        switch self {
        case .emptyName: "Enter your full name."
        case .invalidEmail: "Enter a valid email address."
        case .invalidPhone: "Enter a phone number with at least 7 digits."
        }
    }
}
