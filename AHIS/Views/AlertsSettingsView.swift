//
//  AlertsSettingsView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 09/03/26.
//

import SwiftUI
import AVFoundation


struct AlertsSettingsView: View {
    @ObservedObject var model: AHServiceViewModel
    @State private var newAltitude: String = ""

    var body: some View {
        Form {
            Section(header: Text("Speech Rate")) {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "tortoise")
                        Slider(value: $model.speechRate, in: 0.1...0.65, step: 0.05)
                        Image(systemName: "hare")
                    }
                    Text("Rate: \(model.speechRate, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    model.say("100")
                } label: {
                    Label("Test", systemImage: "play.circle")
                }
            }

            Section(header: Text("Altitude Callouts")) {
                Toggle(isOn: $model.altitudeCalloutsEnabled) {
                    Label("Altitude announcements", systemImage: "arrow.up")
                        .labelStyle(RowLabelStyle(color: .blue))
                }
                if model.altitudeCalloutsEnabled {
                    ForEach(model.configuredAltitudes.sorted(), id: \.self) { alt in
                        HStack {
                            Text("\(alt) m")
                            Spacer()
                            Button(role: .destructive) {
                                model.configuredAltitudes.removeAll { $0 == alt }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    HStack {
                        TextField("meters", text: $newAltitude)
                            .keyboardType(.numberPad)
                        Button {
                            if let value = Int(newAltitude), value > 0, !model.configuredAltitudes.contains(value) {
                                model.configuredAltitudes.append(value)
                                newAltitude = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Section(header: Text("Min Speed")) {
                Toggle(isOn: $model.minSpeedCalloutEnabled) {
                    Label("Min speed reached", systemImage: "speedometer")
                        .labelStyle(RowLabelStyle(color: .green))
                }
                if model.minSpeedCalloutEnabled {
                    HStack {
                        Label("Reached", systemImage: "text.bubble")
                            .labelStyle(RowLabelStyle(color: .green))
                        TextField("minima", text: $model.minSpeedMessage)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.accentColor)
                    }
                    HStack {
                        Label("Lost", systemImage: "text.bubble")
                            .labelStyle(RowLabelStyle(color: .yellow))
                        TextField("più", text: $model.minSpeedLostMessage)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.accentColor)
                    }
                    Button {
                        model.say(model.minSpeedMessage)
                    } label: {
                        Label("Test reached", systemImage: "play.circle")
                    }
                    Button {
                        model.say(model.minSpeedLostMessage)
                    } label: {
                        Label("Test lost", systemImage: "play.circle")
                    }
                }
            }

            Section(header: Text("Max Speed")) {
                Toggle(isOn: $model.maxSpeedCalloutEnabled) {
                    Label("Overspeed alert", systemImage: "exclamationmark.triangle")
                        .labelStyle(RowLabelStyle(color: .red))
                }
                if model.maxSpeedCalloutEnabled {
                    HStack {
                        Label("Message", systemImage: "text.bubble")
                            .labelStyle(RowLabelStyle(color: .red))
                        TextField("meno", text: $model.maxSpeedMessage)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.accentColor)
                    }
                    Button {
                        model.say(model.maxSpeedMessage)
                    } label: {
                        Label("Test", systemImage: "play.circle")
                    }
                }
            }

            Section(header: Text("Wing Drop")) {
                Toggle(isOn: $model.wingDropCalloutEnabled) {
                    Label("Wing drop alert", systemImage: "airplane.departure")
                        .labelStyle(RowLabelStyle(color: .orange))
                }
                if model.wingDropCalloutEnabled {
                    HStack {
                        Label("Message", systemImage: "text.bubble")
                            .labelStyle(RowLabelStyle(color: .orange))
                        TextField("ala", text: $model.wingDropMessage)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.accentColor)
                    }
                    Button {
                        model.say(model.wingDropMessage)
                    } label: {
                        Label("Test", systemImage: "play.circle")
                    }
                }
            }

            Section(header: Text("Completion")) {
                Toggle(isOn: $model.maxAltitudeCalloutEnabled) {
                    Label("Max altitude at completion", systemImage: "flag.checkered")
                        .labelStyle(RowLabelStyle(color: .green))
                }
            }
            Section {
                Text("This app is provided as a supplementary aid only. Voice alerts are based on sensor data that may be inaccurate, delayed, or unavailable. The pilot in command remains solely responsible for all decisions during flight. Never rely on this app as a primary source of information. The developer assumes no liability for any damage, injury, or loss arising from the use of this app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Alerts")
    }
}
