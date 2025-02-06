//
//  NsfwDetector.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import UIKit
import TensorFlowLite

class NsfwDetector: TensorflowDetector {
    
    private var interpreter: Interpreter?
    let batchSize = 1
    let inputChannels = 3
    let inputWidth = 224
    let inputHeight = 224
    private let inputImageSize = CGSize(width: 224, height: 224)
    
    override init() {
        do {
            interpreter = try Interpreter(modelPath: Bundle.main.path(forResource: "nsfw", ofType: "tflite") ?? "")
            try interpreter?.allocateTensors()
            print("[NsfwDetector] model has been loaded")
        } catch {
            print("[NsfwDetector] Failed to create interpreter with error: \(error.localizedDescription)")
        }
        super.init()
    }

    func isNsfw(image: UIImage) -> NsfwPrediction? {
        guard let thumbnailPixelBuffer = CVPixelBuffer.buffer(from: image)?.centerThumbnail(ofSize: inputImageSize) else {
            print("[NsfwDetector] nsfw error on thumbnailPixelBuffer")
            return nil
        }
        
        do {
            let inputTensor = try interpreter?.input(at: 0)

            guard let rgbData = rgbDataFromBuffer(
                thumbnailPixelBuffer,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
                isModelQuantized: inputTensor?.dataType == .float16
            ) else {
                print("[NsfwDetector] nsfw Failed to convert the image buffer to RGB data.")
                return nil
            }

            try interpreter?.copy(rgbData, toInputAt: 0)

            try interpreter?.invoke()
            
            let outputTensor = try interpreter?.output(at: 0)
            let prediction = NsfwPrediction(predictions: outputTensor?.data.toArray(type: Float32.self) ?? [])
            return prediction
        } catch {
            print("[NsfwDetector] nsfw Failed to invoke interpreter with error: \(error.localizedDescription)")
            return nil
        }
    }
}
