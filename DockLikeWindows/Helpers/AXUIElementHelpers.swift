//
//  AXElementHelpers.swift
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-01.
//

import Foundation
import Cocoa

class AXUIElementHelpers {
    static func getElementAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var attributeValue: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &attributeValue)
        return attributeValue
    }

    static func getElementChildren(_ element: AXUIElement) -> [AXUIElement]? {
        if let children = getElementAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            return children
        }
        return nil
    }
    
    static func getElementPosition(_ element: AXUIElement) -> CGPoint? {
        let positionAXValue = getElementAttribute(element, kAXPositionAttribute) as! AXValue
        
        var position = CGPoint.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position) else {
            return nil
        }
        
        return position
    }
    
    static func getElementSize(_ element: AXUIElement) -> CGSize? {
        let sizeAXValue = getElementAttribute(element, kAXSizeAttribute) as! AXValue
        
        var size = CGSize.zero
        guard AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }
        
        return size
    }
}
