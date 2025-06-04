import Foundation

public class OpenAIClient {
    private let apiKey: String
    internal let session: URLSession
    internal let decoder: JSONDecoder
    internal let baseURL = "https://api.openai.com/v1"

    public init(apiKey: String, session: URLSession = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
        self.decoder = JSONDecoder()

        // Configure decoder for snake_case to camelCase conversion
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Configure decoder for Unix timestamp to Date conversion
        self.decoder.dateDecodingStrategy = .secondsSince1970
    }

    public func fetchCosts(parameters: CostQueryParameters) async throws -> CostResponse {
        let url = try buildURL(for: "organization/costs", parameters: parameters)
        let request = try buildRequest(for: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIClientError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                // Use the new convenience initializer for OpenAIClientError
                throw OpenAIClientError(data: data, response: httpResponse, decoder: self.decoder)
            }

            // Successful response, proceed to decode CostResponse
            do {
                let costResponse = try self.decoder.decode(CostResponse.self, from: data)
                return costResponse
            } catch let decodingError {
                throw OpenAIClientError.decodingError("Failed to decode CostResponse: \(decodingError.localizedDescription). Raw data: \(String(data: data, encoding: .utf8) ?? "Non-UTF8 data") Details: \(String(describing: decodingError))")
            }

        } catch let error as OpenAIClientError {
            throw error // Re-throw if it's already an OpenAIClientError (from above or buildURL/buildRequest)
        } catch let error as URLError {
            throw OpenAIClientError.networkError("Network error: \(error.localizedDescription)")
        } catch {
            // Catch any other unexpected errors
            throw OpenAIClientError.otherError("UnknownFetchError", "An unexpected error occurred during fetch: \(error.localizedDescription)")
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

    internal func buildURL(for endpoint: String, parameters: CostQueryParameters) throws -> URL {
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)") else {
            throw OpenAIClientError.invalidRequest("Invalid base URL for URLComponents: \(baseURL)/\(endpoint)")
        }

        urlComponents.queryItems = parameters.queryItems()

        guard let url = urlComponents.url else {
            throw OpenAIClientError.invalidRequest("Failed to construct URL from components.")
        }

        return url
    }

    internal func buildRequest(for url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
