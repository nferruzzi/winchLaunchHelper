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
            formatter.unitOptions = .naturalScale
            formatter.numberFormatter.maximumFractionDigits = 2
            formatter.unitStyle = .short
            return formatter
        }()

        static let providedUnitNoDigits: MeasurementFormatter = {
            let formatter = MeasurementFormatter()
            formatter.unitOptions = .providedUnit
            formatter.numberFormatter.maximumFractionDigits = 0
            formatter.numberFormatter.minimumFractionDigits = 0
            formatter.unitStyle = .short
            return formatter
        }()

        static let providedUnitDigits: MeasurementFormatter = {
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
    
    mutating func appendInterpolation(height value: Measurement<UnitLength>, digits: Bool = false) {
        if digits {
            appendInterpolation(Constants.providedUnitDigits.string(from: value.converted(to: .init(forLocale: Locale.current, usage: .personHeight))))
        } else {
            let val = value.converted(to: .init(forLocale: Locale.current, usage: .personHeight))
            let x = Constants.providedUnitNoDigits.string(from: .init(value: val.value.rounded(), unit: val.unit))
            appendInterpolation(x)
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
