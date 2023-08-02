//
//  AHServiceViewModel.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 02/08/23.
//

import Foundation
import Combine


public final class AHServiceViewModel: ObservableObject {
    private let ahService: DeviceMotionProtocol
    private var subscriptions = Set<AnyCancellable>()
    
    @Published public private(set) var roll: Int = 0
    @Published public private(set) var pitch: Int = 0
    @Published public private(set) var heading: Double = 0
    @Published public private(set) var speed: Double = 0

    init(ahService: DeviceMotionProtocol = DeviceMotionService()) {
        self.ahService = ahService
        
        ahService
            .roll
            .map { Int($0.degree) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.roll, on: self)
            .store(in: &subscriptions)

        ahService
            .pitch
            .map { Int($0.degree) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.pitch, on: self)
            .store(in: &subscriptions)

        ahService.heading
            .receive(on: DispatchQueue.main)
            .assign(to: \.heading, on: self)
            .store(in: &subscriptions)
        
        ahService
            .speed
            .receive(on: DispatchQueue.main)
            .print()
            .assign(to: \.speed, on: self)
            .store(in: &subscriptions)
    }
    
    func reset() {
        ahService.reset()
    }
}
