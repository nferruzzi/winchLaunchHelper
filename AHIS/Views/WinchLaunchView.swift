//
//  WinchLaunchView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import SwiftUI


struct WinchLaunchView: View {
    @ObservedObject var model: AHServiceViewModel
            
    
    struct StateButton: View {
        let state: MachineState
        let takingOff: TimeInterval?
        let current: TimeInterval
        let action: () -> ()
        
        var body: some View {
            Button(action: {
                action()
            }, label: {
                switch state {
                case .completed:
                    Text("Completed")
                case .aborted:
                    Text("Aborted")
                default:
                    if let takingOff = takingOff {
                        Text("\(Int(current - takingOff)) sec")
                    } else {
                        Text("Waiting...")
                    }
                }
            })
        }
    }

    @ViewBuilder
    var content: some View {
        VStack {
            HStack {
                TextSpeed(value: model.minSpeed)
                    .font(.caption)
                    .fixedSize()
                    .padding(.leading)
                TextSpeed(value: model.speed)
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)
                TextSpeed(value: model.maxSpeed)
                    .font(.caption)
                    .fixedSize()
                    .padding(.trailing)
            }
            
            StateButton(state: model.state,
                        takingOff: model.info.value.takeOffAltitude?.timestamp.relativeTimeInterval,
                        current: model.info.timestamp.relativeTimeInterval) {
                model.resetMachineState()
            }
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
