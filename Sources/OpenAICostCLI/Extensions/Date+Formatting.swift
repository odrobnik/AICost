//
//  Date+Formatting.swift
//  OpenAICost
//
//  Created by Oliver Drobnik on 04.06.25.
//

import Foundation

// MARK: - Date Extensions

public extension Date {

    /// Format date for display
    func formattedForDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
