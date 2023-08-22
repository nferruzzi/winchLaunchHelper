//
//  WinchLengthShape.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 22/08/23.
//

import SwiftUI


struct WinchLengthShape: Shape {
    var completed: Double
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .init(x: min(completed, 1), y: 1) * rect)
            path.addLine(to: .init(x: min(completed, 1), y: 0.0) * rect)
            path.addLine(to: .init(x: 1, y: 0.0) * rect)
            path.addLine(to: .init(x: 1, y: 1) * rect)
        }
    }
    
    var animatableData: CGFloat {
        get { completed }
        set { completed = newValue }
    }
}

struct WinchLengthShape_Previews: PreviewProvider {
    static var previews: some View {
        WinchLengthShape(completed: 5)
    }
}
