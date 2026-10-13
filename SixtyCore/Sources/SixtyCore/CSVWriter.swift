import Foundation

/// RFC 4180 CSV: CRLF line endings, fields quoted when they hold a comma,
/// quote, or line break, with inner quotes doubled.
public enum CSVWriter {
    public static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows)
            .map { $0.map(field).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    static func field(_ value: String) -> String {
        let needsQuotes = value.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
