//
//  CGPoint+math.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 21/08/23.
//

import Foundation


/// Normalize and reverse Y axis
func *(point: CGPoint, rect: CGRect) -> CGPoint {
    CGPoint(x: point.x * rect.width, y: rect.height - point.y * rect.height)
}
