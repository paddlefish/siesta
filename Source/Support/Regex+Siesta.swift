//
//  Regex.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

internal extension String
    {
    func containsRegex(regex: String) -> Bool
        {
        return rangeOfString(regex, options: .RegularExpressionSearch) != nil
        }

    func replaceRegex(regex: String, _ replacement: String) -> String
        {
        return stringByReplacingOccurrencesOfString(
            regex, withString: replacement, options: .RegularExpressionSearch, range: nil)
        }
    
    func replaceString(string: String, _ replacement: String) -> String
        {
        // Maybe this method name looked more reasonable in Objective-C.
        return stringByReplacingOccurrencesOfString(string, withString: replacement)
        }
    
    func replaceRegex(regex: NSRegularExpression, _ template: String) -> String
        {
        return regex.stringByReplacingMatchesInString(self, options: [], range: fullRange, withTemplate: template)
        }
    
    var fullRange: NSRange
        {
        return NSRange(location: 0, length: (self as NSString).length)
        }
    }

internal extension NSRegularExpression
    {
    static func compile(pattern: String, options: NSRegularExpressionOptions = [])
        -> NSRegularExpression
        {
        do  {
            return try NSRegularExpression(pattern: pattern, options: options)
            }
        catch
            {
            fatalError("Regexp compilation failed: \(pattern)")
            }
        }
    
    func matches(string: String) -> Bool
        {
        let match = firstMatchInString(string, options: [], range: string.fullRange)
        return match != nil && match?.range.location != NSNotFound
        }
    }
