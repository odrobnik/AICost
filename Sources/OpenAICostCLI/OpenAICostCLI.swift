import ArgumentParser
import Foundation
import OpenAICost

@main
struct OpenAICostCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "openai-cost",
        abstract: "Query OpenAI usage costs",
        version: "1.0.0"
    )

    internal static var standardError = FileHandle.standardError

    @Option(name: .shortAndLong, help: "Start time as Unix timestamp or days ago (e.g., 7 for 7 days ago)")
    var startTime: String

    @Option(name: .shortAndLong, help: "End time as Unix timestamp (optional)")
    var endTime: String?

    @Option(name: .long, help: "Group by fields (comma-separated: project_id, line_item)")
    var groupBy: String?

    @Option(name: .long, help: "Project IDs to filter by (comma-separated)")
    var projectIds: String?

    @Flag(name: .long, help: "Show detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    internal var isGrouping: Bool {
        return groupBy != nil && !groupBy!.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func run() async throws {
        let client = OpenAIClient()

        let startTimeDate: Date
        if let daysAgo = Int(startTime) {
            if daysAgo < 1000 {
                startTimeDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            } else {
                startTimeDate = Date(timeIntervalSince1970: TimeInterval(daysAgo))
            }
        } else {
            throw ValidationError("Invalid start time format. Use Unix timestamp or number of days ago.")
        }

        let endTimeDate: Date?
        if let endTimeStr = endTime, let endTimeInt = Int(endTimeStr) {
            endTimeDate = Date(timeIntervalSince1970: TimeInterval(endTimeInt))
        } else {
            endTimeDate = nil
        }

        let hardcodedBucketWidth = "1d"

        let groupByArray: [String]?
        if let groupByStr = groupBy {
            groupByArray = groupByStr.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            groupByArray = nil
        }

        let projectIdsArray: [String]?
        if let projectIdsStr = projectIds {
            projectIdsArray = projectIdsStr.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        } else {
            projectIdsArray = nil
        }

        let internalApiLimit = 100 

        let parameters = CostQueryParameters(
            startTime: startTimeDate,
            bucketWidth: hardcodedBucketWidth, 
            endTime: endTimeDate,
            groupBy: groupByArray,
            limit: internalApiLimit, 
            page: nil,
            projectIds: projectIdsArray
        )

        do {
            let buckets = try await client.fetchAllCosts(parameters: parameters)
            displayResults(buckets: buckets, hasMore: false, nextPage: nil)
        } catch {
            print("\(error.localizedDescription)", to: &Self.standardError)
            throw ExitCode.failure
        }
    }

    internal func displayResults(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
        if json {
            displayJSON(buckets: buckets, hasMore: false, nextPage: nil)
        } else {
            displayFormatted(buckets: buckets, hasMore: false, nextPage: nil)
        }
    }

    internal func displayJSON(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
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

    internal func displayFormatted(buckets: [CostResponse.CostBucket], hasMore: Bool, nextPage: String?) {
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

        let activeGroupByFields = (self.groupBy ?? "").split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)).lowercased() }

        for (index, bucket) in buckets.enumerated() {
            print("Bucket \(index + 1):")
            print("  Period: \(bucket.startTime.formattedForDisplay()) - \(bucket.endTime.formattedForDisplay())")
            print("  Cost: $\(String(format: "%.4f", bucket.results.totalCost)) \(currency)")

            if isGrouping {
                print("  Group Breakdown:")
                if bucket.results.isEmpty && activeGroupByFields.isEmpty {
                    print("    (No specific group data for this bucket)")
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
                print("  Breakdown:")
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
                print("  Results:")
                for result in bucket.results {
                    var details: [String] = []
                    if let projectId = result.projectId {
                        details.append("Project: \(projectId)")
                    }
                    if let lineItem = result.lineItem {
                        details.append("Line Item: \(lineItem)")
                    }
                    let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
                    print("    - $\(String(format: "%.4f", result.amount.value))\(detailStr)")
                }
            }
            print()
        }
    }
}
