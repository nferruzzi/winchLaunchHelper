//
//  ContentView.swift
//  AHIS
//
//  Created by nferruzzi on 07/01/21.
//

import SwiftUI

struct BackgroundView: View {
    enum Constants {
        static let aspectRatio: CGFloat = 1
        static let height: CGFloat = 1024 * aspectRatio
        static let width: CGFloat = 1024 * aspectRatio
    }
    
    var background: some View {
        Image("Texture")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Constants.width, height: Constants.height, alignment: .center)
            .transformEffect(.init(translationX: 0, y: pitch * (Constants.height / 360)))
            .rotationEffect(Angle(degrees: Double(yaw)), anchor: .center)
            .drawingGroup()
    }
    
    let pitch: CGFloat
    let roll: CGFloat
    let yaw: CGFloat

    var body: some View {
        background
    }
}


struct TriangleShape: Shape {
    let offset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.size.width/2.0, y: 0))
            path.addLine(to: CGPoint(x: rect.size.width, y: rect.size.height - offset))
            path.addLine(to: CGPoint(x: 0, y: rect.size.height - offset))
        }
    }
}


struct BackgroundView2: View {
    enum Constants {
        static let aspectRatio: CGFloat = 0.4
        static let height: CGFloat = 1024 * aspectRatio
        static let width: CGFloat = 1024 * aspectRatio
        static let blueI = Color(red: 0.47, green: 0.66, blue: 0.82)
        static let blueO = Color(red: 0.04, green: 0.35, blue: 0.53)
        static let brownI = Color(red: 0.36, green: 0.27, blue: 0.24)
        static let brownO = Color(red: 0.13, green: 0.10, blue: 0.11)
        static let skyGradient = Gradient(colors: [blueO, blueI])
        static let skyGradientI = Gradient(colors: [blueI, blueO])
        static let earthGradient = Gradient(colors: [brownO, brownI])
        static let earthGradientO = Gradient(colors: [brownI, brownO])
        static let fov: CGFloat = 90
        static let degreeToPixel = height / fov
        static func pitchToPixel(_ pitch: CGFloat) -> CGFloat {
            height / 2.0 + pitch * degreeToPixel
        }
    }

    struct SkyShape: Shape {
        var pitch: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: Constants.width, y: 0))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.pitchToPixel(pitch)))
                path.addLine(to: CGPoint(x: 0, y: Constants.pitchToPixel(pitch)))
            }
        }
        
        var animatableData: CGFloat {
            get { pitch }
            set { pitch = newValue }
        }
    }
    
    struct EarthShape: Shape {
        var pitch: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: Constants.pitchToPixel(pitch)))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.pitchToPixel(pitch)))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.height))
                path.addLine(to: CGPoint(x: 0, y: Constants.height))
            }
        }
        
        var animatableData: CGFloat {
            get { pitch }
            set { pitch = newValue }
        }
    }
    


    func line(_ offset: CGFloat, _ value: String, _ width: CGFloat) -> some View {
        HStack {
            Text(value)
            Rectangle()
                .frame(width: width, height: 1)
            Text(value)
        }
        .font(.system(size: 10))
        .foregroundColor(.white)
        .offset(x: 0, y: ((outer ? 0 : pitch) + offset) * Constants.degreeToPixel)
    }
    
    func pin<Content: View>(_ angle: CGFloat, _ content: @autoclosure () -> Content) -> some View {
        let angle = 180 - angle
        let piAngle = (2 * CGFloat.pi * angle) / 360
        
        return content()
            .rotationEffect(.degrees(Double(-angle)), anchor: UnitPoint(x: 0.5, y: 0.8))
            .offset(x: sin(piAngle) * Constants.width/2.0, y: cos(piAngle) * Constants.height/2.0)
    }
        
    var background: some View {
        ZStack {
            SkyShape(pitch: outer ? 0.0 : pitch)
            .fill(LinearGradient(gradient: Constants.skyGradient, startPoint: .top, endPoint: .bottom))

            EarthShape(pitch: outer ? 0.0 : pitch)
            .fill(LinearGradient(gradient: Constants.earthGradient, startPoint: .bottom, endPoint: .top))
            
            if !outer {
                line(20, "20", 100)
                line(15, "", 50)
                line(10, "10", 75)
                line(5, "", 50)
                line(-20, "20", 100)
                line(-15, "", 50)
                line(-10, "10", 75)
                line(-5, "", 50)
            }
        }
        .frame(width: Constants.width, height: Constants.height)
        .overlay(line(0, "", Constants.width).foregroundColor(.white))
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
        .rotationEffect(Angle(degrees: Double(yaw)), anchor: .center)
        .drawingGroup()
    }
    
    let pitch: CGFloat
    let roll: CGFloat
    let yaw: CGFloat
    let outer: Bool

    var body: some View {
        background
    }
}

extension Double {
    var degree: Double {
        (self * 180.0) / Double.pi
    }
}

struct ContentView: View {
    let sim: Bool
    
    @StateObject var model = AHServiceViewModel()
    @State var pitch: CGFloat = 0
    @State var yaw: CGFloat = 0

    var plane: some View {
        Path { path in
            path.move(to: CGPoint(x: 45, y: 0))
            path.addLine(to: CGPoint(x: 90, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 20))
        }.foregroundColor(.yellow)
        .frame(width: 90, height: 1, alignment: .center)
    }
    
    var virata: some View {
        TriangleShape(offset: 0)
        .foregroundColor(.yellow)
        .frame(width: 30, height: 14, alignment: .top)
        .offset(x: 0, y: 42)
    }
    
    struct Ring: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
            }
        }
    }
    
    @ViewBuilder
    var body: some View {
        VStack {
            ZStack {
                BackgroundView2(pitch: sim ? pitch : CGFloat(model.pitch),
                                roll: CGFloat(model.roll),
                                yaw: sim ? yaw : CGFloat(model.yaw),
                                outer: false)
                    .animation(.linear)
                    .mask(Circle())
                    .overlay(plane.shadow(radius: 5), alignment: .center)
                    .overlay(virata.shadow(radius: 5), alignment: .top)
                
                BackgroundView2(pitch: sim ? pitch : CGFloat(model.pitch),
                                roll: CGFloat(model.roll),
                                yaw: sim ? yaw : CGFloat(model.yaw),
                                outer: true)
                    .animation(.linear)
                    .mask(Circle().strokeBorder(style: StrokeStyle.init(lineWidth: 40, lineCap: .round, lineJoin: .round)))
                    .shadow(color: Color(.sRGBLinear, white: 1, opacity: 0.7), radius: 5)

            }
            VStack {
//                Text("Roll \(model.roll)")
                Text("Pitch \(sim ? Int(pitch) : model.pitch)")
                Text("Yaw \(sim ? Int(yaw) : model.yaw)")
                Button("Reset") {
                    model.reset()
                }
                if sim {
                    Slider(value:$pitch, in: -180...180, label: { Text("Pitch") })
                        .frame(width: 200)
                    Slider(value:$yaw, in: -180...180, label: { Text("Yaw") })
                        .frame(width: 200)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(sim: true)
    }
}
