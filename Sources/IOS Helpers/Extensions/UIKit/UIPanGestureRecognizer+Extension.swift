

import Foundation
import UIKit

public enum PanDirection: Int {
    case up,
         down,
         left,
         right
    
    public var isX: Bool {
        return self == .left || self == .right
    }
    
    public var isY: Bool {
        return !isX
    }
}

public extension UIPanGestureRecognizer {
    var direction: PanDirection? {
        let velocity = self.velocity(in: view)
        let vertical = abs(velocity.y) > abs(velocity.x)
        switch (vertical, velocity.x, velocity.y) {
        case (true, _, let y):
            return y < 0 ? .up : .down
            
        case (false, let x, _):
            return x > 0 ? .right : .left
        }
    }
}
