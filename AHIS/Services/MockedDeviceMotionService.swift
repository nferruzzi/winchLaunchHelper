//
//  MockedDeviceMotionService.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import Combine
import CoreGraphics


fileprivate struct Point {
    var x: Double
    var y: Double
}


public final class MockedDeviceMotionService: DeviceMotionProtocol {
    enum Constants {
        fileprivate static let test: [CGPoint] = [
            .init(x: 0, y: 0), .init(x: 4, y: 70), .init(x: 15, y: 110), .init(x: 60, y: 115),
        ]
    }
    
    
    fileprivate func catmullRom(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * ((2 * p1.x) +
                      (-p0.x + p2.x) * t +
                      (2*p0.x - 5*p1.x + 4*p2.x - p3.x) * t2 +
                      (-p0.x + 3*p1.x - 3*p2.x + p3.x) * t3)

        let y = 0.5 * ((2 * p1.y) +
                      (-p0.y + p2.y) * t +
                      (2*p0.y - 5*p1.y + 4*p2.y - p3.y) * t2 +
                      (-p0.y + 3*p1.y - 3*p2.y + p3.y) * t3)

        return CGPoint(x: x, y: y)
    }
    
    
    fileprivate func interpolatePoints(points: [CGPoint]) -> [CGPoint] {
        precondition(points.count >= 4)
        
        /// Add a pair of edges to interpolate between all passed points
        let fixEdges: [CGPoint] =
            [.init(x: points.first!.x - 10, y: points.first!.y)] + points + [.init(x: points.last!.x + 10, y: points.last!.y)]
        
        var interpolatedPoints: [CGPoint] = []
        for i in 1..<fixEdges.count - 2 {
            let p0 = fixEdges[i - 1]
            let p1 = fixEdges[i]
            let p2 = fixEdges[i + 1]
            let p3 = fixEdges[i + 2]

            for t in stride(from: 0.0, to: 1.1, by: 0.001) {
                let interpolatedPoint = catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: CGFloat(t))
                interpolatedPoints.append(interpolatedPoint)
            }
        }

        return interpolatedPoints
    }
    
    fileprivate func filterClosestToIntX(points: [CGPoint]) -> [CGPoint] {
        var filteredPoints: [CGPoint] = []
        var previousIntX: Int = Int.min

        for point in points {
            let intX = Int(point.x.rounded())

            if intX != previousIntX && abs(point.x - CGFloat(intX)) <= 0.1 {
                filteredPoints.append(.init(x: CGFloat(intX), y: CGFloat(point.y.rounded())))
                previousIntX = intX
            }
        }

        return filteredPoints
    }
    
    fileprivate func indexYValuesForIntX(points: [CGPoint]) -> [Int: CGFloat] {
        var indexedValues: [Int: CGFloat] = [:]

        for point in points {
            let intX = Int(point.x.rounded())
            indexedValues[intX] = point.y
        }

        return indexedValues
    }

    @Published private var speedSubject: DataPointSpeed?
    @Published private var altitudeSubject: DataPointAltitude?

    public var roll: AnyPublisher<DataPointAngle, Never> {
        Just(.zero).eraseToAnyPublisher()
    }
    
    public var pitch: AnyPublisher<DataPointAngle, Never> {
        Just(.zero).eraseToAnyPublisher()
    }
    
    public var heading: AnyPublisher<DataPointAngle, Never> {
        Just(.zero).eraseToAnyPublisher()
    }
    
    public var speed: AnyPublisher<DataPointSpeed, Never> {
        $speedSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public var altitude: AnyPublisher<DataPointAltitude, Never> {
        $altitudeSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    
    public func reset() {}
    
    private var subscription = Set<AnyCancellable>()
    private var start: Date?

    
    public init() {
        let filtered = filterClosestToIntX(points: interpolatePoints(points: Constants.test))
        let indexed = indexYValuesForIntX(points: filtered)

        /// Data are generated with the same CM frequency (1hz)
        Timer.publish(every: 1.0, on: RunLoop.main, in: .default)
            .autoconnect()
            .sink { [unowned self] timer in
                self.start = self.start ?? timer
                let timestamp = timer.timeIntervalSince(self.start!)
                let diff = Int(timestamp.rounded())
                let speed = indexed[diff] ?? filtered.last!.y
//                print(timestamp, diff, speed)
                self.speedSubject = .init(timestamp: timestamp, value: .init(value: speed, unit: .kilometersPerHour).converted(to: .metersPerSecond))
//                self.altitudeSubject = .init(timestamp: timestamp, value: .init(value: self.altitudeSubject.value.value * 1.1, unit: .meters))
            }
            .store(in: &subscription)
    }
}
