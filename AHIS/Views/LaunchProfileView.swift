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
    enum Constants {
        static let formatter: NumberFormatter = {
            var formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }()
    }
    @ObservedObject var model: AHServiceViewModel
    @State var profile: [Double] = []
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(gradient: Color.skyGradient, startPoint: .top, endPoint: .bottom))

            ProfileShape(profile: model.altitudeHistory)
                .fill(LinearGradient(gradient: Color.earthGradient, startPoint: .top, endPoint: .bottom))
                .clipped()
        }
        .overlay(alignment: .top) {
            Text("QFE \(Constants.formatter.string(from: .init(floatLiteral: model.qfe.value)) ?? "") mt")
                .font(.system(size: 50, weight: .bold))
                .padding(.top)
        }
        .overlay(alignment: .trailing) {
            HStack {
//                Text("\(Int(model.distanceFromInitialLocation.value)) / ")
                Text("\(Int(max(0, model.winchLength.value - model.distanceFromInitialLocation.value))) mt")
            }
            .font(.system(size: 30, weight: .bold))
            .padding(.trailing)
        }
    }
}

struct LaunchProfileView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchProfileView(model: AHServiceViewModel())
            .frame(width: 300, height: 300)
    }
}
