//
//  AHServiceViewModel.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import Combine
import CoreLocation


final class AHServiceViewModel: ObservableObject {
    private var subscriptions = Set<AnyCancellable>()
    
    private let ahService: DeviceMotionProtocol?
    private let machineStateService: MachineStateProtocol?
    
    @Published private(set) var roll: Int = 0
    @Published private(set) var pitch: Int = 0
    @Published private(set) var heading: Double = 0
    @Published private(set) var speed: CLLocationSpeed = 0
    @Published private(set) var acceleration: CLLocationSpeed = 0
    @Published private(set) var state: MachineState = .constantSpeed

    init(ahService: DeviceMotionProtocol? = nil,
         machineStateService: MachineStateProtocol? = nil) {

        self.ahService = ahService
        self.machineStateService = machineStateService
        
        ahService?
            .roll
            .map { Int($0.degree) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.roll, on: self)
            .store(in: &subscriptions)

        ahService?
            .pitch
            .map { Int($0.degree) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.pitch, on: self)
            .store(in: &subscriptions)

        ahService?.heading
            .receive(on: DispatchQueue.main)
            .assign(to: \.heading, on: self)
            .store(in: &subscriptions)
        
        machineStateService?
            .speed
            .receive(on: DispatchQueue.main)
            .print()
            .assign(to: \.speed, on: self)
            .store(in: &subscriptions)

        machineStateService?
            .acceleration
            .receive(on: DispatchQueue.main)
            .print()
            .assign(to: \.acceleration, on: self)
            .store(in: &subscriptions)

        machineStateService?
            .machineState
            .receive(on: DispatchQueue.main)
            .print()
            .assign(to: \.state, on: self)
            .store(in: &subscriptions)
    }
    
    func reset() {
        ahService?.reset()
    }
}
