import Foundation

// MARK: - Error Response Model for OpenAIClientError

public struct ErrorResponse: Codable {
    public struct ErrorDetail: Codable {
        let message: String
        let type: String
    // param: String? // Not used by the provided errorFromResponse, but OpenAI sends it
    // code: String?  // Not used by the provided errorFromResponse, but OpenAI sends it
    }
    let error: ErrorDetail
}
