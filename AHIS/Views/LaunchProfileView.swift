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
    }

    @ObservedObject var model: AHServiceViewModel

    private var calloutHeights: [Measurement<UnitLength>] {
        model.configuredAltitudes.sorted().map { .init(value: Double($0), unit: .meters) }
    }

    var info: some View {
        ZStack(alignment: .bottom) {
            ForEach(calloutHeights, id: \.value) { height in
                GridShape(value: height.value, max: Constants.maxHeight)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
            }
        }
    }

    var labels: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ForEach(calloutHeights, id: \.value) { height in
                    TextAltitude(value: height)
                        .position(.init(x: geometry.size.width - 20,
                                        y: geometry.size.height - geometry.size.height / Constants.maxHeight * height.value - 15))
                        .font(.subheadline)
                }
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
