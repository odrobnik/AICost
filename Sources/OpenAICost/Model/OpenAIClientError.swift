import Foundation

// MARK: - OpenAIClientError Enum

public enum OpenAIClientError: Error, LocalizedError {
    case invalidResponse
    case serverError(String)
    case invalidRequest(String)
    case quotaError(String)
    case apiError(String)
    case otherError(String, String) // Typically (type/statusCode, message)
    case decodingError(String) // For issues decoding the primary Codable models
    case networkError(String)  // For underlying URLSession errors

    // New Initializer taking a decoded ErrorResponse
    public init(errorResponse: ErrorResponse) {
        switch errorResponse.error.type {
            case "server_error":
                self = .serverError(errorResponse.error.message)
            case "invalid_request_error":
                self = .invalidRequest(errorResponse.error.message)
            case "insufficient_quota":
                self = .quotaError(errorResponse.error.message)
            case "api_error":
                self = .apiError(errorResponse.error.message)
            default:
                self = .otherError(errorResponse.error.type, errorResponse.error.message)
        }
    }

    // Modified Initializer from HTTP response data - now calls the one above
    public init(data: Data, response: HTTPURLResponse, decoder: JSONDecoder) {
        do {
            let decodedErrorResponse = try decoder.decode(ErrorResponse.self, from: data)
            self.init(errorResponse: decodedErrorResponse) // Call the new init
        } catch {
            // Fallback if ErrorResponse decoding fails
            let rawString = String(data: data, encoding: .utf8) ?? "Invalid data"
            self = .otherError("\(response.statusCode)", rawString)
        }
    }

    public var errorDescription: String? {
        switch self {
            case .invalidResponse:
                return "Invalid Response"
            case .serverError(let message):
                return "Server Error: \(message)" // Showing message directly here too
            case .invalidRequest(let message):
                return "Invalid Request: \(message)"
            case .quotaError(let message):
                return "Quota Error: \(message)"
            case .apiError(let message):
                return "API Error: \(message)"
            case .otherError(let type, let message):
                return "API Error (Type/Status: \(type)): \(message)"
            case .decodingError(let message):
                return "Decoding Error: \(message)"
            case .networkError(let message):
                return "Network Error: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
            case .invalidResponse:
                return "An invalid response was received from the server."
            case .serverError(let message),
                    .invalidRequest(let message),
                    .quotaError(let message),
                    .apiError(let message),
                    .decodingError(let message),
                    .networkError(let message):
                return message
            case .otherError(_, let message):
                return message
        }
    }

    // 'type' might be less directly applicable if we use 'otherError' for status codes
    // but keeping a similar structure.
    public var type: String {
        switch self {
            case .invalidResponse: return "invalid_response"
            case .serverError: return "server_error"
            case .invalidRequest: return "invalid_request_error"
            case .quotaError: return "insufficient_quota"
            case .apiError: return "api_error"
            case .otherError(let errorType, _): return errorType // This could be an API type or an HTTP status code
            case .decodingError: return "decoding_error"
            case .networkError: return "network_error"
        }
    }
}
