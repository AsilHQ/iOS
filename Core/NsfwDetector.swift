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
        super.init()
    }

    private func createInterpreter() -> Interpreter? {
        do {
            let interpreter = try Interpreter(modelPath: Bundle.main.path(forResource: "nsfw", ofType: "tflite") ?? "")
            try interpreter.allocateTensors()
            return interpreter
        } catch {
            print("[NsfwDetector] Failed to create interpreter with error: \(error.localizedDescription)")
            return nil
        }
    }

    func isNsfw(image: UIImage) -> NsfwPrediction? {
        var result: NsfwPrediction?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                semaphore.signal()
                return 
            }
            autoreleasepool {
                // Create pixel buffer and ensure it's cleaned up
                guard let pixelBuffer = CVPixelBuffer.buffer(from: image) else {
                    print("[NsfwDetector] nsfw error creating pixel buffer")
                    semaphore.signal()
                    return
                }
                
                // Create thumbnail and ensure it's cleaned up
                guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: self.inputImageSize) else {
                    print("[NsfwDetector] nsfw error on thumbnailPixelBuffer")
                    semaphore.signal()
                    return
                }
                
                // Create a new interpreter for this prediction
                guard let interpreter = self.createInterpreter() else {
                    semaphore.signal()
                    return
                }
                
                do {
                    let inputTensor = try interpreter.input(at: 0)
                    
                    // Create a temporary buffer for RGB data
                    let rgbData = self.rgbDataFromBuffer(
                        thumbnailPixelBuffer,
                        byteCount: self.batchSize * self.inputWidth * self.inputHeight * self.inputChannels,
                        isModelQuantized: inputTensor.dataType == .float16
                    )
                    
                    guard let rgbData = rgbData else {
                        print("[NsfwDetector] nsfw Failed to convert the image buffer to RGB data.")
                        semaphore.signal()
                        return
                    }
                    
                    // Copy data and run inference
                    try interpreter.copy(rgbData, toInputAt: 0)
                    try interpreter.invoke()
                    
                    // Get output tensor and create prediction
                    let outputTensor = try interpreter.output(at: 0)
                    let predictions = outputTensor.data.toArray(type: Float32.self)
                    result = NsfwPrediction(predictions: predictions)
                    
                    // Force cleanup of temporary objects
                    _ = predictions
                    _ = rgbData
                    _ = outputTensor
                    _ = inputTensor
                } catch {
                    print("[NsfwDetector] nsfw Failed to invoke interpreter with error: \(error.localizedDescription)")
                }
                
                // Force cleanup of pixel buffers
                _ = thumbnailPixelBuffer
                _ = pixelBuffer
                semaphore.signal()
            }
        }
        semaphore.wait()
        return result
    }
}
