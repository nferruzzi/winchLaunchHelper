//
//  DisclaimerView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 09/03/26.
//

import SwiftUI
import UIKit
import CoreLocation


struct DisclaimerView: View {
    @Binding var accepted: Bool
    var ahService: DeviceMotionProtocol?

    @State private var step: OnboardingStep = .disclaimer
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus

    enum OnboardingStep {
        case disclaimer
        case permissions
    }

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .disclaimer:
                disclaimerContent
            case .permissions:
                permissionsContent
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    // MARK: - Step 1: Disclaimer

    private var disclaimerContent: some View {
        Group {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text(String(localized: "onboarding.disclaimer.title", defaultValue: "Disclaimer"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "onboarding.disclaimer.body", defaultValue: "This app is provided as a supplementary aid only. Voice alerts are based on sensor data that may be inaccurate, delayed, or unavailable.\n\nThe pilot in command remains solely responsible for all decisions during flight. Never rely on this app as a primary source of information.\n\nThe developer assumes no liability for any damage, injury, or loss arising from the use of this app."))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                step = .permissions
            } label: {
                Text(String(localized: "onboarding.disclaimer.accept", defaultValue: "I understand and accept"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 2: Permissions

    private var permissionsContent: some View {
        Group {
            Spacer()

            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text(String(localized: "onboarding.permissions.title", defaultValue: "Permissions Required"))
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                permissionRow(
                    icon: "location.fill",
                    color: .blue,
                    title: String(localized: "onboarding.permissions.gps.title", defaultValue: "GPS Location"),
                    description: String(localized: "onboarding.permissions.gps.body", defaultValue: "Measures ground speed and runway distance during the winch launch. Without GPS the app cannot function.")
                )

                permissionRow(
                    icon: "gyroscope",
                    color: .purple,
                    title: String(localized: "onboarding.permissions.motion.title", defaultValue: "Motion Sensors"),
                    description: String(localized: "onboarding.permissions.motion.body", defaultValue: "Powers the artificial horizon and improves speed accuracy between GPS readings using the accelerometer at 50Hz.")
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            if locationStatus == .denied || locationStatus == .restricted {
                deniedLocationView
            } else {
                Button {
                    ahService?.requestLocationPermission()
                    // Check if already authorized (returning user)
                    let status = CLLocationManager().authorizationStatus
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        accepted = true
                    } else {
                        // Will be updated via onChange
                        observeAuthorizationChange()
                    }
                } label: {
                    Text(String(localized: "onboarding.permissions.continue", defaultValue: "Allow and Continue"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: locationStatus) { newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                accepted = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update status when returning from Settings app
            locationStatus = CLLocationManager().authorizationStatus
        }
    }

    private var deniedLocationView: some View {
        VStack(spacing: 12) {
            Text(String(localized: "onboarding.permissions.denied", defaultValue: "Location permission was denied. Winch Pilot needs GPS to work. Please enable it in Settings."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.red)
                .padding(.horizontal)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(String(localized: "onboarding.permissions.openSettings", defaultValue: "Open Settings"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func permissionRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func observeAuthorizationChange() {
        // Poll briefly for authorization change after system dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            locationStatus = CLLocationManager().authorizationStatus
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            locationStatus = CLLocationManager().authorizationStatus
        }
    }
}
