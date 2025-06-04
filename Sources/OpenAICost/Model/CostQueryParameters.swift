import Foundation

// MARK: - Query Parameters

public struct CostQueryParameters {
    public let startTime: Date
    public let bucketWidth: String?
    public let endTime: Date?
    public let groupBy: [String]?
    public let limit: Int?
    public let page: String?
    public let projectIds: [String]?

    public init(
        startTime: Date,
        bucketWidth: String? = nil,
        endTime: Date? = nil,
        groupBy: [String]? = nil,
        limit: Int? = nil,
        page: String? = nil,
        projectIds: [String]? = nil
    ) {
        self.startTime = startTime
        self.bucketWidth = bucketWidth
        self.endTime = endTime
        self.groupBy = groupBy
        self.limit = limit
        self.page = page
        self.projectIds = projectIds
    }

    public func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        // Convert Date to Unix timestamp for API
        items.append(URLQueryItem(name: "start_time", value: String(Int(startTime.timeIntervalSince1970))))

        if let bucketWidth = bucketWidth {
            items.append(URLQueryItem(name: "bucket_width", value: bucketWidth))
        }

        if let endTime = endTime {
            items.append(URLQueryItem(name: "end_time", value: String(Int(endTime.timeIntervalSince1970))))
        }

        if let groupBy = groupBy {
            for group in groupBy {
                items.append(URLQueryItem(name: "group_by[]", value: group))
            }
        }

        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        if let page = page {
            items.append(URLQueryItem(name: "page", value: page))
        }

        if let projectIds = projectIds {
            for projectId in projectIds {
                items.append(URLQueryItem(name: "project_ids[]", value: projectId))
            }
        }

        return items
    }
}
