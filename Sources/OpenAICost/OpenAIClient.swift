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
    
    public func fetchCosts(parameters: CostQueryParameters, debug: Bool = false) async throws -> CostResponse {
        let url = try buildURL(for: "organization/costs", parameters: parameters)
        let request = try buildRequest(for: url)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if debug {
                print("[DEBUG] Raw JSON received for parameters: \(parameters.queryItems())")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("[DEBUG] Could not convert data to UTF-8 string.")
                }
            }
            
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
                if debug { print("[DEBUG] Decoding error details: \(error)") }
                throw OpenAIClientError.decodingError(error)
            } else {
                if debug { print("[DEBUG] Network error details: \(error)") }
                throw OpenAIClientError.networkError(error)
            }
        }
    }
    
    public func fetchAllCosts(parameters: CostQueryParameters, debug: Bool = false) async throws -> [CostResponse.CostBucket] {
        var allBuckets: [CostResponse.CostBucket] = []
        var currentParameters = parameters
        var pageCount = 1
        
        repeat {
            if debug {
                var debugMsg = "[DEBUG] Fetching page \(pageCount)"
                if let page = currentParameters.page {
                    debugMsg += " (page cursor: \(page))"
                }
                debugMsg += ", start_time: \(Int(currentParameters.startTime.timeIntervalSince1970))"
                if let endTime = currentParameters.endTime {
                    debugMsg += ", end_time: \(Int(endTime.timeIntervalSince1970))"
                }
                if let limit = currentParameters.limit {
                    debugMsg += ", limit: \(limit)"
                }
                print(debugMsg)
            }
            let response = try await fetchCosts(parameters: currentParameters, debug: debug)
            allBuckets.append(contentsOf: response.data)
            
            if response.hasMore, let nextPage = response.nextPage {
                // Create new parameters with the next page
                currentParameters = CostQueryParameters(
                    startTime: parameters.startTime,
                    bucketWidth: parameters.bucketWidth,
                    endTime: parameters.endTime,
                    groupBy: parameters.groupBy,
                    limit: parameters.limit,
                    page: nextPage,
                    projectIds: parameters.projectIds
                )
                pageCount += 1
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