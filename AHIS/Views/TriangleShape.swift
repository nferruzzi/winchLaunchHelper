//
//  TriangleShape.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 01/08/23.
//

import SwiftUI


struct TriangleShape: Shape {
    let offset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.size.width/2.0, y: 0))
            path.addLine(to: CGPoint(x: rect.size.width, y: rect.size.height - offset))
            path.addLine(to: CGPoint(x: 0, y: rect.size.height - offset))
        }
    }
}
