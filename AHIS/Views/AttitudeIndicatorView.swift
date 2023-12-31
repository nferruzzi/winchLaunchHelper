//
//  AttitudeIndicatorView.swift
//  AHIS
//
//  Created by Nicola Ferruzzi on 01/08/23.
//

import SwiftUI

fileprivate enum Constants {
    static let maskBoder: CGFloat = 40
}


fileprivate struct BackgroundView: View {
    enum Constants {
        static let fov: CGFloat = 90
    }


    func line(_ offset: CGFloat, _ value: String, _ width: CGFloat, _ height: CGFloat = 1) -> some View {
        HStack {
            Text(value)
            Rectangle()
                .frame(width: width, height: height)
            Text(value)
        }
        .font(.system(size: 10))
        .foregroundColor(.white)
        .offset(x: 0, y: ((outer ? 0 : pitch) + offset) * degreeToPixel)
    }
    
    func pin<Content: View>(_ angle: CGFloat, _ content: @autoclosure () -> Content) -> some View {
        let angle = 180 - angle
        let piAngle = (2 * CGFloat.pi * angle) / 360
        
        return content()
            .rotationEffect(.degrees(Double(-angle)), anchor: UnitPoint(x: 0.5, y: 0.8))
            .offset(x: sin(piAngle) * size/2.0, y: cos(piAngle) * size/2.0)
    }
        
    var background: some View {
        ZStack {
            SkyShape(size: size, horizont: outer ? pitchToPixel(0) : pitchToPixel(pitch))
                .fill(LinearGradient(gradient: Color.skyGradient, startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)
            
            if !outer {
                Rectangle()
                    .frame(width: size, height: size)
                    .foregroundColor(Color.trunkRed.opacity(pitchToOpacity(pitch)))
            }


            EarthShape(size: size, horizont: outer ? pitchToPixel(0) : pitchToPixel(pitch))
                .fill(LinearGradient(gradient: Color.earthGradient, startPoint: .bottom, endPoint: .top))
                .frame(width: size, height: size)

            if !outer {
                Group {
                    line(45, "", 50)
                    line(40, "40", 150, 2)
                    line(35, "", 50)
                    line(30, "30", 125)
                    line(25, "", 50)
                    line(20, "20", 100)
                    line(15, "", 50)
                    line(10, "10", 75)
                    line(5, "", 50)
                }
                Group {
                    line(-5, "", 50)
                    line(-10, "10", 75)
                    line(-15, "", 50)
                    line(-20, "20", 100)
                    line(-25, "", 50)
                    line(-30, "30", 125)
                    line(-35, "", 50)
                    line(-40, "40", 150, 2)
                    line(-45, "", 50)
                }
            }
        }
        .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fill)
        .overlay(line(0, "", size).foregroundColor(.white))
        .overlay(pin(0, TriangleShape(offset: 0).frame(width: 30, height: 35).foregroundColor(.white)))
        .overlay(pin(45, TriangleShape(offset: 0).frame(width: 15, height: 20).offset(x: 0, y: -17).foregroundColor(.white)))
        .overlay(pin(-45, TriangleShape(offset: 0).frame(width: 15, height: 20).offset(x: 0, y: -17).foregroundColor(.white)))
        .overlay(pin(10, Rectangle().frame(width: 3, height: 20).offset(x: 0, y: -15).foregroundColor(.white)))
        .overlay(pin(-10, Rectangle().frame(width: 3, height: 20).offset(x: 0, y: -15).foregroundColor(.white)))
        .overlay(pin(20, Rectangle().frame(width: 3, height: 20).offset(x: 0, y: -15).foregroundColor(.white)))
        .overlay(pin(-20, Rectangle().frame(width: 3, height: 20).offset(x: 0, y: -15).foregroundColor(.white)))
        .overlay(pin(30, Rectangle().frame(width: 5, height: 33).offset(x: 0, y: -2).foregroundColor(.white)))
        .overlay(pin(-30, Rectangle().frame(width: 5, height: 33).offset(x: 0, y: -2).foregroundColor(.white)))
        .overlay(pin(60, Rectangle().frame(width: 5, height: 33).offset(x: 0, y: -5).foregroundColor(.white)))
        .overlay(pin(-60, Rectangle().frame(width: 5, height: 33).offset(x: 0, y: -5).foregroundColor(.white)))
        .rotationEffect(Angle(degrees: Double(roll)), anchor: .center)
        .drawingGroup()
    }
    
    let width: CGFloat
    let height: CGFloat
    let pitch: CGFloat
    let roll: CGFloat
//    let yaw: CGFloat
    let outer: Bool
    
    var degreeToPixel: CGFloat {
        size / Constants.fov
    }

    func pitchToPixel(_ pitch: CGFloat) -> CGFloat {
        size / 2.0 + pitch * degreeToPixel
    }
    
    func pitchToOpacity(_ pitch: CGFloat, _ maxAngle: CGFloat = 50, _ offset: CGFloat = 30) -> CGFloat {
        let clamped = min(max(pitch - offset, 0), maxAngle - offset) / (maxAngle - offset)
        return clamped
    }

    var size: CGFloat {
        min(width, height)
    }

    var body: some View {
        background
    }
}


struct AttitudeIndicatorView: View {
    @ObservedObject var model: AHServiceViewModel

    var plane: some View {
        Path { path in
            path.move(to: CGPoint(x: 45, y: 0))
            path.addLine(to: CGPoint(x: 90, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 20))
        }
            .foregroundColor(.yellow)
            .frame(width: 90, height: 1, alignment: .center)
    }
    
    var virata: some View {
        TriangleShape(offset: 0)
            .foregroundColor(.yellow)
            .frame(width: 30, height: 14, alignment: .top)
            .offset(x: 0, y: 42)
    }
    
    var align: some View {
        Button {
            model.reset()
        } label: {
            Image(systemName: "rotate.3d")
                .imageScale(.large)
        }

    }
    
    @ViewBuilder
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geometry in
                    BackgroundView(width: geometry.size.width,
                                   height: geometry.size.height,
                                   pitch: CGFloat(model.pitch),
                                   roll: CGFloat(model.roll),
                                   outer: false)
                        .animation(.linear, value: model.pitch + model.roll)
                        .mask(Circle())
                        .overlay(plane.shadow(radius: 5), alignment: .center)
                        .overlay(virata.shadow(radius: 5), alignment: .top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                    BackgroundView(width: geometry.size.width,
                                   height: geometry.size.height,
                                   pitch: CGFloat(model.pitch),
                                   roll: CGFloat(model.roll),
                                   outer: true)
                        .animation(.linear, value: model.pitch + model.roll)
                        .mask(Circle().strokeBorder(style: StrokeStyle.init(lineWidth: Constants.maskBoder, lineCap: .round, lineJoin: .round)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .shadow(color: Color(.sRGBLinear, white: 1, opacity: 0.7), radius: 5)
                }
                .overlay(align, alignment: .bottomTrailing)
                .padding()
                .compositingGroup()
            }
        }
        .background(Color.skyGradient)
    }
}


struct AttitudeIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        AttitudeIndicatorView(model: AHServiceViewModel())
    }
}
