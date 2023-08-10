//
//  LaunchProfileView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import SwiftUI

fileprivate func *(point: CGPoint, rect: CGRect) -> CGPoint {
    CGPoint(x: point.x * rect.width, y: rect.height - point.y * rect.height)
}

struct ProfileShape: Shape {
    var profile: [Double]
        
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero * rect)

            let filtered = profile.suffix(Int(rect.width))
            
            for (index, value) in filtered.enumerated() {
                let x = CGFloat(index) / rect.width
                let y = value / rect.height
                
                path.addLine(to: .init(x: x, y: y) * rect)

                if index == filtered.count - 1 {
                    path.addLine(to: .init(x: x, y: 0) * rect)
                    path.addLine(to: .zero * rect)
                }
            }
            path.addLine(to: .init(x: 0, y: 0) * rect)
        }
    }
    
    var animatableData: [Double] {
        get { profile }
        set { profile = newValue }
    }
}


struct LaunchProfileView: View {
    @ObservedObject var model: AHServiceViewModel
    @State var profile: [Double] = []
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.blue)
            
            ProfileShape(profile: model.altitude)
                .fill(.green)
                .clipped()
        }
    }
}

struct LaunchProfileView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchProfileView(model: AHServiceViewModel())
            .frame(width: 300, height: 300)
    }
}
