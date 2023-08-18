//
//  WinchLaunchView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import SwiftUI


struct WinchLaunchView: View {
    enum Constants {
        static let formatter: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .naturalScale
            formatter.numberFormatter.maximumFractionDigits = 0
            formatter.unitStyle = .short
            return formatter
        }()

        static let nformatter: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .naturalScale
            formatter.numberFormatter.maximumFractionDigits = 0
            formatter.unitStyle = .short
            return formatter
        }()
    }
    
    @ObservedObject var model: AHServiceViewModel
            
    
    @ViewBuilder
    var content: some View {
        VStack {
            HStack {
                Text(Constants.nformatter.string(from: model.minSpeed.converted(to: .kilometersPerHour)))
                    .font(.caption)
                    .fixedSize()
                    .padding(.leading)
                Text(Constants.formatter.string(from: model.speed.converted(to: .kilometersPerHour)))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(Constants.nformatter.string(from: model.maxSpeed.converted(to: .kilometersPerHour)))
                    .font(.caption)
                    .fixedSize()
                    .padding(.trailing)
            }
            Text("GPS " + Constants.formatter.string(from: model.gpsSpeed.converted(to: .kilometersPerHour)))
                .font(.system(size: 30, weight: .bold, design: .monospaced))
//            Text(model.lasSayString)
//                .font(.system(size: 40, weight: .bold, design: .monospaced))
            Text(model.state.rawValue)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
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
