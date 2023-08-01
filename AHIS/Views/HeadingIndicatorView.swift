//
//  HeadingIndicatorView.swift
//  AHIS
//
//  Created by nferruzzi on 09/01/21.
//

import SwiftUI


private extension Double {
    /// The conversion formula found online expects the module operator to work like the python one for negative numbers
    /// AKA: mod = a - math.floor(a/b) * base
    func pythonMod(by val: Double) -> Double {
        self - floor(self / val) * val
    }
}


struct HeadingIndicatorPath: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for angle in stride(from: 0, to: 360, by: 10) {
                let angle = CGFloat(180 - angle)
                let piAngle = (2 * CGFloat.pi * angle) / 360
                let x = sin(piAngle) * rect.width/2.0
                let y = -cos(piAngle) * rect.height/2.0
                
                let rotate = CGAffineTransform(rotationAngle: piAngle)
                let translate = CGAffineTransform(translationX: x + rect.width/2.0, y: y + rect.height/2.0)
                
                path.addRect(CGRect(x: -4/2, y: 0, width: 4, height: 35), transform: rotate.concatenating(translate))
            }
            
            for angle in stride(from: 5, to: 360, by: 10) {
                let angle = CGFloat(180 - angle)
                let piAngle = (2 * CGFloat.pi * angle) / 360
                let x = sin(piAngle) * rect.width/2.0
                let y = -cos(piAngle) * rect.height/2.0
                
                let rotate = CGAffineTransform(rotationAngle: piAngle)
                let translate = CGAffineTransform(translationX: x + rect.width/2.0, y: y + rect.height/2.0)
                
                path.addRect(CGRect(x: -2, y: 0, width: 4, height: 20), transform: rotate.concatenating(translate))
            }

        }
    }
}

struct HeadingIndicatorInnerView: View {
    enum Constants {
        static let textFont = Font.system(size: 55, weight: .bold, design: .default)
        static let angleFont = Font.system(size: 30, weight: .bold, design: .default)
    }
    
    let size: CGFloat
    let angle: Double

    func pin<Content: View>(_ angle: CGFloat, _ content: @autoclosure () -> Content) -> some View {
        let angle = 180 - angle
        let piAngle = (2 * CGFloat.pi * angle) / 360
        
        return content()
            .rotationEffect(.degrees(Double(-angle)))
            .offset(x: sin(piAngle) * size/2.0, y: cos(piAngle) * size/2.0)
    }
    
    
    var n: some View {
        pin(0, Text("N").font(Constants.textFont).rotationEffect(.degrees(180)).offset(x: 0, y: -60))
    }

    var e: some View {
        pin(90, Text("E").font(Constants.textFont).rotationEffect(.degrees(180)).offset(x: 0, y: -60))
    }

    var s: some View {
        pin(180, Text("S").font(Constants.textFont).rotationEffect(.degrees(180)).offset(x: 0, y: -60))
    }

    var w: some View {
        pin(270, Text("W").font(Constants.textFont).rotationEffect(.degrees(180)).offset(x: 0, y: -60))
    }
    
    func angleText(_ angle: CGFloat) -> some View {
        pin(angle,
            Text("\(Int(angle/10))").font(Constants.angleFont).rotationEffect(.degrees(180)).offset(x: 0, y: -60))
    }

    var body: some View {
        ZStack {
            Circle()
                .frame(width: size, height: size, alignment: .center)
                .foregroundColor(.black)

            HeadingIndicatorPath().foregroundColor(.white)
                .overlay(n)
                .overlay(s)
                .overlay(w)
                .overlay(e)
                .overlay(angleText(30))
                .overlay(angleText(60))
                .overlay(angleText(120))
                .overlay(angleText(150))
                .overlay(angleText(210))
                .overlay(angleText(240))
                .overlay(angleText(210))
                .overlay(angleText(300))
                .overlay(angleText(330))
//                .rotation3DEffect(
//                    .degrees(-angle),
//                    axis: (x: 0.0, y: 0.0, z: 1.0)
//                    )
                .rotationEffect(.degrees(-angle))

            Circle()
                .stroke(Color.gray, style: StrokeStyle.init(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size, alignment: .center)
                .shadow(color: Color(.sRGBLinear, white: 1, opacity: 0.7), radius: 5)
        }
    }
}

struct HeadingIndicatorView: View {
    @State var heading: Double = 0
    @ObservedObject var model: AHServiceViewModel
    
    var anglePassed: Double {
        model.heading //.pythonMod(by: 360) - 360
    }

    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geometry in
                    HeadingIndicatorInnerView(size: min(geometry.size.width, geometry.size.height), angle: anglePassed)
                        .animation(.linear)
                }
                Image("Airplane")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(60)
                    .offset(x: 0, y: -40)
                    .shadow(color: Color(.sRGBLinear, white: 1, opacity: 0.8), radius: 5)
            }
            .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fit)
        }
        .padding()
    }
}

struct HeadingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        HeadingIndicatorView(model: AHServiceViewModel())
            .preferredColorScheme(.dark)
    }
}
