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


struct BackgroundView2: View {
    enum Constants {
        static let aspectRatio: CGFloat = 0.3
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
    }

    struct SkyShape: Shape {
        var pitch: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: Constants.width, y: 0))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.height / 2.0 + pitch * Constants.height / 360))
                path.addLine(to: CGPoint(x: 0, y: Constants.height / 2.0 + pitch * Constants.height / 360))
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
                path.move(to: CGPoint(x: 0, y: Constants.height / 2.0 + pitch * Constants.height / 360))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.height / 2.0 + pitch * Constants.height / 360))
                path.addLine(to: CGPoint(x: Constants.width, y: Constants.height))
                path.addLine(to: CGPoint(x: 0, y: Constants.height))
            }
        }
        
        var animatableData: CGFloat {
            get { pitch }
            set { pitch = newValue }
        }
    }

        
    var background: some View {
        ZStack {
            SkyShape(pitch: pitch)
            .fill(LinearGradient(gradient: Constants.skyGradient, startPoint: .top, endPoint: .bottom))

            EarthShape(pitch: pitch)
            .fill(LinearGradient(gradient: Constants.earthGradient, startPoint: .bottom, endPoint: .top))
            
//            Text("10").offset(x: 0, y: (pitch + 10) * Constants.height / 360)
//            Text("20").offset(x: 0, y: (pitch + 20) * Constants.height / 360)
//            Text("10").offset(x: 0, y: (pitch - 10) * Constants.height / 360)
//            Text("20").offset(x: 0, y: (pitch - 20) * Constants.height / 360)
            Rectangle()
                .frame(width: 100, height: 1)
                .offset(x: 0, y: (pitch + 20) * Constants.height / 360)

        }
        .font(.system(size: 100)).foregroundColor(.white)
        .frame(width: Constants.width, height: Constants.height)
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

extension Double {
    var degree: Double {
        (self * 180.0) / Double.pi
    }
}

struct ContentView: View {
    @StateObject var model = AHServiceViewModel()
        
    @State var pitch: CGFloat = 0
    @State var yaw: CGFloat = 0

    var plane: some View {
        Path { path in
            path.move(to: CGPoint(x: 50, y: 0))
            path.addLine(to: CGPoint(x: 100, y: 10))
            path.addLine(to: CGPoint(x: 0, y: 10))
        }.foregroundColor(.yellow)
        .frame(width: 100, height: 10, alignment: .center)
    }
    
    @ViewBuilder
    var body: some View {
        VStack {
            ZStack {
                BackgroundView2(pitch: CGFloat(pitch), roll: CGFloat(model.roll), yaw: CGFloat(yaw))
                    .animation(.linear)
//                    .mask(Circle())
                    .overlay(plane, alignment: .center)
                        
//                Rectangle()
//                    .frame(width: 100, height: 10).foregroundColor(.yellow)
            }
            VStack {
//                Text("Roll \(model.roll)")
                Text("Pitch \(pitch)")
                Text("Yaw \(yaw)")
                Button("Reset") {
                    model.reset()
                }
                Slider(value:$pitch, in: -180...180, label: { Text("Pitch") })
                    .frame(width: 200)
                Slider(value:$yaw, in: -180...180, label: { Text("Yaw") })
                    .frame(width: 200)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
