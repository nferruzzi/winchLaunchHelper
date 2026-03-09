//
//  DisclaimerView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 09/03/26.
//

import SwiftUI


struct DisclaimerView: View {
    @Binding var accepted: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("Disclaimer")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This app is provided as a supplementary aid only. Voice alerts are based on sensor data that may be inaccurate, delayed, or unavailable.\n\nThe pilot in command remains solely responsible for all decisions during flight. Never rely on this app as a primary source of information.\n\nThe developer assumes no liability for any damage, injury, or loss arising from the use of this app.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                accepted = true
            } label: {
                Text("I understand and accept")
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
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}
