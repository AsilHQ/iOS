// Copyright 2023 The Kahf Browser Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

const onProcessImageMap = new Map();

class SkinDetector {
    constructor(options = {}) {
        this.options = {
            minSkinRatio: 0.5,
            rgbRanges: {
                r: {
                    min: 95,
                    max: 255
                },
                g: {
                    min: 40,
                    max: 220
                },
                b: {
                    min: 20,
                    max: 200
                }
            },
            lowerBodyMinSkinRatio: 0.20, // Lower threshold for lower body only
            ...options
        };
    }

    isSkinPixel(r, g, b) {
        const {
            rgbRanges
        } = this.options;

        if (r < rgbRanges.r.min || r > rgbRanges.r.max ||
            g < rgbRanges.g.min || g > rgbRanges.g.max ||
            b < rgbRanges.b.min || b > rgbRanges.b.max) {
            return false;
        }

        if (r < g || r < b) return false;
        const rgDiff = Math.abs(r - g);
        if (rgDiff < 15) return false;
        if (r > 220 && g > 210 && b > 170) return false;
        if (r < 100 && g < 100 && b < 100) return false;

        return true;
    }

    analyzeSkeleton(originalImageData, skeletonMask, analysisRegion = 'full') {
        const {
            width,
            height,
            data
        } = originalImageData;
        const maskData = skeletonMask.data;

        const visualizationCanvas = document.createElement('canvas');
        visualizationCanvas.width = width;
        visualizationCanvas.height = height;
        const visCtx = visualizationCanvas.getContext('2d');
        const visData = visCtx.createImageData(width, height);

        let skinPixels = 0;
        let totalPixels = 0;

        for (let i = 0; i < data.length; i += 4) {
            if (maskData[i] > 250 && maskData[i + 1] > 250 && maskData[i + 2] > 250) {
                totalPixels++;

                if (this.isSkinPixel(data[i], data[i + 1], data[i + 2])) {
                    skinPixels++;
                    visData.data[i] = 255; // R
                    visData.data[i + 1] = 0; // G
                    visData.data[i + 2] = 0; // B
                    visData.data[i + 3] = 100; // A
                } else { // color it in green
                    visData.data[i] = 0; // R
                    visData.data[i + 1] = 255; // G
                    visData.data[i + 2] = 0; // B
                    visData.data[i + 3] = 100; // A
                }
            }
        }

        visCtx.putImageData(visData, 0, 0);

        const skinRatio = totalPixels > 0 ? skinPixels / totalPixels : 0;
        // Use different threshold based on analysis region
        const minSkinRatio = analysisRegion === 'lowerBody' ?
            this.options.lowerBodyMinSkinRatio :
            this.options.minSkinRatio;

        return {
            visualization: visualizationCanvas,
            skinPixels,
            totalPixels,
            skinRatio,
            hasSkin: skinRatio >= minSkinRatio,
            analysisRegion
        };
    }
}

