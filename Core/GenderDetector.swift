//
//  GenderDetector.swift
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

import UIKit
import Vision
    import TensorFlowLite

class GenderPrediction {
    var faceCount: Int = 0
    var hasMale: Bool = false
    var hasFemale: Bool = false
    var maleConfidence: Float = 0.0
    var femaleConfidence: Float = 0.0
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
            interpreter = try Interpreter(modelPath: Bundle.main.path(forResource: "gender", ofType: "tflite") ?? "")
            try interpreter?.allocateTensors()
            print("GenderDetector model has been loaded")
        } catch {
            print("GenderDetector failed to create interpreter with error: \(error.localizedDescription)")
        }
        super.init()
    }
    
    func predict(image: UIImage, data: Data, completion: @escaping (GenderPrediction) -> Void) {
        let requestHandler = VNImageRequestHandler(data: data, options: [:])
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { [self] (request, _) in
            guard let observations = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async {
                    completion(GenderPrediction())
                }
                return
            }
            
            let prediction = GenderPrediction()
            prediction.faceCount = observations.count
            
            for faceObservation in observations {
                guard let faceImage = self.cropToBBox(image: image, boundingBox: faceObservation.boundingBox) else { continue }
                
                let genderPredictions = self.getGenderPrediction(image: faceImage)
                
                let isMale = genderPredictions.0 > 0.5
                prediction.hasMale = prediction.hasMale || isMale
                prediction.maleConfidence = isMale ? genderPredictions.0 : 1 - genderPredictions.0
                prediction.femaleConfidence = 1 - prediction.maleConfidence

                if !isMale {
                    prediction.hasFemale = true
                    break
                }
                
            }
            
            DispatchQueue.main.async {
                completion(prediction)
            }
        }
        
        #if targetEnvironment(simulator)
                faceDetectionRequest.usesCPUOnly = true
        #endif
        
        do {
            try requestHandler.perform([faceDetectionRequest])
        } catch {
            print("GenderDetector Error in face detection: \(error)")
            DispatchQueue.main.async {
                completion(GenderPrediction())
            }
        }
    }
    
    private func getGenderPrediction(image: UIImage) -> (Float, Bool) {
        
        guard let thumbnailPixelBuffer = CVPixelBuffer.buffer(from: image)?.centerThumbnail(ofSize: inputImageSize) else {
            return (0, false)
        }
        
        do {
            let inputTensor = try interpreter?.input(at: 0)

            guard let rgbData = rgbDataFromBuffer(
                thumbnailPixelBuffer,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
                isModelQuantized: inputTensor?.dataType == .float16
            ) else {
                print("Failed to convert the image buffer to RGB data.")
                return (0, false)
            }

            try interpreter?.copy(rgbData, toInputAt: 0)

            try interpreter?.invoke()
            
            let outputTensor = try interpreter?.output(at: 0)
            let predictionArray = outputTensor?.data.toArray(type: Float32.self) ?? []
            
            return (predictionArray[0], false)
        } catch {
            print("GenderDetector Failed to invoke interpreter with error: \(error.localizedDescription)")
            return (0, false)
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
