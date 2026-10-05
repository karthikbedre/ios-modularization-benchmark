import ParkingAPI

enum PlateValidator {
    /// Uppercases, collapses spaces, and accepts 2 to 8 letters and digits with at most one space.
    static func normalize(_ plate: String) throws(ParkingError) -> String {
        let collapsed = plate.uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let characters = collapsed.filter { $0 != " " }
        guard (2...8).contains(characters.count),
              characters.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              collapsed.count(where: { $0 == " " }) <= 1 else {
            throw .invalidPlate
        }
        return collapsed
    }
}