class SkeletonDrawer {
    constructor() {
        this.connections = [
            // Face
            ['nose', 'left_eye'],
            ['nose', 'right_eye'],
            ['left_eye', 'left_ear'],
            ['right_eye', 'right_ear'],
            ['left_eye', 'right_eye'],

            // Neck & Body connections
            ['nose', 'left_shoulder'],
            ['nose', 'right_shoulder'],
            ['left_ear', 'left_shoulder'],
            ['right_ear', 'right_shoulder'],
            ['left_shoulder', 'right_shoulder'],
            ['left_shoulder', 'left_elbow'],
            ['right_shoulder', 'right_elbow'],
            ['left_elbow', 'left_wrist'],
            ['right_elbow', 'right_wrist'],
            ['left_shoulder', 'left_hip'],
            ['right_shoulder', 'right_hip'],
            ['left_shoulder', 'right_hip'],
            ['right_shoulder', 'left_hip'],
            ['left_hip', 'right_hip'],
            ['left_hip', 'left_knee'],
            ['right_hip', 'right_knee'],
            ['left_knee', 'left_ankle'],
            ['right_knee', 'right_ankle'],
            ['left_knee', 'right_knee'],
            ['left_ankle', 'right_ankle']
        ];
    }
    // Calculate relative stroke width based on image dimensions
    calculateStrokeWidth(canvasWidth, canvasHeight, mode, gender = "female", keypoints = []) {
        // First get the pose bounds to determine its size relative to the image
        const validPoints = keypoints.filter(kp => kp.score);

        if (validPoints.length === 0) {
            // Fallback to old calculation if no valid points
            const smallerDimension = Math.min(canvasWidth, canvasHeight);
            return Math.max(2, Math.round(smallerDimension * (gender === "female" ? 0.32 : 0.25)));
        }

        // Calculate pose bounds
        const xs = validPoints.map(p => p.x);
        const ys = validPoints.map(p => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);

        // Calculate pose dimensions
        const poseWidth = maxX - minX;
        const poseHeight = maxY - minY;

        // Calculate pose size relative to image
        const widthRatio = poseWidth / canvasWidth;
        const heightRatio = poseHeight / canvasHeight;
        const poseSizeRatio = Math.max(widthRatio, heightRatio);

        // Use the smaller of image or pose dimension for base calculation
        const poseDimension = Math.min(poseWidth, poseHeight);
        const imageDimension = Math.min(canvasWidth, canvasHeight) / 1.2

        // Blend between pose-based and image-based scaling based on pose size
        const baseSize = poseDimension * (1 - poseSizeRatio) + imageDimension * poseSizeRatio;
        const multiplier = gender === "female" ? 0.32 : 0.27;

        switch (mode) {
            case 'standard':
                // Adjust base multiplier based on gender and pose size
                return Math.max(2, Math.round(baseSize * multiplier * poseSizeRatio));

            case 'debug':
                return 5;
            case 'detection':
                // Similarly adjust detection stroke width
                return Math.max(15, Math.round(baseSize * multiplier * poseSizeRatio));

            default:
                throw new Error(`Unknown drawing mode: ${mode}`);
        }
    }

    drawSkeleton(ctx, keypoints, mode = 'standard') {
        const config = {
            ...this.getConfig(mode, ctx.canvas.width, ctx.canvas.height),
            strokeWidth: this.calculateStrokeWidth(
                ctx.canvas.width,
                ctx.canvas.height,
                mode,
                'female', // Default to female for skeleton
                keypoints
            )
        };
        ctx.save();
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.lineWidth = config.strokeWidth;
        ctx.globalAlpha = config.alpha;

        // Apply blur filter directly
        // ctx.filter = 'blur(5px) grayscale(100%)';  // Adjust pixel value for blur intensity

        // Draw connections
        this.connections
            .filter(([start, end]) => {
                const faceConnections = [
                    ['left_eye', 'right_eye'],
                    ['left_eye', 'left_ear'],
                    ['right_eye', 'right_ear']
                ];
                return !faceConnections.some(([s, e]) =>
                    (start === s && end === e) || (start === e && end === s)
                );
            })
            .forEach(([startPoint, endPoint]) => {
                const start = keypoints.find(kp => kp.name === startPoint);
                const end = keypoints.find(kp => kp.name === endPoint);

                if (start && end &&
                    start.score >= POSE_DETECTOR_DEFAULTS.minPartScore &&
                    end.score >= POSE_DETECTOR_DEFAULTS.minPartScore) {
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.strokeStyle = config.color;
                    ctx.stroke();
                }
            });

        ctx.restore();
    }

    getConfig(mode, canvasWidth, canvasHeight) {
        const baseConfig = {
            standard: {
                color: '#9F9F9FFF',
                outlineColor: '#9F9F9FFF',
                alpha: 1
            },
            debug: {
                color: '#808080',
                alpha: 0.7
            },
            detection: {
                color: '#ADADAD',
                alpha: 1.0
            }
        } [mode];

        if (!baseConfig) {
            throw new Error(`Unknown drawing mode: ${mode}`);
        }

        return {
            ...baseConfig,
            strokeWidth: this.calculateStrokeWidth(canvasWidth, canvasHeight, mode)
        };
    }

