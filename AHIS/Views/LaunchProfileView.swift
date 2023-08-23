//
//  LaunchProfileView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import SwiftUI


struct ProfileShape: Shape {
    var profile: [Double]
    let max: Double
        
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero * rect)

            let filtered = profile.suffix(Int(rect.width))
            
            for (index, value) in filtered.enumerated() {
                let x = CGFloat(index) / rect.width
                let y = value / max  /// rect.height
                
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


struct GridShape: Shape {
    let value: Double
    let max: Double
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height - (value / max) * rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - (value / max) * rect.height))
        }
    }
}


struct LaunchProfileView: View {
    enum Constants {
        static let maxHeight: Double = 600
    }
    
    @ObservedObject var model: AHServiceViewModel
    
    var qfe: String {
        "QFE \(naturalScale: model.qfe, digits: true)"
    }
    
    var label: String {
        "\(naturalScale: Measurement<UnitLength>(value: 50, unit: .meters))"
    }
    
    var info: some View {
        ZStack(alignment: .bottom) {
            GridShape(value: 50, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))

            GridShape(value: 100, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))

            GridShape(value: 200, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))

            GridShape(value: 300, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
        }
    }

    var labels: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Text(verbatim: "\(naturalScale: Measurement<UnitLength>(value: 50, unit: .meters))")
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * 50 - 15))
                    .font(.subheadline)

                Text(verbatim: "\(naturalScale: Measurement<UnitLength>(value: 100, unit: .meters))")
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * 100 - 15))
                    .font(.subheadline)

                Text(verbatim: "\(naturalScale: Measurement<UnitLength>(value: 200, unit: .meters))")
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * 200 - 15))
                    .font(.subheadline)

                Text(verbatim: "\(naturalScale: Measurement<UnitLength>(value: 300, unit: .meters))")
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * 300 - 15))
                    .font(.subheadline)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(gradient: Color.skyGradient, startPoint: .top, endPoint: .bottom))
                .overlay(info)

            ProfileShape(profile: model.altitudeHistory, max: Constants.maxHeight)
                .fill(LinearGradient(gradient: Color.earthGradient, startPoint: .top, endPoint: .bottom))
                .clipped()
                .overlay(labels)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                WinchLengthView(distanceFromInitialLocation: model.distanceFromInitialLocation,
                                winchLength: model.winchLength)
                Text(qfe)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(model.qfe.value > 50 ? nil : .trunkRed)
            }
            .padding(.top)
        }
    }
}

struct LaunchProfileView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchProfileView(model: AHServiceViewModel())
            .frame(width: 300, height: 300)
    }
}
