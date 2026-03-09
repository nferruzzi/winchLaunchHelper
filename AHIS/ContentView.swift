//
//  ContentView.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI


struct ContentView: View {
    @State private var isPortrait = true
    @State private var showSettings = false
    
    @ObservedObject var model: AHServiceViewModel
    
    var body: some View {
        ZStack {
            Group {
                if isPortrait {
                    GeometryReader { value in
                        VStack(spacing: 0) {
                            AttitudeIndicatorView(model: model)
                                .frame(height: value.size.height / 2.3)

                            LaunchProfileView(model: model)
                            
                            WinchLaunchView(model: model)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    HStack {
                        AttitudeIndicatorView(model: model)
                        WinchLaunchView(model: model)
                        HeadingIndicatorView(model: model)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    if model.isSimulation {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.orange)
                        Text("REPLAY")
                            .foregroundStyle(.orange)
                    } else {
                        let color = gpsColor(accuracy: model.gpsHorizontalAccuracy)
                        Image(systemName: model.gpsHorizontalAccuracy != nil ? "location.fill" : "location.slash.fill")
                            .foregroundStyle(color)
                            .opacity(model.gpsBlinking ? 0.3 : 1.0)
                        Text("GPS")
                            .foregroundStyle(color)
                    }
                }
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(8)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "airplane.circle")
                        .imageScale(.large)
                }
                .padding()
                .accessibilityIdentifier("Settings")
            }
            
            if showSettings {
                SettingsView(model: model, showSettings: $showSettings)
            }
            
        }.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            guard let scene = UIApplication.shared.windows.first?.windowScene else { return }
            self.isPortrait = scene.interfaceOrientation.isPortrait
        }
    }
}

private func gpsColor(accuracy: Double?) -> Color {
    guard let accuracy else { return .red }
    if accuracy <= 10 { return .green }
    if accuracy >= 100 { return .red }
    // 100 → 10: red → orange → yellow → green
    let t = (100 - accuracy) / 90  // 0 at 100m, 1 at 10m
    if t < 0.33 {
        // red → orange
        let p = t / 0.33
        return Color(red: 1.0, green: 0.5 * p, blue: 0)
    } else if t < 0.66 {
        // orange → yellow
        let p = (t - 0.33) / 0.33
        return Color(red: 1.0, green: 0.5 + 0.5 * p, blue: 0)
    } else {
        // yellow → green
        let p = (t - 0.66) / 0.34
        return Color(red: 1.0 - p, green: 1.0, blue: 0)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: AHServiceViewModel())
            .preferredColorScheme(.dark)
    }
}