    drawOvalFaceRegion(ctx, originalCanvas, faceRegion) {
        // Save the current context state
        ctx.save();

        // Create a clipping path in the shape of an oval
        ctx.beginPath();
        const centerX = faceRegion.x + faceRegion.width / 2;
        const centerY = faceRegion.y + faceRegion.height / 2;
        const radiusX = faceRegion.width / 2.2;
        const radiusY = faceRegion.height / 2.2;

        // Draw ellipse as clipping path
        ctx.ellipse(
            centerX, centerY,
            radiusX, radiusY,
            0, 0, 2 * Math.PI
        );

        // Create the clipping mask
        ctx.clip();

        // Draw the original image portion
        ctx.drawImage(
            originalCanvas,
            faceRegion.x, faceRegion.y, faceRegion.width, faceRegion.height,
            faceRegion.x, faceRegion.y, faceRegion.width, faceRegion.height
        );

        // Restore the context state
        ctx.restore();
    }

    getFaceRegion(keypoints) {
        // Get all face-related points
        const facePoints = ['nose', 'left_eye', 'right_eye', 'left_ear', 'right_ear']
            .map(name => keypoints.find(kp => kp.name === name))
            .filter(kp => kp?.score);

        if (facePoints.length < 2) return null;

        // Get shoulder points if they exist
        const leftShoulder = keypoints.find(kp => kp.name === 'left_shoulder' && kp.score);
        const rightShoulder = keypoints.find(kp => kp.name === 'right_shoulder' && kp.score);

        // Calculate base dimensions from face points
        const xs = facePoints.map(p => p.x);
        const ys = facePoints.map(p => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        const baseWidth = maxX - minX;
        const baseHeight = maxY - minY;

        // Get reference points for height calculation
        const leftEye = keypoints.find(kp => kp.name === 'left_eye' && kp.score);
        const rightEye = keypoints.find(kp => kp.name === 'right_eye' && kp.score);
        const nose = keypoints.find(kp => kp.name === 'nose' && kp.score);


        if (!rightEye && !leftEye) return null;
        if (!nose) return null;

        const heightBetweenEyeAndNose = Math.abs((rightEye || leftEye)?.y - nose?.y)


        // Calculate width constraints
        let maxWidth;
        if (leftShoulder && rightShoulder) {
            // Use shoulder width as constraint
            maxWidth = Math.abs(rightShoulder.x - leftShoulder.x);
        } else {
            // Use 2x face width as constraint
            maxWidth = baseWidth * 2;
        }

        // Calculate height constraints
        let maxHeight = heightBetweenEyeAndNose * 4;

        // Calculate padded dimensions (constrained by maxWidth/maxHeight)
        const desiredPaddedWidth = baseWidth * 1.2; // 20% padding
        const desiredPaddedHeight = baseHeight * 4; // 140% padding

        const finalWidth = Math.min(desiredPaddedWidth, maxWidth);
        const finalHeight = Math.min(desiredPaddedHeight, maxHeight);

        // Calculate padding to add (divided by 2 since we add to both sides)
        const widthPadding = (finalWidth - baseWidth) / 2;
        const heightPadding = (finalHeight - baseHeight) / 2;

        // Return padded region, ensuring we don't go below 0
        return {
            x: Math.max(0, minX - widthPadding),
            y: Math.max(0, minY - heightPadding * 0.5),
            width: finalWidth,
            height: finalHeight
        };
    }

    drawDetectionMask(ctx, keypoints, options = {}) {
        const {
            gender = 'unknown',
                faceRegion = null,
                mode = 'detection'
        } = options;

        ctx.save();
        ctx.strokeStyle = '#ADADAD';
        ctx.fillStyle = '#ADADAD';
        const calcLineWidth = this.calculateStrokeWidth(
            ctx.canvas.width,
            ctx.canvas.height,
            mode,
            gender,
            keypoints // Pass keypoints to calculate relative size
        );
        ctx.lineWidth = calcLineWidth;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';


        if (gender === 'male') {
            // For males: Draw only lower body connections
            const lowerBodyConnections = [
                ['left_hip', 'right_hip'],
                ['left_hip', 'left_knee'],
                ['right_hip', 'right_knee'],
                ['left_knee', 'right_knee']
            ];

            lowerBodyConnections.forEach(([startPoint, endPoint]) => {
                const start = keypoints.find(kp => kp.name === startPoint);
                const end = keypoints.find(kp => kp.name === endPoint);

                if (start && end &&
                    start.score >= POSE_DETECTOR_DEFAULTS.minPartScore &&
                    end.score >= POSE_DETECTOR_DEFAULTS.minPartScore) {
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.stroke();
                }
            });
        } else {
            // For females: Draw full body mask
            this.connections
                .filter(([start, end]) => {
                    const faceConnections = [
                        ['left_eye', 'right_eye'],
                        ['left_eye', 'left_ear'],
                        ['right_eye', 'right_ear']
                    ];
                    return !faceConnections.some(([s, e]) =>
                        (start === s && end === e) || (start === e && end === s)
                    );
                })
                .forEach(([startPoint, endPoint]) => {
                    const start = keypoints.find(kp => kp.name === startPoint);
                    const end = keypoints.find(kp => kp.name === endPoint);

                    if (start && end &&
                        start.score &&
                        end.score) {
                        ctx.beginPath();
                        ctx.moveTo(start.x, start.y);
                        ctx.lineTo(end.x, end.y);
                        ctx.stroke();
                    }
                });

            // draw line connecting nose to neck (estimated) to groin (estimated)
            const nose = keypoints.find(kp => kp.name === 'nose');
            const leftShoulder = keypoints.find(kp => kp.name === 'left_shoulder');
            const rightShoulder = keypoints.find(kp => kp.name === 'right_shoulder');
            const leftHip = keypoints.find(kp => kp.name === 'left_hip');
            const rightHip = keypoints.find(kp => kp.name === 'right_hip');

            if (nose && leftShoulder && rightShoulder) {
                const neckLeft = {
                    x: (nose.x + leftShoulder.x) / 2,
                    y: (nose.y + leftShoulder.y) / 2
                };
                const neckRight = {
                    x: (nose.x + rightShoulder.x) / 2,
                    y: (nose.y + rightShoulder.y) / 2
                };

                const neckMiddle = {
                    x: (neckLeft.x + neckRight.x) / 2,
                    y: (neckLeft.y + neckRight.y) / 2
                };

                ctx.lineWidth = calcLineWidth * 2;
                ctx.beginPath();
                ctx.moveTo(nose.x, nose.y);
                ctx.lineTo(neckLeft.x, neckLeft.y);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(nose.x, nose.y);
                ctx.lineTo(neckRight.x, neckRight.y);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(neckMiddle.x, neckMiddle.y);
                ctx.lineTo((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
                ctx.stroke();
            }

            if (leftShoulder && rightShoulder && leftHip && rightHip) {
                ctx.beginPath();
                ctx.moveTo((leftShoulder.x + rightShoulder.x) / 2, (leftShoulder.y + rightShoulder.y) / 2);
                ctx.lineTo((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
                ctx.stroke();
            }

            ctx.lineWidth = calcLineWidth * 1.5;

            // connect the eyes by a square
            const leftEye = keypoints.find(kp => kp.name === 'left_eye');
            const rightEye = keypoints.find(kp => kp.name === 'right_eye');
            let distance = Math.abs(leftEye.x - rightEye.x);
            if (leftEye && rightEye) {
                ctx.beginPath();
                ctx.moveTo(leftEye.x, leftEye.y);
                ctx.lineTo(leftEye.x, leftEye.y - distance);
                ctx.lineTo(rightEye.x, rightEye.y - distance);
                ctx.lineTo(rightEye.x, rightEye.y);
                ctx.closePath();
                ctx.stroke();
            }

            // same with ears
            const leftEar = keypoints.find(kp => kp.name === 'left_ear');
            const rightEar = keypoints.find(kp => kp.name === 'right_ear');
            if (leftEar && rightEar) {
                distance *= 1.5
                ctx.beginPath();
                ctx.moveTo(leftEar.x, leftEar.y);
                ctx.lineTo(leftEar.x, leftEar.y - distance);
                ctx.lineTo(rightEar.x, rightEar.y - distance);
                ctx.lineTo(rightEar.x, rightEar.y);
                ctx.closePath();
                ctx.stroke();
            }

            ctx.lineWidth = calcLineWidth;
        }



        ctx.restore();
    }

    drawFaceDebug(ctx, faceRegion, genderInfo, source = "face") {
        if (!faceRegion) return;

        ctx.save();

        // Draw rectangle around face
        ctx.strokeStyle = genderInfo.isFemale ? '#FF69B4' : '#4169E1'; // Pink for female, Blue for male
        ctx.lineWidth = 3;

        if (source == "face")
            ctx.setLineDash([5, 3]); // Create dashed line effect

        // Draw rectangle
        ctx.strokeRect(
            faceRegion.x,
            faceRegion.y,
            faceRegion.width,
            faceRegion.height
        );

        // Add gender label
        const labelText = `${genderInfo.isFemale ? 'Female' : 'Male'} (${(genderInfo.confidence * 100).toFixed(1)}%)`;

        // Set up text style
        ctx.font = 'bold 14px Arial';
        ctx.textBaseline = 'top';
        const textMetrics = ctx.measureText(labelText);
        const textPadding = 4;

        // Draw label background
        ctx.fillStyle = genderInfo.isFemale ? '#FF69B4' : '#4169E1';
        ctx.fillRect(
            faceRegion.x,
            faceRegion.y - 20, // Position above the face box
            textMetrics.width + (textPadding * 2),
            20
        );

        // Draw label text
        ctx.fillStyle = '#FFFFFF';
        ctx.fillText(
            labelText,
            faceRegion.x + textPadding,
            faceRegion.y - 18 // Slight offset from background top
        );

        ctx.restore();
    }
}


window.safegazeOnDeviceModelHandler = safegazeOnDeviceModelHandler;
window.updateBluredImageOpacity = updateBluredImageOpacity;

const POSE_DETECTOR_DEFAULTS = {
    minPartScore: 0.2
};

const skinDetector = new SkinDetector();
const skeletonDrawer = new SkeletonDrawer();



const createCanvas = (width, height) => {
    const canvas = document.createElement('canvas');
    canvas.crossOrigin = 'Anonymous';
    canvas.width = width;
    canvas.height = height;
    return canvas;
};

window.sendMessage = function(message) {
    console.log(message);
    try {
        SafeGazeInterface.sendMessage(message)
    } catch {}
}

async function safegazeOnDeviceModelHandler(uid, detectionResultStr, imgData) {

    const originalImg = onProcessImageMap.get(uid);
    if (!originalImg) return;

    try {
        if (!detectionResultStr || !imgData?.length) {
            unblurImage(originalImg);
            return;
        }
            
        const detectionResult = JSON.parse(detectionResultStr);
        if (!detectionResult) return;
        console.log("🚀 ~ safegazeOnDeviceModelHandler ~ detectionResult:", detectionResult)

        // 1. If the image is NSFW, blur it
        const isNsfw = detectionResult?.isNSFW;
        if (isNsfw) {
            if (originalImg) {
                blurImage(originalImg);
            }
            return;
        }

        unblurImage(originalImg);


        // Get exact dimensions from image
        const imgWidthKotlin = detectionResult.imageWidth;
        const imgHeightKotlin = detectionResult.imageHeight;


        let width, height, ratioX, ratioY;

        let newImg, originalCanvas = originalImg.ourCanvas, originalCtx = originalImg.ourContext;
        if (!originalCanvas || !originalCtx) { // we couldn't convert the image to base64 earlier
            width = originalImg.width;
            height = originalImg.height;
            ratioX = width / imgWidthKotlin;
            ratioY = height / imgHeightKotlin;

            newImg = new Image(width, height)
            newImg.crossOrigin = 'anonymous';
            try {
                await new Promise((resolve, reject) => {
                    newImg.onload = resolve;
                    newImg.onerror = reject;
                    newImg.src = `data:image/png;base64,${imgData}`;
                });
            } catch {
                await new Promise((resolve, reject) => {
                    newImg.onload = resolve;
                    newImg.onerror = reject;
                    newImg.src = originalImg.ourSrc;
                })
            }
            originalCanvas = createCanvas(width, height);
            originalCtx = originalCanvas.getContext('2d', {
                alpha: true,
                willReadFrequently: true
            });
            originalCtx.clearRect(0, 0, width, height);
            originalCtx.drawImage(newImg, 0, 0, width, height);
        } else {
            width = originalCanvas.width;
            height = originalCanvas.height;
            ratioX = width / imgWidthKotlin;
            ratioY = height / imgHeightKotlin;
        }

        // Setup canvases
        const canvas = createCanvas(width, height);
        const ctx = canvas.getContext('2d', {
            alpha: true,
            willReadFrequently: true
        });
        

        // Clear and draw original image
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(originalCanvas, 0, 0, width, height);

        let shouldBlur = false;
        let facesToRedraw = [];

        // 2. Loop over all the poses and draw the body masks.
        for (const [key, value] of Object.entries(detectionResult?.persons ?? {})) {
            let {
                faceBox,
                poseBox, // doesn't seem like this is needed
                isFemale,
                genderScore,
                keypoints,
                id,
                poseScore, // i'll sstil see if neeed
                faceScore // i'll still see if needed
            } = value;
            // if (poseScore < 0.2) return;

            const gender = isFemale ? "female" : "true"
            faceBox = faceBox && {
                xMin: faceBox.xMin * ratioX,
                yMin: faceBox.yMin * ratioY,
                width: faceBox.width * ratioX,
                height: faceBox.height * ratioY
            };
            keypoints = keypoints.map(kp => ({
                ...kp,
                x: kp.x * ratioX,
                y: kp.y * ratioY
            }));


            if (window.sgSettings?.debug) {
                skeletonDrawer.drawFaceDebug(ctx, {
                    x: faceBox.xMin,
                    y: faceBox.yMin,
                    width: faceBox.width,
                    height: faceBox.height,
                }, {
                    isFemale,
                    confidence: isFemale ? genderScore : 1 - genderScore
                });
            }

            // Create detection mask for skin analysis
            const maskCanvas = createCanvas(width, height);
            const maskCtx = maskCanvas.getContext('2d', {
                alpha: true,
                willReadFrequently: true
            });

            // Draw the detection mask
            skeletonDrawer.drawDetectionMask(maskCtx, keypoints, {
                gender: isFemale ? "female" : "male",
                faceRegion: isFemale ? faceBox : null,
                mode: 'detection'
            });

            // Analyze skin using the mask
            const imageData = ctx.getImageData(0, 0, width, height);
            const maskImageData = maskCtx.getImageData(0, 0, width, height);
            const analysis = isFemale ? null : skinDetector.analyzeSkeleton(
                imageData,
                maskImageData,
                isFemale ? 'full' : 'lowerBody'
            );

            // Debug visualization if enabled
            if (window.sgSettings?.debug) {
                ctx.fillStyle = '#800080';
                ctx.font = '16px Arial';
                const textY = 150;

                ctx.fillText(`Gender: ${gender}`, 10, textY - 25);
                if (analysis) {
                    ctx.fillText(`Analysis Region: ${analysis.analysisRegion}`, 10, textY);
                    ctx.fillText(`Skin Pixels: ${analysis.skinPixels}/${analysis.totalPixels}`, 10, textY + 50);
                    ctx.fillText(`Skin Ratio: ${(analysis.skinRatio * 100).toFixed(1)}%`, 10, textY + 75);
                    ctx.fillText(`Threshold: ${(isFemale ?
                    skinDetector.options.minSkinRatio :
                    skinDetector.options.lowerBodyMinSkinRatio) * 100}%`, 10, textY + 100);

                    if (analysis.visualization) {
                        ctx.drawImage(analysis.visualization, 0, 0);
                    }
                }
                skeletonDrawer.drawSkeleton(ctx, keypoints, "debug");
            }

            // If female or enough skin detected, apply gray mask
            if (isFemale || analysis?.hasSkin) {
                ctx.save();
                // ctx.globalAlpha = 0.7;

                skeletonDrawer.drawDetectionMask(ctx, keypoints, {
                    gender: isFemale ? "female" : "male",
                    faceRegion: isFemale ? faceBox : null,
                    mode: 'detection'
                });

                // Fill the masked area with gray
                ctx.globalCompositeOperation = 'source-atop';

                ctx.restore();

                shouldBlur = true;
            }

            facesToRedraw.push(faceBox);
        }

        // draw the faces
        if (shouldBlur) {
            // Redraw faces to avoid blurring them
            for (const faceBox of facesToRedraw) {
                skeletonDrawer.drawOvalFaceRegion(ctx, originalCanvas, {
                    x: faceBox.xMin,
                    y: faceBox.yMin,
                    width: faceBox.width,
                    height: faceBox.height
                });
            }
            const newSrcUrl = canvas.toDataURL('image/png', 1.0);
            setImageSrc(originalImg, newSrcUrl);
        }
    } catch (e) {
        console.error(e)
        originalImg.setAttribute('sgError', JSON.stringify(e));
        unblurImage(originalImg);
    }
}


function setImageSrc(element, url) {
    const isBackgroundImage = element.tagName !== 'IMG';
    if (isBackgroundImage) {
        element.style.backgroundImage = `url(${url})`;
        element.setAttribute('data-replaced', 'true');
        unblurImage(element);
    } else {
        element.style.opacity = "unset !important"
        element.src = url;
        element.setAttribute('data-replaced', 'true');
        unblurImageOnLoad(element);
        if (element.srcset) {
            element.srcset = "";
        }
    }

    // if parent is picture, remove the source elements
    if (element.parentElement.tagName === 'PICTURE') {
        const sources = element.parentElement.querySelectorAll('source');
        sources.forEach(source => source.remove());
    }
}

function handleDoubleTap(imgElement) {
    let lastTap = 0;
    let touchStartY = 0;
    const doubleTapDelay = 300; // maximum delay between taps to be considered a double tap
    const scrollThreshold = 10; // pixels of vertical movement to be considered a scroll attempt

    function handleTouchStart(e) {
        if (imgElement.getAttribute('isBlurred') === 'true') {
            touchStartY = e.touches[0].clientY;
            const currentTime = new Date().getTime();
            const tapLength = currentTime - lastTap;
            if (tapLength < doubleTapDelay && tapLength > 0) {
                // Double tap detected
                e.preventDefault();
                unblurImage(imgElement);
            }
            lastTap = currentTime;
        }
    }

    function handleTouchMove(e) {
        if (imgElement.getAttribute('isBlurred') === 'true') {
            const touchMoveY = e.touches[0].clientY;
            const verticalDistance = Math.abs(touchMoveY - touchStartY);
            if (verticalDistance > scrollThreshold) {
                // User is attempting to scroll, so we don't interfere
                lastTap = 0; // Reset lastTap to prevent accidental double-tap detection
            }
        }
    }

    function handleTouchEnd(e) {
        if (imgElement.getAttribute('isBlurred') === 'true') {
            // Only prevent default if it wasn't a scroll attempt
            if (Math.abs(e.changedTouches[0].clientY - touchStartY) <= scrollThreshold) {
                e.preventDefault();
            }
        }
    }

    imgElement.addEventListener('touchstart', handleTouchStart);
    imgElement.addEventListener('touchmove', handleTouchMove, {
        passive: true
    });
    imgElement.addEventListener('touchend', handleTouchEnd);
}

function blurImage(image, isInitial = false) {
    image.setAttribute('isBlurred', 'true');
    const blurMin = 0;
    const blurMax = 4;
    // Calculate blur value between min and max based on the window blur intensity
    const blurValue = blurMin + (window.blurIntensity * (blurMax - blurMin));
    if (isInitial) {
        image.style.filter = `blur(${blurValue}px)`;
        return;
    }
    // Apply the calculated filter values to the image
    image.style.filter = `blur(${blurValue}px) grayscale(100%) contrast(400%) brightness(100%) contrast(0.5) brightness(300%)`;
    image.style.opacity = "unset !important";
}

function unblurImageOnLoad(image) {
    image.onload = () => {
        image.style.filter = 'none';
    };
    image.setAttribute('isBlurred', 'false');
}

//Means that there is no object in image
function unblurImage(image) {
    image.style.filter = 'none';
    image.setAttribute('isBlurred', 'false');
}

function updateBluredImageOpacity() {
    const blurredElements = document.querySelectorAll('[isBlurred="true"]');
    blurredElements.forEach(element => {
        blurImage(element);
    });
}

async function getImageElements() {
    try {
        const minImageSize = 45; // Minimum image size in pixels

        const hasMinRenderedSize = (element) => {
            if (element.width === 0 || element.height === 0) return "not rendered yet";
            return (element.width >= minImageSize && element.height >= minImageSize)
        };

           
        async function getImageData(src) {
            const corsImage = new Image()
            corsImage.crossOrigin = 'anonymous';
            await new Promise ((resolve, reject) => {
                    corsImage.onload = resolve;
                    corsImage.onerror = reject;
                    corsImage.src = src;
                }
            )

            const {width, height, ratio} = calculateResizeDimensions(corsImage.width, corsImage.height, 800, 800);

            const canvas = createCanvas(width, height);
            const ctx = canvas.getContext('2d', {
                alpha: false,
                willReadFrequently: true
            });


            ctx.drawImage(corsImage, 0, 0, width, height);
            const imgData = canvas.toDataURL('image/png', 0.8).split(',')[1];
            return { imgData, canvas, ctx, ratio };
        }

        function calculateResizeDimensions(width, height, maxWidth, maxHeight) {
            const ratio = Math.min(maxWidth / width, maxHeight / height);
            return {
                width: width * ratio,
                height: height * ratio,
                ratio
            };
        }


        const processImage = async (htmlElement, src, type = "image", srcChanged = false, skipCheck = false) => {
          try {
              if (htmlElement.getAttribute('isSent') === type && !srcChanged) return;
              // we need to check the image size, but for that we need to make sure the image
              // has been loaded. If it has not been loaded, we need to wait for it to load
              if (type === "image") {
                if (htmlElement.complete) {
                    if (!hasMinRenderedSize(htmlElement)) return;
                } else {
                    htmlElement.addEventListener('load', processImage.bind(null, htmlElement, src, type, srcChanged), {once:true});

                    return;
                }
              } else {
                  if (hasMinRenderedSize(htmlElement) === false) return; // If the element is rendered but not of minimum size
              }
  
              blurImage(htmlElement, true)
              // Handle long press for mobile
              handleDoubleTap(htmlElement);
  
              const srcEdited = src?.startsWith('://') ? 'https:' + src :
                  src?.startsWith('data:') ? src :
                  src;
  
              const uid = Math.random().toString(36).substr(2, 9);
  
              try {
                  const { imgData, canvas, ctx,ratio } = await getImageData(srcEdited);
                  htmlElement.ourCanvas = canvas;
                  htmlElement.ourContext = ctx
                  htmlElement.ourRatio = ratio
                  sendMessage("coreML/-/" + srcEdited + "/-/" + uid + "/-/" + imgData);
              } catch (e) {
                    // console.error(e);
                 sendMessage("coreML/-/" + srcEdited + "/-/" + uid);
            }
              
  
              htmlElement.setAttribute('isSent', type);
              htmlElement.ourSrc = srcEdited;
              htmlElement.ourType = type;
              onProcessImageMap.set(uid, htmlElement);
          } catch (error) {
            console.error(error);
          }
        }

        const observeElement = (el, srcChanged = false) => {
            try {
                if (!el.getAttribute) return;
                if (el.getAttribute('isObserved') && !srcChanged) return;
                el.setAttribute('isObserved', 'true');

                let src = el.src
                const srcChecker = /url\(\s*?['"]?\s*?(\S+?)\s*?["']?\s*?\)/i
                let bgImage = window.getComputedStyle(el, null).getPropertyValue('background-image')
                let match = bgImage.match(srcChecker);
                // let xlink = el.getAttribute('xlink:href');

                if (/^img$/i.test(el.tagName)) { // to handle img tags
                    if (el.src?.length > 0) {
                        processImage(el, src, "image", srcChanged);
                    }
                }
                // SVG images are not supported for now
                // else if (xlink) { // to handle svg images
                //         src = xlink;
                //         processImage(el, src, "svg");
                // }
                else if (match) { // to handle background images
                    src = match[1];
                    processImage(el, src, "backgroundImage");
                }
            } catch (e) {
                console.log(e);
            }

        }

        const fetchNewImages = (mutations) => {
            mutations.forEach(mutation => {
                if (mutation.type === 'childList') {
                    mutation.addedNodes.forEach(node => {

                        observeElement(node);
                        // Process all child elements
                        if (!node.getElementsByTagName) return;
                        const allElements = node.getElementsByTagName('*');
                        for (let i = 0; i < allElements.length; i++) {
                            observeElement(allElements[i]);
                        }
                    });
                } else if (mutation.type === 'attributes') {
                    const el = mutation.target;
                    observeElement(el, mutation.attributeName === 'src' && !el.getAttribute("data-replaced"));
                }
            });
        }

        const observer = new MutationObserver(fetchNewImages)
        observer.observe(document, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src']
        });

        // Process initial images
        fetchNewImages([{
            type: 'childList',
            addedNodes: [document.body]
        }]);

        window.addEventListener('unload', sendMessage("page_refresh"))
    } catch (e) {
        console.log(e);
    }

}


getImageElements();
