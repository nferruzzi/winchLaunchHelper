//
//  WinchLaunchView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import SwiftUI


struct WinchLaunchView: View {
    @ObservedObject var model: AHServiceViewModel
    @Binding var showSettings: Bool

    struct StateButton: View {
        let state: MachineState
        let takingOff: TimeInterval?
        let current: TimeInterval
        let action: () -> ()

        var body: some View {
            Button(action: {
                action()
            }, label: {
                Group {
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            })
        }
    }

    @ViewBuilder
    var content: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 4)
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

            ZStack {
                StateButton(state: model.state,
                            takingOff: model.info.value.takeOffAltitude?.timestamp.relativeTimeInterval,
                            current: model.info.timestamp.relativeTimeInterval) {
                    model.resetMachineState()
                }

                HStack {
                    Spacer()
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    }
                    .accessibilityIdentifier("Settings")
                    .padding(.trailing)
                }
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
        WinchLaunchView(model: AHServiceViewModel(), showSettings: .constant(false))
    }
}
