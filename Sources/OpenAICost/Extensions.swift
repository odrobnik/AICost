import Foundation

// MARK: - Date Extensions

public extension Date {
    /// Convert Date to Unix timestamp (seconds since 1970)
    var unixTimestamp: Int {
        return Int(self.timeIntervalSince1970)
    }
    
    /// Create Date from Unix timestamp
    init(unixTimestamp: Int) {
        self.init(timeIntervalSince1970: TimeInterval(unixTimestamp))
    }
    
    /// Format date for display
    func formattedForDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - String Extensions

public extension String {
    /// Parse Unix timestamp from string
    var unixTimestamp: Int? {
        return Int(self)
    }
}

// MARK: - Array Extensions

public extension Array where Element == CostResponse.CostBucket.CostResult {
    /// Calculate total cost for all results
    var totalCost: Double {
        return self.reduce(0) { $0 + $1.amount.value }
    }
}

public extension Array where Element == CostResponse.CostBucket {
    /// Calculate total cost for all buckets
    var totalCost: Double {
        return self.reduce(0) { $0 + $1.results.totalCost }
    }
} 