//
//  Double+math.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 01/08/23.
//

import Foundation

extension Double {
    var degree: Double {
        (self * 180.0) / Double.pi
    }

    /// The conversion formula found online expects the module operator to work like the python one for negative numbers
    /// AKA: mod = a - math.floor(a/b) * base
    func pythonMod(by val: Double) -> Double {
        self - floor(self / val) * val
    }
}
