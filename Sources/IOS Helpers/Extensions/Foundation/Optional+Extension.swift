
import Foundation

public extension Optional where Wrapped == String {
    
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
    
    var orDash: String {
        return self ?? "-"
    }
    
    var orDoubleDash: String {
        guard let self = self else {
            return "--"
        }
        return self.isEmpty ? "--" : self
    }
    
    var orEmpty: String {
        return self ?? ""
    }
}


public extension Optional where Wrapped == Bool {
    
    var orFalse: Bool {
        return self ?? false
    }
}

public extension Optional where Wrapped == Float {
    
    var orZero: Float {
        return self ?? 0
    }
}


public extension Optional where Wrapped == Int {
    
    var orZero: Int {
        return self ?? 0
    }
}
