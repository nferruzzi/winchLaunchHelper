//
//  ContentView.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI


struct ContentView: View {
    @State private var isPortrait = true
    @StateObject var model = AHServiceViewModel()
    
    var body: some View {
        Group {
            if isPortrait {
                VStack {
                    AttitudeIndicatorView(model: model)
                    HeadingIndicatorView(model: model)
                }
            } else {
                HStack {
                    AttitudeIndicatorView(model: model)
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
        ContentView()
            .preferredColorScheme(.dark)
//        ContentView(sim: true)
//            .preferredColorScheme(.light)
//        ContentView(sim: true)
//            .previewDevice("iPhone 8")
//            .preferredColorScheme(.light)
//        ContentView(sim: true)
//            .previewDevice("iPad Pro (12.9-inch) (4th generation)")
//            .preferredColorScheme(.light)
    }
}
