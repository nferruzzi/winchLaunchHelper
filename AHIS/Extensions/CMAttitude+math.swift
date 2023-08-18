//
//  CMAttitude+math.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 10/08/23.
//

import Foundation
import simd
import CoreMotion


extension CMQuaternion {
    var simdQuatd: simd_quatd {
        simd_quatd(ix: x, iy: y, iz: z, r: w)
    }
}

extension simd_quatd {
    // Note: X and Y axis from the CM look swapped / use a different convention.

    var pitch: Double {
        let roll = atan2(2.0 * (real * imag.x + imag.y * imag.z),
                         1 - 2 * (imag.x * imag.x + imag.y * imag.y))
        return roll - Double.pi/2
    }
    
    var roll: Double {
        let pitch = asin(2.0 * (real * imag.y - imag.z * imag.x))
        return -pitch
    }
    
    /// Not tested
    var yaw: Double {
        let yaw = atan2(2.0 * (real * imag.z + imag.x * imag.y),
                        1 - 2 * (imag.y * imag.y + imag.z * imag.z))
        return yaw
    }
}

extension CMAcceleration {
    var simDouble3: simd_double3 {
        simd_double3(x, y, z)
    }
}
