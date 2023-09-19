//
//  SettingsView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 18/08/23.
//

import SwiftUI

struct ReplayPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedReplay: URL?
    @State var replays: [URL] = []
    
    var body: some View {
        List(selection: $selectedReplay) {
            Text("Replay Off")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedReplay = nil
                    dismiss()
                }
                .tag(URL?(nil))
                        
            Section("Select to replay...") {
                ForEach(DeviceMotionService.replayList(), id: \.self) { url in
                    Text(url.deletingPathExtension().lastPathComponent)
                        .tag(url as URL?)
                }
                .onDelete { val in
                    for v in val {
                        let item = self.replays[v]
                        try? FileManager.default.removeItem(at: item)
                        self.replays = DeviceMotionService.replayList()
                    }
                }
            }
        }
        .onAppear {
            self.replays = DeviceMotionService.replayList()
        }
        .onChange(of: selectedReplay) { _ in
            self.dismiss()
        }
        .navigationTitle("Logs")
    }
}

struct SettingsView: View {
    @ObservedObject var model: AHServiceViewModel
    @Binding var showSettings: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State var minSpeed: String = ""
    @State var maxSpeed: String = ""
    @State var winchLength: String = ""
    @State var selectedReplay: URL? = nil
    
    var body: some View {
        NavigationView {
            Form {
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

                Section(header: Text("Logs")) {
                    Toggle("Automatically log winch launches", isOn: $model.record)
                        .disabled(selectedReplay != nil)
                    NavigationLink {
                        ReplayPickerView(selectedReplay: $selectedReplay)
                    } label: {
                        Text(selectedReplay?.deletingPathExtension().lastPathComponent ?? "Replay Off")
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(leading:
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "arrow.left")
                }
            )
            .onAppear {
                minSpeed = model.minSpeed.converted(to: .kilometersPerHour).value.formatted()
                maxSpeed = model.maxSpeed.converted(to: .kilometersPerHour).value.formatted()
                winchLength = model.winchLength.converted(to: .meters).value.formatted()
                selectedReplay = Services.shared.replayURL
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
            .onChange(of: selectedReplay) { newValue in
                Services.shared.setup(replay: newValue)
            }
        }
    }
}
