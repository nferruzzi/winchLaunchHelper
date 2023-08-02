//
//  ContentView.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI


struct ContentView: View {
    @State private var isPortrait = true
    var model: AHServiceViewModel
    
    var body: some View {
        Group {
            if isPortrait {
                VStack {
                    AttitudeIndicatorView(model: model)
                    WinchLaunchView(model: model)
                }
            } else {
                HStack {
                    AttitudeIndicatorView(model: model)
                    WinchLaunchView(model: model)
                    HeadingIndicatorView(model: model)
                }
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
