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
            .overlay(alignment: .bottomTrailing) {
                Button {
                    self.showSettings.toggle()
                } label: {
                    Image(systemName: "airplane.circle")
                        .imageScale(.large)
                }
                .padding()
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
