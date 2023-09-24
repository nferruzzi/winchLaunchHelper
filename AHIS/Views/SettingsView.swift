//
//  SettingsView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 18/08/23.
//

import SwiftUI

enum UIUnitSpeed: String, CaseIterable {
    static let userSetting = "unitSpeed"
    
    case kmh, mph, knots
        
    var localizedString: LocalizedStringKey {
        switch self {
        case .kmh: "km/h"
        case .mph: "mph"
        case .knots: "kt"
        }
    }

    var unit: UnitSpeed {
        switch self {
        case .mph: return .milesPerHour
        case .kmh: return .kilometersPerHour
        case .knots: return .knots
        }
    }

    static var unit: UnitSpeed {
        switch UIUnitSpeed(rawValue: UserDefaults().string(forKey: Self.userSetting) ?? "") {
        case .mph: return .milesPerHour
        case .kmh: return .kilometersPerHour
        case .knots: return .knots
        default: return .kilometersPerHour
        }
    }
}

enum UIUnitAltitude: String, CaseIterable {
    static let userSetting = "unitAltitude"

    case meters, feets
    
    var localizedString: LocalizedStringKey {
        switch self {
        case .meters: "mt"
        case .feets: "ft"
        }
    }

    var unit: UnitLength {
        switch self {
        case .meters: return .meters
        case .feets: return .feet
        }
    }

    static var unit: UnitLength {
        switch UIUnitAltitude(rawValue: UserDefaults().string(forKey: Self.userSetting) ?? "") {
        case .meters: return .meters
        case .feets: return .feet
        default: return .meters
        }
    }
}

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

struct RowLabelStyle: LabelStyle {
    let color: Color
    
    init(color: Color) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            configuration.icon
                .frame(width: 24, height: 24, alignment: .center)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            configuration.title
        }
    }
}

struct RowStyle: TextFieldStyle {
    let labelName: LocalizedStringKey
    let unitName: LocalizedStringKey?
    let systemImage: String
    let color: Color
    
    init(labelName: LocalizedStringKey, systemImage: String, color: Color, unitName: LocalizedStringKey? = nil) {
        self.labelName = labelName
        self.unitName = unitName
        self.systemImage = systemImage
        self.color = color
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label(labelName, systemImage: systemImage)
                .labelStyle(RowLabelStyle(color: color))
            configuration
                .foregroundColor(.accentColor)
            if let unitName {
                Text(unitName).font(.caption)
            }
        }
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

    @AppStorage("pilotName") var pilotName: String = ""
    @AppStorage("gliderRegistration") var gliderRegistration: String = ""
    @AppStorage(UIUnitSpeed.userSetting) var unitSpeed: UIUnitSpeed = .kmh
    @AppStorage(UIUnitAltitude.userSetting) var unitAltitude: UIUnitAltitude = .meters

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pilot")) {
                    TextField("name", text: $pilotName)
                        .textFieldStyle(RowStyle(labelName: "Name", systemImage: "person", color: .accentColor))
                }
                
                Section(header: Text("Units")) {
                    Picker(selection: $unitSpeed) {
                        ForEach(UIUnitSpeed.allCases, id: \.self) { value in
                            Text(value.localizedString)
                                .tag(value)
                        }
                    } label: {
                        Label("Speed", systemImage: "circle")
                            .labelStyle(RowLabelStyle(color: Color.orange))
                    }

                    Picker(selection: $unitAltitude) {
                        ForEach(UIUnitAltitude.allCases, id: \.self) { value in
                            Text(value.localizedString)
                                .tag(value)
                        }
                    } label: {
                        Label("Altitude / length", systemImage: "square")
                            .labelStyle(RowLabelStyle(color: Color.orange))
                    }
                }
                
                Section(header: Text("Glider")) {
                    TextField("registration", text: $gliderRegistration)
                        .textFieldStyle(RowStyle(labelName: "Registration", systemImage: "airplane", color: .leafGreen))
                    TextField(unitSpeed.localizedString, text: $minSpeed)
                        .textFieldStyle(RowStyle(labelName: "Min Speed", systemImage: "speedometer", color: .trunkRed, unitName: unitSpeed.localizedString))
                   TextField(unitSpeed.localizedString, text: $maxSpeed)
                        .textFieldStyle(RowStyle(labelName: "Max Speed", systemImage: "speedometer", color: .trunkRed, unitName: unitSpeed.localizedString))
                }
                
                Section(header: Text("Winch")) {
                    TextField(unitAltitude.localizedString, text: $winchLength)
                        .textFieldStyle(RowStyle(labelName: "Winch Length", systemImage: "arrow.left.and.right", color: .leafGreen, unitName: unitAltitude.localizedString))
                }

                Section(header: Text("Logs")) {
                    Toggle(isOn: $model.record) {
                        Label("Automatically log winch launches", systemImage: "recordingtape.circle")
                            .labelStyle(RowLabelStyle(color: Color.accentColor))
                    }
                    .disabled(selectedReplay != nil)

                    NavigationLink {
                        ReplayPickerView(selectedReplay: $selectedReplay)
                    } label: {
                        Label("Replay", systemImage: "play")
                            .labelStyle(RowLabelStyle(color: Color.accentColor))
                        Text(selectedReplay?.deletingPathExtension().lastPathComponent ?? "Off")
                            .foregroundColor(.accentColor)
                        
                    }
                }
            }
            .tint(.accentColor)
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
