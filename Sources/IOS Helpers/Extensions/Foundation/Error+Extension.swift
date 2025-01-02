
import Foundation

public extension NSError {
    class func createError(domain: String? = nil, code: Int = 404, message: String?) -> NSError {
        return NSError(
            domain: domain ?? "com.api.error",
            code: code,
            userInfo: [NSLocalizedDescriptionKey : message ?? "####"]
        )
    }
}
