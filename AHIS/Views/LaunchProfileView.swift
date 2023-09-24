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

struct TextSpeed: View {
    @AppStorage(UIUnitSpeed.userSetting) var unitSpeed: UIUnitSpeed = .kmh
    let value: Measurement<UnitSpeed>
    
    var text: String {
        "\(uiSetting: value)"
    }
    
    var body: some View {
        Text(text)
            .id(unitSpeed)
    }
}

struct TextAltitude: View {
    @AppStorage(UIUnitAltitude.userSetting) var unitAltitude: UIUnitAltitude = .meters
    let value: Measurement<UnitLength>
    
    var text: String {
        "\(uiSetting: value, digits: false)"
    }
    
    var body: some View {
        Text(text)
            .id(unitAltitude)
    }
}

struct LaunchProfileView: View {
    enum Constants {
        static let maxHeight: Double = 500
        static let referenceHeights: [Measurement<UnitLength>] = [
            .init(value: 60, unit: .meters),
            .init(value: 120, unit: .meters),
            .init(value: 240, unit: .meters),
        ]
    }
    
    @ObservedObject var model: AHServiceViewModel
            
    var info: some View {
        ZStack(alignment: .bottom) {
            GridShape(value: Constants.referenceHeights[0].value, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))

            GridShape(value: Constants.referenceHeights[1].value, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))

            GridShape(value: Constants.referenceHeights[2].value, max: Constants.maxHeight)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
        }
    }

    var labels: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                TextAltitude(value: Constants.referenceHeights[0])
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * Constants.referenceHeights[0].value - 15))
                    .font(.subheadline)

                TextAltitude(value: Constants.referenceHeights[1])
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * Constants.referenceHeights[1].value - 15))
                    .font(.subheadline)

                TextAltitude(value: Constants.referenceHeights[2])
                    .position(.init(x: geometry.size.width - 20, y: geometry.size.height - geometry.size.height / Constants.maxHeight * Constants.referenceHeights[2].value - 15))
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
                HStack {
                    Text("QFE")
                    TextAltitude(value: model.qfe)
                }
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(model.qfe.value > 50 ? nil : .trunkRed)
            }
            .padding(.top)
        }
        .compositingGroup()
    }
}

struct LaunchProfileView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchProfileView(model: AHServiceViewModel())
            .frame(width: 300, height: 300)
    }
}
