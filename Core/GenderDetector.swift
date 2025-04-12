//
//  GenderDetector.swift
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
import Vision
import TensorFlowLite

class GenderPrediction {
    let isMale: Bool
    let genderScore: Float
    
    init(isMale: Bool, genderScore: Float) {
        self.isMale = isMale
        self.genderScore = genderScore
    }
}

class GenderDetector: TensorflowDetector {
    private let inputSize = CGSize(width: 224, height: 224)
    private let processingQueue = DispatchQueue(label: "com.kahf.genderDetection", qos: .userInitiated)
    private var interpreter: Interpreter?
    
    override init() {
        super.init()
        setupInterpreter()
    }
    
    private func setupInterpreter() {
        processingQueue.async {
            do {
                guard let modelPath = Bundle.main.path(forResource: "mobilenet_v2_gender", ofType: "tflite") else {
                    debugPrint("GenderDetector model file not found")
                    return
                }
                
                self.interpreter = try Interpreter(modelPath: modelPath)
                try self.interpreter?.allocateTensors()
                debugPrint("GenderDetector model loaded successfully")
            } catch {
                debugPrint("GenderDetector initialization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func predict(image: UIImage, boundingBox: CGRect, completion: @escaping (GenderPrediction) -> Void) {
        processingQueue.async {
            autoreleasepool {
                // Convert bounding box to image coordinates
                let originalRect = CGRect(
                    x: boundingBox.minX * image.size.width,
                    y: boundingBox.minY * image.size.height,
                    width: boundingBox.width * image.size.width,
                    height: boundingBox.height * image.size.height
                )
                
                // Crop and resize face image
                guard let faceImage = self.prepareFaceImage(image: image, rect: originalRect) else {
                    debugPrint("Failed to prepare face image")
                    return
                }
                
                // Get gender prediction
                let score = self.getGenderPrediction(image: faceImage)
                let isMale = score > 0.5
                let genderScore = isMale ? score : 1 - score
                
                let prediction = GenderPrediction(isMale: isMale, genderScore: genderScore)
                
                DispatchQueue.main.async {
                    completion(prediction)
                }
            }
        }
    }
    
    private func prepareFaceImage(image: UIImage, rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return nil
        }
        
        let faceImage = UIImage(cgImage: cgImage)
        
        // Resize to model input size
        UIGraphicsBeginImageContextWithOptions(inputSize, false, 1.0)
        faceImage.draw(in: CGRect(origin: .zero, size: inputSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func getGenderPrediction(image: UIImage) -> Float {
        guard let interpreter = interpreter,
              let pixelBuffer = CVPixelBuffer.buffer(from: image),
              let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: inputSize) else {
            return -1
        }
        
        do {
            let inputTensor = try interpreter.input(at: 0)
            
            // Validate tensor shape
            guard inputTensor.shape.dimensions == [1, Int(inputSize.height), Int(inputSize.width), 3] else {
                return -1
            }
            
            // Convert to RGB data
            guard let rgbData = rgbDataFromBuffer(
                thumbnailPixelBuffer,
                byteCount: Int(inputSize.width) * Int(inputSize.height) * 3,
                isModelQuantized: inputTensor.dataType == .uInt8
            ) else {
                return -1
            }
            
            // Run inference
            try interpreter.copy(rgbData, toInputAt: 0)
            try interpreter.invoke()
            
            // Get results
            let outputTensor = try interpreter.output(at: 0)
            let maxConfidence = outputTensor.data.toArray(type: Float32.self).max()
            
            return maxConfidence ?? -1
        } catch {
            debugPrint("Gender prediction failed: \(error.localizedDescription)")
            return -1
        }
    }
}
