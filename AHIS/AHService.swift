//
//  AHService.swift
//  AHIS
//
//  Created by nferruzzi on 08/01/21.
//

import Foundation
import Combine
import CoreMotion


public protocol AHProtocol {
    var deviceMotion: AnyPublisher<CMDeviceMotion?, Never> { get }
    func reset()
}


public class AHService: AHProtocol {
    enum Constants {
        static let manager = CMMotionManager()
        static let queue = OperationQueue()
    }

    @Published private var deviceMotionSubject: CMDeviceMotion?
    private var referenceAttitude: CMAttitude?
    private var latestAttitude: CMAttitude?
    
    public var deviceMotion: AnyPublisher<CMDeviceMotion?, Never> {
        $deviceMotionSubject.eraseToAnyPublisher()
    }

    public init() {
        Constants.manager.showsDeviceMovementDisplay = true
        Constants.manager.deviceMotionUpdateInterval = TimeInterval(1.0/25.0)
        start(reference: .xArbitraryZVertical)
    }
    
    private func start(reference: CMAttitudeReferenceFrame) {
        Constants.manager.stopDeviceMotionUpdates()
        Constants.manager.startDeviceMotionUpdates(using: reference, to: Constants.queue) { [weak self](motion: CMDeviceMotion?, error: Error?) in
            guard let motion = motion else { return }
            self?.latestAttitude = motion.attitude.copy() as? CMAttitude
            
            if let ra = self?.referenceAttitude {
                motion.attitude.multiply(byInverseOf: ra)
            }
            self?.deviceMotionSubject = motion
        }
    }
    
    public func reset() {
        referenceAttitude = latestAttitude?.copy() as? CMAttitude
    }
}


public class AHServiceViewModel: ObservableObject {
    private let ahService: AHProtocol
    private var subscriptions = Set<AnyCancellable>()

    public private(set) var motion: CMDeviceMotion?
    
    @Published public private(set) var roll: Int = 0
    @Published public private(set) var pitch: Int = 0
    @Published public private(set) var yaw: Int = 0

    init() {
        ahService = AHService()
        let share = ahService.deviceMotion
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .share()
            
        share
            .map { val -> CMDeviceMotion? in val}
            .assign(to: \.motion, on: self)
            .store(in: &subscriptions)
        
        share.map { Int($0.attitude.roll.degree) }
            .removeDuplicates()
            .assign(to: \.roll, on: self)
            .store(in: &subscriptions)

        share.map { Int($0.attitude.pitch.degree) }
            .removeDuplicates()
            .assign(to: \.pitch, on: self)
            .store(in: &subscriptions)

        share.map { Int($0.attitude.yaw.degree) }
            .removeDuplicates()
            .assign(to: \.yaw, on: self)
            .store(in: &subscriptions)
    }
    
    func reset() {
        ahService.reset()
    }
}
