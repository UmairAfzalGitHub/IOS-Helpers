
import Foundation

public extension Array {
    mutating func updateFirst(where predicate: (Element) -> Bool, _ update: (inout Element) -> Void) {
        if let index = self.firstIndex(where: predicate) {
            update(&self[index])
        }
    }
}
