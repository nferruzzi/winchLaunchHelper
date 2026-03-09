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
    
    var model: AHServiceViewModel
    
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
                        Image(systemName: model.hasGPSFix ? "location.fill" : "location.slash.fill")
                            .foregroundStyle(model.hasGPSFix ? .green : .red)
                            .opacity(model.gpsBlinking ? 0.3 : 1.0)
                        Text(model.hasGPSFix ? "GPS" : "GPS")
                            .foregroundStyle(model.hasGPSFix ? .green : .red)
                        // Debug: show raw GPS speed
                        Text(String(format: "%.1f", model.gpsSpeed.converted(to: .kilometersPerHour).value))
                            .foregroundStyle(.gray)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: AHServiceViewModel())
            .preferredColorScheme(.dark)
    }
}
