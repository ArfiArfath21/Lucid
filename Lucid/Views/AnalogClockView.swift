//
//  AnalogClockView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import SwiftUI

struct AnalogClockView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clock Face
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 10)
                
                // Hour Markers
                ForEach(0..<12) { hour in
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: hour % 3 == 0 ? 4 : 2, height: hour % 3 == 0 ? 15 : 10)
                        .offset(y: -(min(geometry.size.width, geometry.size.height) / 2 - 25))
                        .rotationEffect(.degrees(Double(hour) * 30))
                }
                
                // Minute Markers
                ForEach(0..<60) { minute in
                    if minute % 5 != 0 {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 1, height: 5)
                            .offset(y: -(min(geometry.size.width, geometry.size.height) / 2 - 25))
                            .rotationEffect(.degrees(Double(minute) * 6))
                    }
                }
                
                // Hour Hand
                ClockHand(length: min(geometry.size.width, geometry.size.height) * 0.3,
                          width: 6,
                          color: .black,
                          angle: getHourHandAngle())
                
                // Minute Hand
                ClockHand(length: min(geometry.size.width, geometry.size.height) * 0.4,
                          width: 4,
                          color: .black,
                          angle: getMinuteHandAngle())
                
                // Second Hand
                ClockHand(length: min(geometry.size.width, geometry.size.height) * 0.4,
                          width: 2,
                          color: .red,
                          angle: getSecondHandAngle())
                
                // Center Circle
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
            }
            .padding(20)
        }
        .aspectRatio(1, contentMode: .fit)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func getHourHandAngle() -> Angle {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: currentTime))
        let minute = Double(calendar.component(.minute, from: currentTime))
        
        // Each hour is 30 degrees (360 / 12), plus a fraction based on minutes
        let hourAngle = hour * 30 + minute * 0.5
        
        return .degrees(hourAngle)
    }
    
    private func getMinuteHandAngle() -> Angle {
        let calendar = Calendar.current
        let minute = Double(calendar.component(.minute, from: currentTime))
        let second = Double(calendar.component(.second, from: currentTime))
        
        // Each minute is 6 degrees (360 / 60), plus a fraction based on seconds
        let minuteAngle = minute * 6 + second * 0.1
        
        return .degrees(minuteAngle)
    }
    
    private func getSecondHandAngle() -> Angle {
        let calendar = Calendar.current
        let second = Double(calendar.component(.second, from: currentTime))
        
        // Each second is 6 degrees (360 / 60)
        let secondAngle = second * 6
        
        return .degrees(secondAngle)
    }
}

struct ClockHand: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let angle: Angle
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(angle)
    }
}

struct AnalogClockView_Previews: PreviewProvider {
    static var previews: some View {
        AnalogClockView()
            .frame(width: 300, height: 300)
            .previewLayout(.sizeThatFits)
    }
}
