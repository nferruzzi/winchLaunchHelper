//
//  SettingsView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 18/08/23.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AHServiceViewModel
    @Binding var showSettings: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State var minSpeed: String = ""
    @State var maxSpeed: String = ""
    @State var winchLength: String = ""

    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Glider")) {
                    HStack{
                        Text("Min Speed")
                        TextField("km/h", text: $minSpeed)
                            .foregroundColor(.accentColor)
                    }
                    HStack{
                        Text("Max Speed")
                        TextField("km/h", text: $maxSpeed)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Section(header: Text("Winch")) {
                    HStack{
                        Text("Winch length")
                        TextField("meters", text: $winchLength)
                            .foregroundColor(.accentColor)
                    }
                }

                Section(header: Text("Record")) {
                    Toggle("Log sensors data to local json files", isOn: $model.record)
                }
            }
            .listStyle(GroupedListStyle()) // Questo style assomiglia alle settings di iOS
            .navigationTitle("Settings")
            .navigationBarItems(leading:
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "arrow.left") // icona di freccia a sinistra
                }
            )
            .onAppear {
                minSpeed = model.minSpeed.converted(to: .kilometersPerHour).value.formatted()
                maxSpeed = model.maxSpeed.converted(to: .kilometersPerHour).value.formatted()
                winchLength = model.winchLength.converted(to: .meters).value.formatted()
            }
            .onChange(of: minSpeed) { newValue in
                guard let nv = Double(newValue) else { return }
                model.minSpeed = .init(value: nv, unit: .kilometersPerHour)
            }
            .onChange(of: maxSpeed) { newValue in
                guard let nv = Double(newValue) else { return }
                model.maxSpeed = .init(value: nv, unit: .kilometersPerHour)
            }
            .onChange(of: winchLength) { newValue in
                guard let nv = Double(newValue) else { return }
                model.winchLength = .init(value: nv, unit: .meters)
            }
        }
    }
}
