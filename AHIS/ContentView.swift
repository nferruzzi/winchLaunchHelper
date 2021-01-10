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
        static let blueI = Color(red: 0.47, green: 0.66, blue: 0.82)
        static let blueO = Color(red: 0.04, green: 0.35, blue: 0.53)
        static let brownI = Color(red: 0.36, green: 0.27, blue: 0.24)
        static let brownO = Color(red: 0.13, green: 0.10, blue: 0.11)
        static let skyGradient = Gradient(colors: [blueO, blueI])
        static let skyGradientI = Gradient(colors: [blueI, blueO])
        static let earthGradient = Gradient(colors: [brownO, brownI])
        static let earthGradientO = Gradient(colors: [brownI, brownO])
        static let fov: CGFloat = 120
    }

    struct SkyShape: Shape {
        let size: CGFloat
        var horizont: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: horizont))
                path.addLine(to: CGPoint(x: 0, y: horizont))
            }
        }
        
        var animatableData: CGFloat {
            get { horizont }
            set { horizont = newValue }
        }
    }
    
    struct EarthShape: Shape {
        let size: CGFloat
        var horizont: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: horizont))
                path.addLine(to: CGPoint(x: size, y: horizont))
                path.addLine(to: CGPoint(x: size, y: size))
                path.addLine(to: CGPoint(x: 0, y: size))
            }
        }
        
        var animatableData: CGFloat {
            get { horizont }
            set { horizont = newValue }
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
                .fill(LinearGradient(gradient: Constants.skyGradient, startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)

            EarthShape(size: size, horizont: outer ? pitchToPixel(0) : pitchToPixel(pitch))
                .fill(LinearGradient(gradient: Constants.earthGradient, startPoint: .bottom, endPoint: .top))
                .frame(width: size, height: size)

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
        .rotationEffect(Angle(degrees: Double(yaw)), anchor: .center)
        .drawingGroup()
    }
    
    let width: CGFloat
    let height: CGFloat
    let pitch: CGFloat
    let roll: CGFloat
    let yaw: CGFloat
    let outer: Bool
    
    var degreeToPixel: CGFloat {
        size / Constants.fov
    }

    func pitchToPixel(_ pitch: CGFloat) -> CGFloat {
        size / 2.0 + pitch * degreeToPixel
    }

    var size: CGFloat {
        min(width, height)
    }

    var body: some View {
        background
    }
}

extension Double {
    var degree: Double {
        (self * 180.0) / Double.pi
    }
}

struct AttitudeIndicatorView: View {
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
                GeometryReader { geometry in
                    BackgroundView2(width: geometry.size.width,
                                    height: geometry.size.height,
                                    pitch: sim ? pitch : CGFloat(model.pitch),
                                    roll: CGFloat(model.roll),
                                    yaw: sim ? yaw : CGFloat(model.yaw),
                                    outer: false)
                        .animation(.linear)
                        .mask(Circle())
                        .overlay(plane.shadow(radius: 5), alignment: .center)
                        .overlay(virata.shadow(radius: 5), alignment: .top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                    BackgroundView2(width: geometry.size.width,
                                    height: geometry.size.height,
                                    pitch: sim ? pitch : CGFloat(model.pitch),
                                    roll: CGFloat(model.roll),
                                    yaw: sim ? yaw : CGFloat(model.yaw),
                                    outer: true)
                        .animation(.linear)
                        .mask(Circle().strokeBorder(style: StrokeStyle.init(lineWidth: 40, lineCap: .round, lineJoin: .round)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .shadow(color: Color(.sRGBLinear, white: 1, opacity: 0.7), radius: 5)
                }
                .overlay(Button("Align") {
                    model.reset()
                }, alignment: .bottomTrailing)
                .padding()
            }
            if false && sim {
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
}


struct ContentView: View {
    @StateObject var model = AHServiceViewModel()
    let sim: Bool
    
    var body: some View {
        VStack {
            AttitudeIndicatorView(sim: sim, model: model)
            HeadingIndicatorView(sim: sim, model: model)
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(sim: true)
            .preferredColorScheme(.dark)
        ContentView(sim: true)
            .preferredColorScheme(.light)
        ContentView(sim: true)
            .previewDevice("iPhone 8")
            .preferredColorScheme(.light)
        ContentView(sim: true)
            .previewDevice("iPad Pro (12.9-inch) (4th generation)")
            .preferredColorScheme(.light)
    }
}
