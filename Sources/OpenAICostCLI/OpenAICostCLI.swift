import ArgumentParser
import Foundation
import OpenAICost

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        self.write(Data(string.utf8))
    }
}

@main
struct OpenAICostCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "openai-cost",
        abstract: "Query OpenAI usage costs",
        version: "1.0.0"
    )
    
    private static var standardError = FileHandle.standardError
    
    @Option(name: .shortAndLong, help: "Start time as Unix timestamp or days ago (e.g., 7 for 7 days ago)")
    var startTime: String
    
    @Option(name: .shortAndLong, help: "End time as Unix timestamp (optional)")
    var endTime: String?
    
    @Option(name: .shortAndLong, help: "Bucket width (default: 1d)")
    var bucketWidth: String = "1d"
    
    @Option(name: .shortAndLong, help: "Maximum number of buckets per page (1-180, default: 7)")
    var limit: Int = 7
    
    @Option(name: .long, help: "Group by fields (comma-separated: project_id, line_item)")
    var groupBy: String?
    
    @Option(name: .long, help: "Project IDs to filter by (comma-separated)")
    var projectIds: String?
    
    @Flag(name: .long, help: "Fetch all pages automatically")
    var fetchAll: Bool = false
    
    @Flag(name: .long, help: "Show detailed output")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false
    
    @Flag(name: .long, help: "Show debug output for each page fetch")
    var debug: Bool = false
    
    // Track if groupBy is set
    private var isGrouping: Bool {
        return groupBy != nil && !groupBy!.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func run() async throws {
        let client = OpenAIClient()
        
        // Parse start time
        let startTimeDate: Date
        if let daysAgo = Int(startTime) {
            // If it's a reasonable number (< 1000), treat as days ago
            if daysAgo < 1000 {
                startTimeDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            } else {
                startTimeDate = Date(timeIntervalSince1970: TimeInterval(daysAgo))
            }
        } else {
            throw ValidationError("Invalid start time format. Use Unix timestamp or number of days ago.")
        }
        
        // Parse end time
        let endTimeDate: Date?
        if let endTimeStr = endTime, let endTimeInt = Int(endTimeStr) {
            endTimeDate = Date(timeIntervalSince1970: TimeInterval(endTimeInt))
        } else {
            endTimeDate = nil
        }
        
        // Validate bucket width
        // Based on API error feedback, only '1d' is currently accepted by /v1/organization/costs
        if bucketWidth != "1d" {
            throw ValidationError("Invalid bucket width: '\(bucketWidth)'. The API currently only supports '1d' for this endpoint.")
        }
        
        // Parse group by
        let groupByArray: [String]?
        if let groupByStr = groupBy {
            groupByArray = groupByStr.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            groupByArray = nil
        }
        
        // Parse project IDs
        let projectIdsArray: [String]?
        if let projectIdsStr = projectIds {
            projectIdsArray = projectIdsStr.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            projectIdsArray = nil
        }
        
        // Validate limit
        guard 1...180 ~= limit else {
            throw ValidationError("Limit must be between 1 and 180")
        }
        
        let parameters = CostQueryParameters(
            startTime: startTimeDate,
            bucketWidth: bucketWidth,
            endTime: endTimeDate,
            groupBy: groupByArray,
            limit: limit,
            page: nil,
            projectIds: projectIdsArray
        )
        
        do {
            if fetchAll {
                let buckets = try await client.fetchAllCosts(parameters: parameters, debug: debug)
                displayResults(buckets: buckets, hasMore: false, nextPage: nil)
            } else {
                let response = try await client.fetchCosts(parameters: parameters, debug: debug)
                displayResults(buckets: response.data, hasMore: response.hasMore, nextPage: response.nextPage)
            }
        } catch {
            print("Error: \(error.localizedDescription)", to: &Self.standardError)
            throw ExitCode.failure
        }
    }
    
    private func displayResults(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
        if json {
            displayJSON(buckets: buckets, hasMore: hasMore, nextPage: nextPage)
        } else {
            displayFormatted(buckets: buckets, hasMore: hasMore, nextPage: nextPage)
        }
    }
    
    private func displayJSON(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
        let response = CostResponse(
            object: "page",
            data: buckets,
            hasMore: hasMore,
            nextPage: nextPage
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(response)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("Error encoding JSON: \(error)", to: &Self.standardError)
        }
    }
    
    private func displayFormatted(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
        print("OpenAI Cost Report")
        print("==================")
        print()
        
        if buckets.isEmpty {
            print("No cost data found for the specified time range.")
            return
        }
        
        let totalCost = buckets.totalCost
        let currency = buckets.first?.results.first?.amount.currency.uppercased() ?? "USD"
        
        print("Total Cost: $\(String(format: "%.4f", totalCost)) \(currency)")
        print("Time Buckets: \(buckets.count)")
        print()
        
        // Parse the groupBy argument to know which fields to display
        let activeGroupByFields = (self.groupBy ?? "").split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)).lowercased() }
        
        for (index, bucket) in buckets.enumerated() {
            print("Bucket \(index + 1):")
            print("  Period: \(bucket.startTime.formattedForDisplay()) - \(bucket.endTime.formattedForDisplay())")
            print("  Cost: $\(String(format: "%.4f", bucket.results.totalCost)) \(currency)")

            if isGrouping {
                print("  Group Breakdown:")
                if bucket.results.isEmpty && activeGroupByFields.isEmpty {
                     print("    (No specific group data for this bucket)") // Should not happen if grouping yields results
                } else if bucket.results.isEmpty {
                    print("    (No results in this bucket for the specified group(s))")
                } else {
                    for result in bucket.results {
                        var details: [String] = []
                        if activeGroupByFields.contains("project_id") {
                            details.append("project_id: \(result.projectId ?? "null")")
                        }
                        if activeGroupByFields.contains("line_item") {
                            details.append("line_item: \(result.lineItem ?? "null")")
                        }
                        // If no specific group_by fields were recognized or matched, but we are grouping, show any available details
                        if details.isEmpty {
                            if let projectId = result.projectId {
                                details.append("project_id: \(projectId)")
                            }
                            if let lineItem = result.lineItem {
                                details.append("line_item: \(lineItem)")
                            }
                        }
                        let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
                        print("    - $\(String(format: "%.4f", result.amount.value))\(detailStr)")
                    }
                }
            } else if bucket.results.count > 1 || bucket.results.contains(where: { $0.lineItem != nil || $0.projectId != nil }) {
                 // This block is for non-explicit grouping but where results have inherent grouping info
                print("  Breakdown:") // Changed from "Group Breakdown" to avoid confusion
                for result in bucket.results {
                    var details: [String] = []
                    if let projectId = result.projectId {
                        details.append("project_id: \(projectId)")
                    }
                    if let lineItem = result.lineItem {
                        details.append("line_item: \(lineItem)")
                    }
                    let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
                    print("    - $\(String(format: "%.4f", result.amount.value))\(detailStr)")
                }
            } else if verbose && !bucket.results.isEmpty {
                // Fallback: show details if verbose and no other breakdown shown
                print("  Results:")
                for result in bucket.results {
                    var details: [String] = [] // Keep details minimal for non-grouped verbose
                    if let projectId = result.projectId {
                        details.append("Project: \(projectId)") // Using original "Project:" label for verbose
                    }
                    if let lineItem = result.lineItem {
                        details.append("Line Item: \(lineItem)") // Using original "Line Item:" label for verbose
                    }
                    let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
                    print("    - $\(String(format: "%.4f", result.amount.value))\(detailStr)")
                }
            }
            print()
        }
        
        if hasMore {
            print("Note: More data available. Use --fetch-all to retrieve all pages.")
            if let nextPage = nextPage {
                print("Next page: \(nextPage)")
            }
        }
    }
} 