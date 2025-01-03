//
//  File.swift
//  
//
//  Created by Umair Afzal on 03/01/2025.
//

import Foundation

public extension Encodable {
    
    /// Save JSON string into user defaults
    func saveInUserDefaults (key : String) {
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(self)
            
            if let jsonString  = String(data: jsonData, encoding: .utf8) {
                UserDefaults.standard.set(jsonString, forKey: key)
                print("Data saved")
            } else {
                print("Data saving in UserDefaults failed ")
            }
        } catch {
            print("Data saving in UserDefaults failed ")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /**
     Load from user default for a specific key.
     
     - parameter key: key for which you want to load value from user default.
     
     - returns: Loaded Value of generic type from user default.
     */
    static func loadFromUserDefaults <T: Codable> (key : String) -> T? {
        
        if let jsonString = UserDefaults.standard.object(forKey:key) as? String,
           let data = jsonString.data(using: .utf8) {
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
                
            } catch {
                print("Failed to decode JSON")
                return nil
                
            }
        }
        
        return nil
    }
}
