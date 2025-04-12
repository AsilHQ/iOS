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
    
//    private var interpreter: Interpreter?
    let batchSize = 1
    let inputChannels = 3
    let inputWidth = 224
    let inputHeight = 224
    private let inputImageSize = CGSize(width: 224, height: 224)
    
    lazy var interpreter: Interpreter? = {
        guard let modelPath = Bundle.main.path(forResource: "nsfw", ofType: "tflite") else { return nil }
        do {
            return try Interpreter(modelPath: modelPath)
        } catch {
            print("Failed to create interpreter: \(error)")
            return nil
        }
    }()
    
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
        guard let interpreter = self.interpreter,
              let inputData = image.normalizedRGBData() else { return nil }

        do {
            try interpreter.allocateTensors()
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            
            let outputTensor = try interpreter.output(at: 0)
            let output = [Float](unsafeData: outputTensor.data) ?? []
            return NsfwPrediction(predictions: output)
        } catch {
            print("Model failed: \(error)")
            return nil
        }
    }

//    func isNsfw(image: UIImage) -> NsfwPrediction? {
//        var result: NsfwPrediction?
//        let semaphore = DispatchSemaphore(value: 0)
//        
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            guard let self = self else { 
//                semaphore.signal()
//                return 
//            }
//            autoreleasepool {
//                // Create pixel buffer and ensure it's cleaned up
//                guard let pixelBuffer = CVPixelBuffer.buffer(from: image) else {
//                    print("[NsfwDetector] nsfw error creating pixel buffer")
//                    semaphore.signal()
//                    return
//                }
//                
//                // Create thumbnail and ensure it's cleaned up
//                guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: self.inputImageSize) else {
//                    print("[NsfwDetector] nsfw error on thumbnailPixelBuffer")
//                    semaphore.signal()
//                    return
//                }
//                
//                // Create a new interpreter for this prediction
//                guard let interpreter = self.createInterpreter() else {
//                    semaphore.signal()
//                    return
//                }
//                
//                do {
//                    let inputTensor = try interpreter.input(at: 0)
//                    
//                    // Create a temporary buffer for RGB data
//                    let rgbData = self.rgbDataFromBuffer(
//                        thumbnailPixelBuffer,
//                        byteCount: self.batchSize * self.inputWidth * self.inputHeight * self.inputChannels,
//                        isModelQuantized: inputTensor.dataType == .float16
//                    )
//                    
//                    guard let rgbData = rgbData else {
//                        print("[NsfwDetector] nsfw Failed to convert the image buffer to RGB data.")
//                        semaphore.signal()
//                        return
//                    }
//                    
//                    // Copy data and run inference
//                    try interpreter.copy(rgbData, toInputAt: 0)
//                    try interpreter.invoke()
//                    
//                    // Get output tensor and create prediction
//                    let outputTensor = try interpreter.output(at: 0)
//                    let predictions = outputTensor.data.toArray(type: Float32.self)
//                    result = NsfwPrediction(predictions: predictions)
//                    
//                    // Force cleanup of temporary objects
//                    _ = predictions
//                    _ = rgbData
//                    _ = outputTensor
//                    _ = inputTensor
//                } catch {
//                    print("[NsfwDetector] nsfw Failed to invoke interpreter with error: \(error.localizedDescription)")
//                }
//                
//                // Force cleanup of pixel buffers
//                _ = thumbnailPixelBuffer
//                _ = pixelBuffer
//                semaphore.signal()
//            }
//        }
//        semaphore.wait()
//        return result
//    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        defer { UIGraphicsEndImageContext() }

        self.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func resizedCG(to targetSize: CGSize) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        let bitsPerComponent = 8
        let bytesPerRow = 4 * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let scaledImage = context.makeImage() else { return nil }
        return UIImage(cgImage: scaledImage)
    }

    /// Normalize image pixel data to RGB float array [0, 1]
    func normalizedRGBData() -> Data? {
        guard let resized = self.resizedCG(to: CGSize(width: 224, height: 224)),
              let cgImage = resized.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var floatArray = [Float](repeating: 0, count: width * height * 3)
        for i in 0..<width * height {
            let pixelIndex = i * bytesPerPixel
            let r = Float(pixelData[pixelIndex]) / 255.0
            let g = Float(pixelData[pixelIndex + 1]) / 255.0
            let b = Float(pixelData[pixelIndex + 2]) / 255.0
            floatArray[i * 3] = r
            floatArray[i * 3 + 1] = g
            floatArray[i * 3 + 2] = b
        }

        return Data(buffer: UnsafeBufferPointer(start: &floatArray, count: floatArray.count))
    }
}
