//
//  GPSFixView.swift
//  AHIS
//

import SwiftUI

struct GPSFixView: View {
    @ObservedObject var model: AHServiceViewModel
    @Binding var dismissed: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if model.hasGPSFix {
                Image(systemName: "location.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text(String(localized: "onboarding.gps.ready.title", defaultValue: "GPS Ready"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let acc = model.gpsHorizontalAccuracy {
                    Text("\(Int(acc))m")
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)

                Text(String(localized: "onboarding.gps.waiting.title", defaultValue: "Waiting for GPS Signal"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(String(localized: "onboarding.gps.waiting.body", defaultValue: "Make sure you are outdoors with a clear view of the sky."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if let acc = model.gpsHorizontalAccuracy {
                    Text("\(Int(acc))m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                dismissed = true
            } label: {
                Text(model.hasGPSFix
                     ? String(localized: "onboarding.gps.start", defaultValue: "Start")
                     : String(localized: "onboarding.gps.skip", defaultValue: "Skip"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(model.hasGPSFix ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.easeInOut, value: model.hasGPSFix)
        .preferredColorScheme(.dark)
        .onChange(of: model.hasGPSFix) { hasFix in
            if hasFix {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismissed = true
                }
            }
        }
    }
}
