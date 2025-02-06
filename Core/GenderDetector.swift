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
    var faceCount: Int = 0
    var isMale: Bool = false
    var genderScore: Float = 0.0
}

class GenderDetector: TensorflowDetector {
    private let inputImageSize = CGSize(width: 224, height: 224)
    private var interpreter: Interpreter?

    let batchSize = 1
    let inputChannels = 3
    let inputWidth = 224
    let inputHeight = 224
    
    override init() {
        do {
            interpreter = try Interpreter(modelPath: Bundle.main.path(forResource: "mobilenet_v2_gender", ofType: "tflite") ?? "")
            try interpreter?.allocateTensors()
            print("GenderDetector model has been loaded")
        } catch {
            print("GenderDetector failed to create interpreter with error: \(error.localizedDescription)")
        }
        super.init()
    }
    
    func predict(image: UIImage, boundingBox: CGRect, completion: @escaping (GenderPrediction) -> Void) {
        debugPrint("enter into gender prediction")

        let prediction = GenderPrediction()
        prediction.faceCount = 1
                        
        let originalRect = CGRect(x: boundingBox.minX * image.size.width,
                                  y: boundingBox.minY * image.size.height,
                                  width: boundingBox.width * image.size.width,
                                  height: boundingBox.height * image.size.height)
        
        guard let cgImage = image.cgImage?.cropping(to: originalRect) else {
            debugPrint("converting to cgImage failed")
               return
           }
        
        let faceImage = UIImage(cgImage: cgImage)
        
        let score = self.getGenderPrediction(image: faceImage)
        debugPrint("gender score is:\(score)")
        prediction.isMale = score > 0.5 //genderPredictions > 0.5
        prediction.genderScore = (score > 0.5) ? score : 1 - score //prediction.isMale ? genderPredictions : 1 - genderPredictions
        
        DispatchQueue.main.async {
            completion(prediction)
        }
    }
    
    private func getGenderPrediction(image: UIImage) -> Float {
        // Step 1: Update input dimensions based on the model's actual requirements
        let inputImageSize = CGSize(width: 224, height: 224) // Update to match model's input shape
        let inputWidth = Int(inputImageSize.width)
        let inputHeight = Int(inputImageSize.height)

        // Step 2: Convert UIImage to CVPixelBuffer
        guard let pixelBuffer = CVPixelBuffer.buffer(from: image) else {
            debugPrint("Failed to convert UIImage to CVPixelBuffer.")
            return -1
        }
        
        // Step 3: Create a centered thumbnail of the required size
        guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: inputImageSize) else {
            debugPrint("Could not create a centered thumbnail from the pixel buffer.")
            return -1
        }
        
        // Step 4: Prepare the RGB data for the model
        do {
            let inputTensor = try interpreter?.input(at: 0)
            
            // Validate input tensor properties
            guard let tensor = inputTensor else {
                debugPrint("Interpreter input tensor is nil.")
                return -1
            }
            
            // Ensure the tensor shape matches the model's input
            guard tensor.shape.dimensions == [batchSize, inputHeight, inputWidth, inputChannels] else {
                debugPrint("Mismatch between input tensor shape and model requirements. Tensor shape: \(tensor.shape.dimensions)")
                return -1
            }
            
            // Convert the thumbnail to the RGB data the model expects
            guard let rgbData = rgbDataFromBuffer(
                thumbnailPixelBuffer,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
                isModelQuantized: tensor.dataType == .uInt8
            ) else {
                debugPrint("Failed to convert the pixel buffer to RGB data.")
                return -1
            }
            
            // Step 5: Feed the RGB data into the model
            try interpreter?.copy(rgbData, toInputAt: 0)
            try interpreter?.invoke()
            
            // Step 6: Retrieve the output tensor and process results
            guard let outputTensor = try interpreter?.output(at: 0) else {
                debugPrint("Interpreter output tensor is nil.")
                return -1
            }
            
            let predictionArray = outputTensor.data.toArray(type: Float32.self)
            debugPrint("Prediction Array: \(predictionArray)")
            
            // Find the index of the highest confidence value
            guard let maxIndex = predictionArray.firstIndex(of: predictionArray.max() ?? 0.0) else {
                debugPrint("Failed to find the index of the maximum confidence value.")
                return -1
            }
            
            debugPrint("maxIndex is:\(maxIndex)")
            
            // Map index to gender
            // Assume index 0 = Male, index 1 = Female
            let confidence = predictionArray[maxIndex]
            
            return (confidence)
        } catch {
            debugPrint("GenderDetector failed with error: \(error.localizedDescription)")
            return -1
        }
    }

    
    private func cropToBBox(image: UIImage, boundingBox: CGRect) -> UIImage? {
        let size = CGSize(width: boundingBox.width * image.size.width, height: boundingBox.height * image.size.height)
        let origin = CGPoint(x: boundingBox.origin.x * image.size.width, y: (1 - boundingBox.origin.y - boundingBox.height) * image.size.height)
        let cropRect = CGRect(origin: origin, size: size).integral
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
