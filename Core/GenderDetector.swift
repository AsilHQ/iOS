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
        
        let prediction = GenderPrediction()
        prediction.faceCount = 1
        
        guard let faceImage = self.cropToBBox(image: image, boundingBox: boundingBox) else { return }
        
        saveImageToAppDirectory(image: faceImage, fileName: UUID().uuidString + ".png")
        
        let genderPredictions = self.getGenderPrediction(image: faceImage).0
        prediction.isMale = genderPredictions > 0.5
        prediction.genderScore = prediction.isMale ? genderPredictions : 1 - genderPredictions
        
        DispatchQueue.main.async {
            completion(prediction)
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

extension GenderDetector {
    func saveImageToAppDirectory(image: UIImage, directory: String? = nil, fileName: String) -> Bool {
        guard let imageData = image.pngData() else {
            debugPrint("[ImageProcessor] Failed to convert UIImage to PNG data.")
            return false
        }
        
        // Access the app's documents directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create the full path for the directory (if specified)
        var savePath = documentsDirectory
        if let directory = directory {
            savePath = savePath.appendingPathComponent(directory)
            
            // Ensure the directory exists
            if !fileManager.fileExists(atPath: savePath.path) {
                do {
                    try fileManager.createDirectory(at: savePath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    debugPrint("[ImageProcessor] Failed to create directory '\(directory)': \(error)")
                    return false
                }
            }
        }
        
        // Sanitize the file name
        let sanitizedFileName = sanitizeFileName(fileName)
        let filePath = savePath.appendingPathComponent(sanitizedFileName)
        
        // Save the image data
        do {
            try imageData.write(to: filePath)
            debugPrint("[ImageProcessor] Image saved successfully at: \(filePath.path)")
            return true
        } catch {
            debugPrint("[ImageProcessor] Failed to save image: \(error)")
            return false
        }
    }
    
    /// Sanitize a file name by removing invalid characters.
    /// - Parameter fileName: The original file name.
    /// - Returns: A sanitized file name safe for the file system.
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/?<>\\|*\"")
        return fileName
            .components(separatedBy: invalidCharacters)
            .joined()
    }
}
