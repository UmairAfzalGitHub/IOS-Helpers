//
//  File.swift
//  IOS Helpers
//
//  Created by Umair Afzal on 02/08/2025.
//

import Foundation

extension Collection {
    
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    func notEmpty() -> Bool {
        return !isEmpty
    }
}
