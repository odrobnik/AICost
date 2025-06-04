import XCTest
@testable import OpenAICost

final class OpenAICostTests: XCTestCase {
    
    func testCostQueryParametersQueryItems() {
        let startDate = Date(timeIntervalSince1970: 1730419200)
        let endDate = Date(timeIntervalSince1970: 1730505600)
        
        let parameters = CostQueryParameters(
            startTime: startDate,
            bucketWidth: "1d",
            endTime: endDate,
            groupBy: ["project_id", "line_item"],
            limit: 10,
            page: nil,
            projectIds: ["proj_123", "proj_456"]
        )
        
        let queryItems = parameters.queryItems()
        
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "start_time", value: "1730419200")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "bucket_width", value: "1d")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "end_time", value: "1730505600")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "limit", value: "10")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "group_by[]", value: "project_id")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "group_by[]", value: "line_item")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "project_ids[]", value: "proj_123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "project_ids[]", value: "proj_456")))
    }
    
    func testCostResultArrayTotalCost() {
        let results = [
            CostResponse.CostBucket.CostResult(
                object: "organization.costs.result",
                amount: CostResponse.CostBucket.CostResult.Amount(value: 0.05, currency: "usd"),
                lineItem: nil,
                projectId: nil
            ),
            CostResponse.CostBucket.CostResult(
                object: "organization.costs.result",
                amount: CostResponse.CostBucket.CostResult.Amount(value: 0.03, currency: "usd"),
                lineItem: nil,
                projectId: nil
            )
        ]
        
        XCTAssertEqual(results.totalCost, 0.08, accuracy: 0.001)
    }
    
    func testCostBucketArrayTotalCost() {
        let bucket1 = CostResponse.CostBucket(
            object: "bucket",
            startTime: Date(timeIntervalSince1970: 1730419200),
            endTime: Date(timeIntervalSince1970: 1730505600),
            results: [
                CostResponse.CostBucket.CostResult(
                    object: "organization.costs.result",
                    amount: CostResponse.CostBucket.CostResult.Amount(value: 0.05, currency: "usd"),
                    lineItem: nil,
                    projectId: nil
                )
            ]
        )
        
        let bucket2 = CostResponse.CostBucket(
            object: "bucket",
            startTime: Date(timeIntervalSince1970: 1730505600),
            endTime: Date(timeIntervalSince1970: 1730592000),
            results: [
                CostResponse.CostBucket.CostResult(
                    object: "organization.costs.result",
                    amount: CostResponse.CostBucket.CostResult.Amount(value: 0.03, currency: "usd"),
                    lineItem: nil,
                    projectId: nil
                )
            ]
        )
        
        let buckets = [bucket1, bucket2]
        XCTAssertEqual(buckets.totalCost, 0.08, accuracy: 0.001)
    }
    
    func testJSONDecodingWithSnakeCase() throws {
        let jsonString = """
        {
            "object": "page",
            "data": [
                {
                    "object": "bucket",
                    "start_time": 1730419200,
                    "end_time": 1730505600,
                    "results": [
                        {
                            "object": "organization.costs.result",
                            "amount": {
                                "value": 0.06,
                                "currency": "usd"
                            },
                            "line_item": null,
                            "project_id": null
                        }
                    ]
                }
            ],
            "has_more": false,
            "next_page": null
        }
        """
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let data = jsonString.data(using: .utf8)!
        let response = try decoder.decode(CostResponse.self, from: data)
        
        XCTAssertEqual(response.object, "page")
        XCTAssertEqual(response.data.count, 1)
        XCTAssertFalse(response.hasMore)
        XCTAssertNil(response.nextPage)
        
        let bucket = response.data[0]
        XCTAssertEqual(bucket.startTime.timeIntervalSince1970, 1730419200)
        XCTAssertEqual(bucket.endTime.timeIntervalSince1970, 1730505600)
        XCTAssertEqual(bucket.results.count, 1)
        
        let result = bucket.results[0]
        XCTAssertEqual(result.amount.value, 0.06, accuracy: 0.001)
        XCTAssertEqual(result.amount.currency, "usd")
        XCTAssertNil(result.lineItem)
        XCTAssertNil(result.projectId)
    }
} 
