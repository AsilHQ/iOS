//
//  AutocompleteView.swift
//  Kahf Browser
//
//  Copyright © 2024 Kahf Browser. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SwiftUI

struct SliderView: View {
    @Binding var value: Float
    @State var lastCoordinateValue: CGFloat = 0.0
    var sliderRange: ClosedRange<CGFloat> = 0...1
    var thumbColor: Color = .yellow
    var minTrackColor: Color = Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1)
    var maxTrackColor: Color = Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255, opacity: 1)
    
    var body: some View {
        GeometryReader { gr in
            let thumbWidth = 10.258
            let radius = gr.size.height * 0.5
            let minValue = 0.0
            let maxValue = (gr.size.width * 0.95) - thumbWidth
            
            let scaleFactor = Double(maxValue - minValue) / Double(sliderRange.upperBound - sliderRange.lowerBound)
            let lower = sliderRange.lowerBound
            let sliderVal = (Double(self.value) - lower) * scaleFactor + minValue
            
            ZStack {
                Color.clear
                Rectangle()
                    .foregroundColor(maxTrackColor)
                    .frame(width: gr.size.width, height: 5)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                HStack {
                    Rectangle()
                        .foregroundColor(minTrackColor)
                        .frame(width: max(0, sliderVal), height: 5)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
                
                HStack {
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 10.258, height: 10.258)
                            .background(.white)
                            .cornerRadius(10.258 / 2)
                    }
                    .frame(width: 18, height: 18)
                    .background(Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1))
                    .cornerRadius(23 / 2)
                    .offset(x: sliderVal)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if abs(v.translation.width) < 0.1 {
                                    self.lastCoordinateValue = sliderVal
                                }
                                if v.translation.width > 0 {
                                    let nextCoordinateValue = min(maxValue, self.lastCoordinateValue + v.translation.width)
                                    self.value = Float(((nextCoordinateValue - minValue) / scaleFactor)  + lower)
                                } else {
                                    let nextCoordinateValue = max(minValue, self.lastCoordinateValue + v.translation.width)
                                    self.value = Float(((nextCoordinateValue - minValue) / scaleFactor) + lower)
                                }
                            }
                    )
                    Spacer()
                }
            }.frame(height: 18)
        }
    }
}
