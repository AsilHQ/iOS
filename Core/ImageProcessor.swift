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
import MediaPipeTasksVision

class ImageProcessor {
    
    let nsfwDetector = NsfwDetector()
    let genderDetector = GenderDetector()
    var movenet: PoseEstimator?
    let queue = DispatchQueue(label: "serial_queue")
    var totalFacesCount: Int = 0
    var totalPoseCount: Int = 0
    
    private var faceDetector: FaceDetector?
    private var poseLandmarker: PoseLandmarker?
    
    init() {
        queue.async {
            do {
                self.movenet = try MoveNet(threadCount: 4, delegate: .gpu, modelType: .movenetMultipose)
            } catch {
                // Print the error directly
                debugPrint("[SafegazeScript] Cannot initialize movenet: \(error)")
            }
        }
        
       
        configureFaceDetection()
        configurePoseLandmarker()
    }
    
    private func configureFaceDetection() {
        do {
            guard let modelPath = Bundle.main.path(forResource: "blaze_face_short_range", ofType: "tflite") else {
                print("Model file not found")
                return
            }
            
            let options = FaceDetectorOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .image
            
            faceDetector = try FaceDetector(options: options)
        } catch {
            print("Error initializing FaceDetector: \(error)")
        }
    }
    
    private func configurePoseLandmarker() {
        do {
            // Load the pose landmark model
            guard let modelPath = Bundle.main.path(
                forResource: "pose_landmarker_full",
                ofType: "task"
            ) else {
                debugPrint("could not find pose_landmarker_full model")
                return
            }

            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .image
            options.numPoses = 10         // Detect up to 5 poses in the image
//            options.minPoseDetectionConfidence = 0.5 // Adjust the confidence threshold as needed
//            options.minPosePresenceConfidence = 0.5
//            options.minTrackingConfidence = 0.5

            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            print("Failed to initialize PoseLandmarker: \(error.localizedDescription)")
        }
    }
    
