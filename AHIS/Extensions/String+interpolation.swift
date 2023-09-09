//
//  String+interpolation.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 22/08/23.
//

import Foundation


extension String.StringInterpolation {
    enum Constants {
        static let naturalScaleNoDigits: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .naturalScale
            formatter.numberFormatter.maximumFractionDigits = 0
            formatter.unitStyle = .short
            return formatter
        }()
        
        static let naturalScaleDigits: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .providedUnit
            formatter.numberFormatter.maximumFractionDigits = 2
            formatter.unitStyle = .short
            return formatter
        }()
    }
    
    mutating func appendInterpolation<U: Unit>(naturalScale value: Measurement<U>, digits: Bool = false) {
        if digits {
            appendInterpolation(Constants.naturalScaleDigits.string(from: value))
        } else {
            appendInterpolation(Constants.naturalScaleNoDigits.string(from: value))
        }
    }
}

extension Date {
    var localizedString: String {
        lazy var dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("yyyyMMMMddHHmmss")
            df.timeZone = TimeZone.current
            df.locale = Locale.current
            return df
        }()
        return dateFormatter.string(from: self)
    }
}
