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
                    Text("1m, 20m, 50m, 100m, 200m, 250m")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        }
        .navigationTitle("Alerts")
    }
}