    func processImage(image: UIImage, imageData: Data, imageUrl: String, completion: @escaping (Bool, [Person]) -> Void) {
        debugPrint("[SafegazeScript] processImage Starting processImage for \(imageUrl)")
        
        runFaceAndPoseDetectionInParallel(image: image) { faceRects, poseList in
            
            var personList = self.matchFacesToPoses(
                personList: poseList,
                faceRects: faceRects,
                imageWidth: image.size.width,
                imageHeight: image.size.height
            )
            
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
        detectFaces(in: image) { rects in
            faceRects = rects
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        detectPoses(from: image) { persons in
            poseList = persons
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            debugPrint("faceRects total count is:\(faceRects.count)")
            completion(faceRects, poseList)
        }
    }
        
    func detectFaces(in image: UIImage, completion: @escaping ([CGRect]) -> Void) {
        guard let faceDetector = faceDetector else {
            print("Face detector is not initialized")
            return completion([])
        }

        do {
            let mpImage = try MPImage(uiImage: image)
            let result = try faceDetector.detect(image: mpImage)
            
            let faceRect = result.detections.map { detection in
                let boundingBox = detection.boundingBox
                
                return CGRect(
                    x: boundingBox.origin.x / image.size.width, // Normalize X
                    y: boundingBox.origin.y / image.size.height, // Normalize Y
                    width: boundingBox.width / image.size.width, // Normalize Width
                    height: boundingBox.height / image.size.height // Normalize Height
                )
            }
           
            completion(faceRect)
        } catch {
            print("Error detecting faces: \(error)")
            return completion([])
        }
    }
        
    private func detectPoses(from image: UIImage, completion: @escaping ([Person]) -> Void) {
        guard let poseLandmarker = poseLandmarker else {
            print("PoseLandmarker is not configured.")
            completion([])
            return
        }

        guard let mpImage = try? MPImage(uiImage: image) else {
            print("Failed to convert UIImage to MPImage.")
            completion([])
            return
        }

        do {
            let result = try poseLandmarker.detect(image: mpImage)
            let imageSize = CGSize(width: image.size.width, height: image.size.height) // Replace with actual image size
            let persons = createPersonsFromLandmarks(result: result, imageSize: imageSize)

            if persons.isEmpty {
                debugPrint("No persons detected.")
                completion([])
            } else {
                completion(persons)
            }
        } catch {
            completion([])
            print("Pose detection failed: \(error.localizedDescription)")
        }
    }
        
    private func createPersonsFromLandmarks(result: PoseLandmarkerResult, imageSize: CGSize) -> [Person] {
        var persons: [Person] = []

        // Correct mapping of BodyPart to MediaPipe landmark index
        let bodyPartToLandmarkIndex: [BodyPart: Int] = [
            .nose: 0,
            .leftEye: 2, .rightEye: 5,
            .leftEar: 7, .rightEar: 8,
            .leftShoulder: 11, .rightShoulder: 12,
            .leftElbow: 13, .rightElbow: 14,
            .leftWrist: 15, .rightWrist: 16,
            .leftHip: 23, .rightHip: 24,
            .leftKnee: 25, .rightKnee: 26,
            .leftAnkle: 27, .rightAnkle: 28
        ]

        for landmarks in result.landmarks {
            var keyPoints: [KeyPoint] = []
            var totalScore: Float32 = 0.0

            var minX: CGFloat = .greatestFiniteMagnitude
            var minY: CGFloat = .greatestFiniteMagnitude
            var maxX: CGFloat = .leastNormalMagnitude
            var maxY: CGFloat = .leastNormalMagnitude

            for (bodyPart, index) in bodyPartToLandmarkIndex {
                guard index < landmarks.count else { continue }
                let landmark = landmarks[index]

                let visibility = (landmark.visibility as? Float32) ?? 0.0
                guard visibility > 0.05 else { continue } // Skip low-confidence points

                // Convert normalized coordinates to absolute pixel values
                let absoluteX = CGFloat(landmark.x) * imageSize.width
                let absoluteY = CGFloat(landmark.y) * imageSize.height

                // Update bounding box values
                minX = min(minX, absoluteX)
                minY = min(minY, absoluteY)
                maxX = max(maxX, absoluteX)
                maxY = max(maxY, absoluteY)

                keyPoints.append(KeyPoint(bodyPart: bodyPart, coordinate: CGPoint(x: absoluteX, y: absoluteY), score: visibility))
                totalScore += visibility
            }

            guard !keyPoints.isEmpty else { continue } // Skip if no valid keypoints

            let averageScore = totalScore / Float32(keyPoints.count)

            // Expand bounding box slightly to ensure full-body coverage
            let paddingX = (maxX - minX) * 0.1
            let paddingY = (maxY - minY) * 0.1

            let poseBox = RectF(
                left: max(0, minX - paddingX),
                top: max(0, minY - paddingY),
                right: min(imageSize.width, maxX + paddingX),
                bottom: min(imageSize.height, maxY + paddingY)
            )

            persons.append(Person(keyPoints: keyPoints, score: averageScore, id: -1, poseBox: poseBox))
        }

        return persons
    }

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

                // Convert normalized faceRect to pixel coordinates
                let faceRectPixel = CGRect(
                    x: faceRect.origin.x * imageWidth,
                    y: faceRect.origin.y * imageHeight,
                    width: faceRect.width * imageWidth,
                    height: faceRect.height * imageHeight
                )

                // Calculate face center in pixel coordinates
                let faceCenter = CGPoint(
                    x: faceRectPixel.midX,
                    y: faceRectPixel.midY
                )

                // Compute the distance between the pose center and face center
                let distance = getDistancehypot(point1: poseCenter, point2: faceCenter)
                let maxAllowedDistance = max(poseBox.width, poseBox.height)

                // Match face to pose if within the allowed distance
                if distance <= maxAllowedDistance {
                    let score = 1 - (distance / maxAllowedDistance)
                    if score > bestScore {
                        bestScore = score
                        bestMatch = faceRectPixel
                    }
                }
            }

            if let bestMatch = bestMatch {
                // Assign faceBox in normalized coordinates
                updatedPersons[i].faceBox = RectF(
                    left: bestMatch.origin.x / imageWidth,
                    top: bestMatch.origin.y / imageHeight,
                    right: (bestMatch.origin.x + bestMatch.width) / imageWidth,
                    bottom: (bestMatch.origin.y + bestMatch.height) / imageHeight
                )

                // Assign faceBoxPixel in pixel coordinates
                updatedPersons[i].faceBoxPixel = RectF(
                    left: bestMatch.origin.x,
                    top: bestMatch.origin.y,
                    right: bestMatch.origin.x + bestMatch.width,
                    bottom: bestMatch.origin.y + bestMatch.height
                )
            } else {
                debugPrint("[SafegazeScript] matchFacesToPoses: No bestMatch found for person \(i)")
                updatedPersons[i].faceBox = nil
                updatedPersons[i].faceBoxPixel = nil
            }
        }

        return updatedPersons
    }

    // Helper function to calculate Euclidean distance between two points
    func getDistancehypot(point1: CGPoint, point2: CGPoint) -> CGFloat {
        return hypot(point1.x - point2.x, point1.y - point2.y)
    }
}
