//
//  WinchLengthView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 21/08/23.
//

import SwiftUI


struct DiagonalBarsView: View {
    let numberOfBars: Int
    let colors: [Color]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(-1..<numberOfBars+1, id: \.self) { index in
                    Path { path in
                        let step = geometry.size.width / CGFloat(numberOfBars)
                        let startX = step * CGFloat(index)
                        path.move(to: CGPoint(x: startX, y: 0))
                        path.addLine(to: CGPoint(x: startX + step, y: 0))
                        path.addLine(to: CGPoint(x: startX, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: startX - step, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(colors[(index + 1) % colors.count])
                }
            }
        }
        .clipped()
    }
}


struct WinchLengthView: View {
    @ObservedObject var model: AHServiceViewModel

    var completed: Double {
        model.distanceFromInitialLocation.value / model.winchLength.value
    }
    
    var distance: String {
        "\(naturalScale: model.winchLength - model.distanceFromInitialLocation)"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                DiagonalBarsView(numberOfBars: 30, colors: [.orange, .red])

                WinchLengthShape(completed: completed)
                    .fill(Color.green)
                    .animation(.linear, value: model.distanceFromInitialLocation)
            }
            .overlay(alignment: .center) {
                Text(distance)
                    .font(.system(size: geometry.size.height, weight: .bold))
            }
        }
        .frame(height: 40)
        .padding()
    }
}
