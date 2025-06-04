import Foundation

// MARK: - Cost Response Models

public struct CostResponse: Codable {
    public let object: String
    public let data: [CostBucket]
    public let hasMore: Bool
    public let nextPage: String?
    
    public init(object: String, data: [CostBucket], hasMore: Bool, nextPage: String?) {
        self.object = object
        self.data = data
        self.hasMore = hasMore
        self.nextPage = nextPage
    }
    
    public struct CostBucket: Codable {
        public let object: String
        public let startTime: Date
        public let endTime: Date
        public let results: [CostResult]
        
        // Structs
        
        public struct CostResult: Codable {
            public let object: String
            public let amount: Amount
            public let lineItem: String?
            public let projectId: String?
            
            public struct Amount: Codable {
                public let value: Double
                public let currency: String
            }
        }
        
    }
}
