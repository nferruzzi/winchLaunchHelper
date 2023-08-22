//
//  WinchLaunchView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import SwiftUI


struct WinchLaunchView: View {
    @ObservedObject var model: AHServiceViewModel
            
    var minSpeed: String {
        "\(naturalScale: model.minSpeed.converted(to: .kilometersPerHour))"
    }

    var speed: String {
        "\(naturalScale: model.speed.converted(to: .kilometersPerHour))"
    }

    var maxSpeed: String {
        "\(naturalScale: model.maxSpeed.converted(to: .kilometersPerHour))"
    }

    @ViewBuilder
    var content: some View {
        VStack {
            HStack {
                Text(minSpeed)
                    .font(.caption)
                    .fixedSize()
                    .padding(.leading)
                Text(speed)
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(maxSpeed)
                    .font(.caption)
                    .fixedSize()
                    .padding(.trailing)
            }
            if let takingOff = model.takingOffDate {
                Text("\(-Int(takingOff.timeIntervalSinceNow)) sec")
            } else {
                Text("Waiting...")
            }
//            Text(model.state.rawValue)
//                .font(.system(size: 20, weight: .bold, design: .monospaced))
        }
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct WinchLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        WinchLaunchView(model: AHServiceViewModel())
    }
}
