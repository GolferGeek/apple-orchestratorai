import Foundation

enum JSONValue: Decodable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var shortDescription: String {
        switch self {
        case .object(let dictionary):
            if let object = dictionary["object"]?.stringValue {
                return object
            }
            return "\(dictionary.count) fields"
        case .array(let array):
            return "\(array.count) items"
        case .string(let string):
            return string
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        }
    }

    var listCountDescription: String {
        switch self {
        case .array(let array):
            return "\(array.count)"
        case .object(let dictionary):
            if case .array(let data)? = dictionary["data"] {
                return "\(data.count)"
            }
            if case .array(let skills)? = dictionary["skills"] {
                return "\(skills.count)"
            }
            if case .array(let toolsets)? = dictionary["toolsets"] {
                return "\(toolsets.count)"
            }
            return "\(dictionary.count) fields"
        default:
            return shortDescription
        }
    }

    private var stringValue: String? {
        if case .string(let string) = self {
            return string
        }
        return nil
    }
}
