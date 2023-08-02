//
//  WinchLaunchView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import SwiftUI


struct WinchLaunchView: View {
    @ObservedObject var model: AHServiceViewModel

    var speed: Measurement<UnitSpeed> {
        Measurement(value: model.speed, unit: UnitSpeed.metersPerSecond)
    }
    
    @ViewBuilder
    var content: some View {
        Text(speed.converted(to: .kilometersPerHour).formatted())
            .font(.system(size: 80, weight: .bold, design: .monospaced))
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
