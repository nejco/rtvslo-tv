import Foundation

/// A lenient JSON value. The RTV API is unofficial and mixes numbers and strings
/// for the same field, so we read it dynamically instead of with strict Codable.
enum JSON {
    case object([String: JSON])
    case array([JSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(any: Any) {
        if CFGetTypeID(any as CFTypeRef) == CFBooleanGetTypeID(), let b = any as? Bool {
            self = .bool(b)
            return
        }
        switch any {
        case let d as [String: Any]: self = .object(d.mapValues(JSON.init(any:)))
        case let a as [Any]: self = .array(a.map(JSON.init(any:)))
        case let s as String: self = .string(s)
        case let n as NSNumber: self = .number(n.doubleValue)
        default: self = .null
        }
    }

    static func parse(_ data: Data) throws -> JSON {
        // Strip a JSONP wrapper if the server adds one.
        var bytes = data
        if let text = String(data: data, encoding: .utf8),
           let open = text.firstIndex(of: "("), text.hasSuffix(")") || text.hasSuffix(");"),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            let inner = text[text.index(after: open)...]
            let trimmed = inner.trimmingCharacters(in: CharacterSet(charactersIn: ");\n\r "))
            bytes = Data(trimmed.utf8)
        }
        let obj = try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
        return JSON(any: obj)
    }

    subscript(key: String) -> JSON {
        if case .object(let d) = self { return d[key] ?? .null }
        return .null
    }

    subscript(index: Int) -> JSON {
        if case .array(let a) = self, a.indices.contains(index) { return a[index] }
        return .null
    }

    var isNull: Bool { if case .null = self { return true } else { return false } }

    var array: [JSON] {
        if case .array(let a) = self { return a }
        return []
    }

    var dictionary: [String: JSON] {
        if case .object(let d) = self { return d }
        return [:]
    }

    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var int: Int? { double.map { Int($0) } }

    var bool: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        case .string(let s): return ["1", "true", "yes"].contains(s.lowercased())
        default: return nil
        }
    }

    /// Returns the first non-empty string found at any of the given key paths.
    func firstString(_ paths: [[String]]) -> String? {
        for path in paths {
            var node = self
            for key in path { node = node[key] }
            if let s = node.string, !s.isEmpty { return s }
        }
        return nil
    }
}
