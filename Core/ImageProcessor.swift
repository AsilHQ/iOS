//
//  ImageProcessor.swift
//  Kahf Browser
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Vision

class ImageProcessor {
    
    let nsfwDetector = NsfwDetector()
    let genderDetector = GenderDetector()
    var movenet: PoseEstimator?
    let queue = DispatchQueue(label: "serial_queue")
    
    init() {
        queue.async {
            do {
                self.movenet = try MoveNet(threadCount: 4, delegate: .gpu, modelType: .movenetMultipose)
            } catch {
                // Print the error directly
                print("[SafegazeScript] Cannot initialize movenet: \(error)")
            }
        }
    }
    
    func processImage(image: UIImage, imageData: Data, imageUrl: String, completion: @escaping (Bool, [Person]) -> Void) {
        debugPrint("[SafegazeScript] processImage Starting processImage for \(imageUrl)")
        
        runFaceAndPoseDetectionInParallel(image: image) { faceRects, poseList in
            debugPrint("[SafegazeScript] processImage Detected \(faceRects.count) faces and \(poseList.count) poses for \(imageUrl)")
            
            var personList = self.matchFacesToPoses(personList: poseList, faceRects: faceRects, imageWidth: image.size.width, imageHeight: image.size.height)
            
            let dispatchGroup = DispatchGroup()
            
            for i in personList.indices {
                dispatchGroup.enter()
                
                var person = personList[i]
                
                if let faceBox = person.faceBox {
                    
                    self.genderDetector.predict(image: image, boundingBox: faceBox.rect) { prediction in
                        defer {
                            debugPrint("[SafegazeScript] processImage DispatchGroup leave for person \(i) in \(imageUrl)")
                            dispatchGroup.leave()
                        }
                        
                        if prediction.faceCount > 0 {
                            person.isFemale = !prediction.isMale
                            person.genderScore = prediction.genderScore
                            person.faceBox = person.faceBoxPixel
                            debugPrint("[SafegazeScript] processImage Gender prediction completed for person \(i) in \(imageUrl). GenderScore: \(prediction.genderScore) isFemale: \(person.isFemale)")
                            personList[i] = person
                        } else {
                            debugPrint("[SafegazeScript] processImage No faces detected in gender prediction for person \(i) in \(imageUrl)")
                        }
                    }
                } else {
                    debugPrint("[SafegazeScript] processImage No faceBox for person \(i) in \(imageUrl)")
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                debugPrint("[SafegazeScript] processImage DispatchGroup notify triggered for \(imageUrl)")
                
                let containsFemale = personList.contains { $0.isFemale }
                debugPrint("[SafegazeScript] processImage Process completed for \(imageUrl). Contains female: \(containsFemale) Person Count: \(personList.count)")
                completion(containsFemale, personList)
            }
        }
    }
    
    func runFaceAndPoseDetectionInParallel(image: UIImage, completion: @escaping ([CGRect], [Person]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var faceRects: [CGRect] = []
        var poseList: [Person] = []
        
        dispatchGroup.enter()
        detectFaces(image: image) { rects in
            faceRects = rects
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        detectBodyPoses(image: image) { poses in
            poseList = poses
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(faceRects, poseList)
        }
    }
    
    func detectFaces(image: UIImage, completion: @escaping ([CGRect]) -> Void) {
        let request = VNDetectFaceRectanglesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
                let rects = request.results?.compactMap { $0 }.map { $0.boundingBox } ?? []
                completion(rects)
            } catch {
                debugPrint("Error detecting faces: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    func detectBodyPoses(image: UIImage, completion: @escaping ([Person]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pixelBuffer = CVPixelBuffer.buffer(from: image) else {
                debugPrint("[SafegazeScript] Error: Could not convert image to pixel buffer.")
                completion([])
                return
            }

            guard let movenet = self.movenet else {
                debugPrint("[SafegazeScript] Movenet is nil")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            do {
                // Run your TensorFlow Lite inference
                let persons = try movenet.estimateMultiplePoses(on: pixelBuffer)

                // Return the detected poses
                DispatchQueue.main.async {
                    completion(persons)
                }
            } catch {
                debugPrint("[SafegazeScript] TensorFlow Lite inference error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    func cropToBBox(image: UIImage, boundingBox: CGRect) -> UIImage? {
        let size = CGSize(width: boundingBox.width * image.size.width, height: boundingBox.height * image.size.height)
        let origin = CGPoint(x: boundingBox.origin.x * image.size.width, y: (1 - boundingBox.origin.y - boundingBox.height) * image.size.height)
        let cropRect = CGRect(origin: origin, size: size).integral
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Match faces to poses using bounding box proximity.
    func matchFacesToPoses(personList: [Person], faceRects: [CGRect], imageWidth: CGFloat, imageHeight: CGFloat) -> [Person] {
        var updatedPersons = personList

        for i in updatedPersons.indices { // Use indices for mutable access
            guard let poseBox = updatedPersons[i].poseBox else { continue }

            var bestMatch: CGRect?
            var bestScore: CGFloat = -1

            // Calculate pose center in pixel coordinates
            let poseCenter = CGPoint(
                x: poseBox.midX,
                y: poseBox.midY
            )

            for faceRect in faceRects {
                debugPrint("FaceRects detected: \(faceRect)")

                // Calculate face center in pixel coordinates
                let faceCenter = CGPoint(
                    x: faceRect.midX,
                    y: faceRect.midY
                )

                // Compute the distance between the pose center and face center
                let distance = getDistance(point1: poseCenter, point2: faceCenter)
                let maxAllowedDistance = max(poseBox.width, poseBox.height)

                // Match face to pose if within the allowed distance
                if distance <= maxAllowedDistance {
                    let score = 1 - (distance / maxAllowedDistance)
                    if score > bestScore {
                        bestScore = score
                        bestMatch = faceRect
                    }
                }
            }

            if let bestMatch = bestMatch {
                updatedPersons[i].faceBox = RectF(
                    left: bestMatch.origin.x,
                    top: bestMatch.origin.y,
                    right: bestMatch.origin.x + bestMatch.width,
                    bottom: bestMatch.origin.y + bestMatch.height
                )
                updatedPersons[i].faceBoxPixel = RectF(
                    left: bestMatch.origin.x * imageWidth,
                    top: (1 - bestMatch.origin.y - bestMatch.height) * imageHeight,
                    right: (bestMatch.origin.x + bestMatch.width) * imageWidth,
                    bottom: (1 - bestMatch.origin.y) * imageHeight
                )
            } else {
                debugPrint("[SafegazeScript] matchFacesToPoses: No bestMatch found for person \(i)")
                updatedPersons[i].faceBox = nil
            }
        }

        return updatedPersons
    }
    
    /// Calculate distance between two points.
    private func getDistance(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}
