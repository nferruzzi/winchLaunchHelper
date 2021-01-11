//
//  DeviceMotionService.swift
//  AHIS
//
//  Created by nferruzzi on 08/01/21.
//

import Foundation
import Combine
import CoreMotion
import UIKit


public protocol DeviceMotionProtocol {
    func reset()
    
    var roll: AnyPublisher<Double, Never> { get }
    var pitch: AnyPublisher<Double, Never> { get }
    var heading: AnyPublisher<Double, Never> { get }
}


public class DeviceMotionService: DeviceMotionProtocol {
    
    enum Constants {
        static let manager = CMMotionManager()
        static let queue = OperationQueue()
    }

    @Published private var deviceMotionSubject: CMDeviceMotion?
    @Published private var headingSubject: Double = 0
    @Published private var rollSubject: Double = 0
    @Published private var pitchSubject: Double = 0
    @Published private var interfaceOrientation: UIInterfaceOrientation = .portrait

    private var subscriptions = Set<AnyCancellable>()
    private var referenceAttitude: CMAttitude?
    private var latestAttitude: CMAttitude?
    private var rotate: Double = 10
    private var prevHeading: Double = 0
    
//    public var deviceMotion: AnyPublisher<CMDeviceMotion?, Never> {
//        $deviceMotionSubject.removeDuplicates().eraseToAnyPublisher()
//    }

    public var heading: AnyPublisher<Double, Never> {
        Publishers.CombineLatest($interfaceOrientation.removeDuplicates(),
                                 $headingSubject.removeDuplicates() )
            .map { orientation, heading in
                switch orientation {
                case .portrait:
                    return heading

                case .portraitUpsideDown:
                    return heading

                case .landscapeLeft:
                    return heading - 90

                case .landscapeRight:
                    return heading + 90

                default:
                    return heading
                }
            }
            .eraseToAnyPublisher()
    }

    public var roll: AnyPublisher<Double, Never> {
        $rollSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public var pitch: AnyPublisher<Double, Never> {
        $pitchSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public init() {
        Constants.manager.showsDeviceMovementDisplay = true
        Constants.manager.deviceMotionUpdateInterval = TimeInterval(1.0/25.0)
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ in
                UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
            }
            .assign(to: \.interfaceOrientation, on: self)
            .store(in: &subscriptions)

        start(reference: .xMagneticNorthZVertical)
        
        Publishers.CombineLatest($interfaceOrientation.removeDuplicates(),
                                 $deviceMotionSubject.compactMap { $0?.attitude } )
            .sink { [weak self] orientation, attitude in
                switch orientation {
                case .portrait:
                    self?.rollSubject = attitude.yaw
                    self?.pitchSubject = attitude.pitch

                case .portraitUpsideDown:
                    debugPrint("Portrait UP not tested")
                    self?.rollSubject = attitude.yaw
                    self?.pitchSubject = -attitude.pitch

                case .landscapeLeft:
                    self?.rollSubject = attitude.yaw
                    self?.pitchSubject = attitude.roll

                case .landscapeRight:
                    self?.rollSubject = attitude.yaw
                    self?.pitchSubject = -attitude.roll

                default:
                    debugPrint("Unknown")
                }
            }
            .store(in: &subscriptions)
    }
    
    private func start(reference: CMAttitudeReferenceFrame) {
        Constants.manager.stopDeviceMotionUpdates()
        Constants.manager.startDeviceMotionUpdates(using: reference, to: Constants.queue) { [weak self](motion: CMDeviceMotion?, error: Error?) in
            guard let motion = motion else { return }
            guard let self = self else { return }
            
            let heading = motion.heading
            
            if heading > 270 && self.prevHeading <= 90 {
                self.rotate -= 1
//                debugPrint("bug da 0 a 360 \(motion.heading) \(self.rotate)")
            }
            else
            if motion.heading < 90 && self.prevHeading > 270 {
                self.rotate += 1
//                debugPrint("bug da 360 a 0 \(motion.heading) \(self.rotate)")
            }

            self.prevHeading = motion.heading
            self.headingSubject = heading + self.rotate * 360
            
            self.latestAttitude = motion.attitude.copy() as? CMAttitude
            
            if let ra = self.referenceAttitude {
                motion.attitude.multiply(byInverseOf: ra)
            }

            self.deviceMotionSubject = motion
        }
    }
    
    public func reset() {
        referenceAttitude = latestAttitude?.copy() as? CMAttitude
    }
}


public class AHServiceViewModel: ObservableObject {
    private let ahService: DeviceMotionProtocol
    private var subscriptions = Set<AnyCancellable>()
    
    @Published public private(set) var roll: Int = 0
    @Published public private(set) var pitch: Int = 0
    @Published public private(set) var heading: Double = 0

    init() {
        ahService = DeviceMotionService()
        
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
    }
    
    func reset() {
        ahService.reset()
    }
}
