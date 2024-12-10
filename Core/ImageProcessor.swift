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
    
    func processImage(image: UIImage, imageData: Data, imageUrl: String, completion: @escaping (Bool, [Person]) -> Void) {
        runFaceAndPoseDetectionInParallel(image: image) { faceRects, poseList in
            // Match detected poses to face rectangles
            let personList = self.matchFacesToPoses(personList: poseList, faceRects: faceRects)
            
            for person in personList {
                if let faceBox = person.faceBox {
                    if let faceImage = self.cropToBBox(image: image, boundingBox: faceBox) {
                        // Perform gender detection
                        self.genderDetector.predict(image: faceImage, data: imageData) { prediction in
                            if prediction.faceCount > 0 {
                                person.isFemale = !prediction.hasMale
                                person.genderScore = prediction.femaleConfidence
                                debugPrint("[SafegazeScript] Gender Prediction: \(prediction.femaleConfidence) isFemale \(person.isFemale) for Person ID: \(person.id)")
                            }
                        }
                    }
                } else {
                    debugPrint("[SafegazeScript] no facebox check \(imageUrl)")
                }
            }
            
            let containsFemale = personList.contains { $0.isFemale }
            completion(containsFemale, personList)
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
        let request = VNDetectHumanBodyPoseRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
                
                guard let observations = request.results  else {
                    debugPrint("[SafegazeScript] There is no observation")
                    completion([])
                    return
                }
                
                let poses = self.parsePoses(from: observations, imageSize: image.size)

                completion(poses)
            } catch {
                debugPrint("[SafegazeScript] Error detecting body poses: \(error.localizedDescription)")
                completion([])
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
    func matchFacesToPoses(personList: [Person], faceRects: [CGRect]) -> [Person] {
        var updatedPersons = personList
        
        for i in updatedPersons.indices { // Use indices for mutable access
            guard let poseBox = updatedPersons[i].poseBox else { continue }
            
            var bestMatch: CGRect?
            var bestScore: CGFloat = -1
            
            let poseCenter = CGPoint(
                x: poseBox.midX,
                y: poseBox.midY
            )
            
            for faceRect in faceRects {
                let faceCenter = CGPoint(
                    x: faceRect.midX,
                    y: faceRect.midY
                )
                
                let distance = getDistance(point1: poseCenter, point2: faceCenter)
                let maxAllowedDistance = max(poseBox.width, poseBox.height)
                
                if distance <= maxAllowedDistance {
                    let score = 1 - (distance / maxAllowedDistance)
                    if score > bestScore {
                        bestScore = score
                        bestMatch = faceRect
                    }
                }
            }
            
            // Assign the best match to the person
            updatedPersons[i].faceBox = bestMatch
        }
        
        return updatedPersons
    }
    
    /// Calculate distance between two points.
    private func getDistance(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func parsePoses(from observations: [VNHumanBodyPoseObservation], imageSize: CGSize) -> [Person] {
        var persons: [Person] = []

        for (id, observation) in observations.enumerated() {
            do {
                let recognizedPoints = try observation.recognizedPoints(.all)
                var keyPoints: [KeyPoint] = []
                var totalScore: Float = 0

                // Calculate bounding box for the pose
                var minX: CGFloat = CGFloat.greatestFiniteMagnitude
                var minY: CGFloat = CGFloat.greatestFiniteMagnitude
                var maxX: CGFloat = -CGFloat.greatestFiniteMagnitude
                var maxY: CGFloat = -CGFloat.greatestFiniteMagnitude

                // Iterate through recognized points
                for (bodyPart, point) in recognizedPoints {
                    if point.confidence > 0.1 { // Filter low-confidence points
                        let coordinate = CGPoint(
                            x: point.location.x * imageSize.width,
                            y: (1 - point.location.y) * imageSize.height // Adjust Y-axis
                        )

                        // Update bounding box
                        minX = min(minX, coordinate.x)
                        minY = min(minY, coordinate.y)
                        maxX = max(maxX, coordinate.x)
                        maxY = max(maxY, coordinate.y)

                        // Create keypoint
                        let keyPoint = KeyPoint(bodyPart: bodyPart, coordinate: coordinate, score: point.confidence)
                        keyPoints.append(keyPoint)
                        totalScore += point.confidence
                    }
                }

                // Skip if no keypoints detected
                guard !keyPoints.isEmpty else { continue }

                // Calculate average score and create bounding box
                let averageScore = totalScore / Float(keyPoints.count)
                let poseBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

                // Create Person object
                let person = Person(id: id, keyPoints: keyPoints, score: averageScore, faceBox: nil, poseBox: poseBox)
                persons.append(person)
            } catch {
                debugPrint("[SafegazeScript] Error processing pose observation: \(error.localizedDescription)")
            }
        }

        return persons
    }
}
