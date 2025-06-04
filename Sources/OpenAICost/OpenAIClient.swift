import Foundation

public enum OpenAIClientError: Error, LocalizedError {
    case invalidURL
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .missingAPIKey:
            return "Missing API key. Set OPENAI_ADMIN_KEY environment variable"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

public class OpenAIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = "https://api.openai.com/v1"
    
    public init() {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        
        // Configure decoder for snake_case to camelCase conversion
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Configure decoder for Unix timestamp to Date conversion
        self.decoder.dateDecodingStrategy = .secondsSince1970
    }
    
    private var apiKey: String {
        get throws {
            guard let key = ProcessInfo.processInfo.environment["OPENAI_ADMIN_KEY"] else {
                throw OpenAIClientError.missingAPIKey
            }
            return key
        }
    }
    
    public func fetchCosts(parameters: CostQueryParameters) async throws -> CostResponse {
        let url = try buildURL(for: "organization/costs", parameters: parameters)
        let request = try buildRequest(for: url)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIClientError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw OpenAIClientError.httpError(statusCode: httpResponse.statusCode, data: data)
            }
            
            let costResponse = try decoder.decode(CostResponse.self, from: data)
            return costResponse
            
        } catch let error as OpenAIClientError {
            throw error
        } catch {
            if error is DecodingError {
                throw OpenAIClientError.decodingError(error)
            } else {
                throw OpenAIClientError.networkError(error)
            }
        }
    }
    
    public func fetchAllCosts(parameters: CostQueryParameters) async throws -> [CostResponse.CostBucket] {
        var allBuckets: [CostResponse.CostBucket] = []
        var currentParameters = parameters
        
        repeat {
            let response = try await fetchCosts(parameters: currentParameters)
            allBuckets.append(contentsOf: response.data)
            
            if response.hasMore, let nextPage = response.nextPage {
                currentParameters = CostQueryParameters(
                    startTime: parameters.startTime,
                    bucketWidth: parameters.bucketWidth,
                    endTime: parameters.endTime,
                    groupBy: parameters.groupBy,
                    limit: parameters.limit,
                    page: nextPage,
                    projectIds: parameters.projectIds
                )
            } else {
                break
            }
        } while true
        
        return allBuckets
    }
    
    private func buildURL(for endpoint: String, parameters: CostQueryParameters) throws -> URL {
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)") else {
            throw OpenAIClientError.invalidURL
        }
        
        urlComponents.queryItems = parameters.queryItems()
        
        guard let url = urlComponents.url else {
            throw OpenAIClientError.invalidURL
        }
        
        return url
    }
    
    private func buildRequest(for url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(try apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
} 