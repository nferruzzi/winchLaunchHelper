//
//  SkyShape.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 01/08/23.
//

import SwiftUI

struct SkyShape: Shape {
    let size: CGFloat
    var horizont: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: size, y: horizont))
            path.addLine(to: CGPoint(x: 0, y: horizont))
        }
    }
    
    var animatableData: CGFloat {
        get { horizont }
        set { horizont = newValue }
    }
}
