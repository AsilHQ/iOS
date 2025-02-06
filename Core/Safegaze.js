// Copyright 2023 The Kahf Browser Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

class SkinDetector {
    constructor(options = {}) {
        this.options = {
            minSkinRatio: 0.3,
            rgbRanges: {
                r: { min: 95, max: 255 },
                g: { min: 40, max: 220 },
                b: { min: 20, max: 200 },
            },
            lowerBodyMinSkinRatio: 0.2, // Lower threshold for lower body only
            ...options,
        };
    }

    isSkinPixel(r, g, b) {
        const { rgbRanges } = this.options;

        if (
            r < rgbRanges.r.min ||
            r > rgbRanges.r.max ||
            g < rgbRanges.g.min ||
            g > rgbRanges.g.max ||
            b < rgbRanges.b.min ||
            b > rgbRanges.b.max
        ) {
            return false;
        }

        if (r < g || r < b) return false;
        const rgDiff = Math.abs(r - g);
        if (rgDiff < 15) return false;
        if (r > 220 && g > 210 && b > 170) return false;
        if (r < 100 && g < 100 && b < 100) return false;

        return true;
    }

    analyzeSkeleton(originalImageData, skeletonMask, analysisRegion = "full") {
        const { width, height, data } = originalImageData;
        const maskData = skeletonMask.data;
        const visualizationCanvas = document.createElement("canvas");
        visualizationCanvas.width = width;
        visualizationCanvas.height = height;
        const visCtx = visualizationCanvas.getContext("2d");
        const visData = visCtx.createImageData(width, height);

        let skinPixels = 0;
        let totalPixels = 0;

        for (let i = 0; i < data.length; i += 4) {
            if (
                maskData[i] == 53 &&
                maskData[i + 1] == 34 &&
                maskData[i + 2] == 34
            ) {
                // an exact color that we're using for the detection mask
                totalPixels++;

                if (this.isSkinPixel(data[i], data[i + 1], data[i + 2])) {
                    skinPixels++;
                    visData.data[i] = 255; // R
                    visData.data[i + 1] = 0; // G
                    visData.data[i + 2] = 0; // B
                    visData.data[i + 3] = 100; // A
                } else {
                    // color it in green
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
        const minSkinRatio =
            analysisRegion === "lowerBody"
                ? this.options.lowerBodyMinSkinRatio
                : this.options.minSkinRatio;

        return {
            visualization: visualizationCanvas,
            skinPixels,
            totalPixels,
            skinRatio,
            hasSkin: skinRatio >= minSkinRatio,
            analysisRegion,
        };
    }
}

class SkeletonDrawer {
    constructor(options) {
        this.connections = [
            // Face
            ["nose", "left_eye"],
            ["nose", "right_eye"],
            ["left_eye", "left_ear"],
            ["right_eye", "right_ear"],
            ["left_eye", "right_eye"],

            // Neck & Body connections
            ["nose", "left_shoulder"],
            ["nose", "right_shoulder"],
            ["left_ear", "left_shoulder"],
            ["right_ear", "right_shoulder"],
            ["left_shoulder", "right_shoulder"],
            ["left_shoulder", "left_elbow"],
            ["right_shoulder", "right_elbow"],
            ["left_elbow", "left_wrist"],
            ["right_elbow", "right_wrist"],
            ["left_shoulder", "left_hip"],
            ["right_shoulder", "right_hip"],
            ["left_shoulder", "right_hip"],
            ["right_shoulder", "left_hip"],
            ["left_hip", "right_hip"],
            ["left_hip", "left_knee"],
            ["right_hip", "right_knee"],
            ["left_knee", "left_ankle"],
            ["right_knee", "right_ankle"],
            ["left_knee", "right_knee"],
            ["left_ankle", "right_ankle"],
        ];

        this.options = {
            ...POSE_DETECTOR_DEFAULTS,
        };
    }
    // Calculate relative stroke width based on image dimensions
    calculateStrokeWidth(
        canvasWidth,
        canvasHeight,
        mode,
        gender = "female",
        keypoints = []
    ) {
        // First get the pose bounds to determine its size relative to the image
        const validPoints = keypoints.filter((kp) => kp.score);

        if (validPoints.length === 0) {
            // Fallback to old calculation if no valid points
            const smallerDimension = Math.min(canvasWidth, canvasHeight);
            return Math.max(
                2,
                Math.round(
                    smallerDimension * (gender === "female" ? 0.32 : 0.25)
                )
            );
        }

        // Calculate pose bounds
        const xs = validPoints.map((p) => p.x);
        const ys = validPoints.map((p) => p.y);
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
        const imageDimension = Math.min(canvasWidth, canvasHeight) / 1.2;

        // Blend between pose-based and image-based scaling based on pose size
        const baseSize =
            poseDimension * (1 - poseSizeRatio) +
            imageDimension * poseSizeRatio;
        const multiplier = gender === "female" ? 0.32 : 0.27;

        switch (mode) {
            case "debug":
                return 5;
            case "detection":
            case "standard":
                // Similarly adjust detection stroke width
                return Math.max(
                    15,
                    Math.round(baseSize * multiplier * poseSizeRatio)
                );

            default:
                throw new Error(`Unknown drawing mode: ${mode}`);
        }
    }

    drawSkeleton(ctx, keypoints, mode = "standard") {
        const config = {
            ...this.getConfig(mode, ctx.canvas.width, ctx.canvas.height),
            strokeWidth: this.calculateStrokeWidth(
                ctx.canvas.width,
                ctx.canvas.height,
                mode,
                "female", // Default to female for skeleton
                keypoints
            ),
        };
        ctx.save();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = config.strokeWidth;
        ctx.globalAlpha = config.alpha;

        // Draw connections
        this.connections
            .filter(([start, end]) => {
                const faceConnections = [
                    ["left_eye", "right_eye"],
                    ["left_eye", "left_ear"],
                    ["right_eye", "right_ear"],
                ];
                return !faceConnections.some(
                    ([s, e]) =>
                        (start === s && end === e) || (start === e && end === s)
                );
            })
            .forEach(([startPoint, endPoint]) => {
                const start = keypoints.find((kp) => kp.name === startPoint);
                const end = keypoints.find((kp) => kp.name === endPoint);

                if (start && end) {
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.strokeStyle = config.color;
                    ctx.stroke();
                }
            });

        // Draw face keypoints with red circles
        const faceKeypoints = [
            "nose",
            "left_eye",
            "right_eye",
            "left_ear",
            "right_ear",
        ];
        faceKeypoints.forEach((pointName) => {
            const point = keypoints.find((kp) => kp.name === pointName);
            if (point) {
                ctx.beginPath();
                ctx.arc(
                    point.x,
                    point.y,
                    config.strokeWidth / 2,
                    0,
                    2 * Math.PI
                );
                ctx.fillStyle = "red";
                ctx.fill();
            }
        });

        ctx.restore();
    }

    getConfig(mode, canvasWidth, canvasHeight) {
        const baseConfig = {
            standard: {
                color: "#9F9F9FFF",
                outlineColor: "#9F9F9FFF",
                alpha: 1,
            },
            debug: {
                color: "#808080",
                alpha: 0.7,
            },
            detection: {
                color: "#ADADAD",
                alpha: 1.0,
            },
        }[mode];

        if (!baseConfig) {
            throw new Error(`Unknown drawing mode: ${mode}`);
        }

        return {
            ...baseConfig,
            strokeWidth: this.calculateStrokeWidth(
                canvasWidth,
                canvasHeight,
                mode
            ),
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
        ctx.ellipse(centerX, centerY, radiusX, radiusY, 0, 0, 2 * Math.PI);

        // Create the clipping mask
        ctx.clip();

        // Draw the original image portion
        ctx.drawImage(
            originalCanvas,
            faceRegion.x,
            faceRegion.y,
            faceRegion.width,
            faceRegion.height,
            faceRegion.x,
            faceRegion.y,
            faceRegion.width,
            faceRegion.height
        );

        // Restore the context state
        ctx.restore();
    }

    getFaceRegion(keypoints) {
        // Get all face-related points
        const facePoints = [
            "nose",
            "left_eye",
            "right_eye",
            "left_ear",
            "right_ear",
        ]
            .map((name) => keypoints.find((kp) => kp.name === name))
            .filter((kp) => kp?.score);

        if (facePoints.length < 2) return null;

        // Get shoulder points if they exist
        const leftShoulder = keypoints.find(
            (kp) => kp.name === "left_shoulder" && kp.score
        );
        const rightShoulder = keypoints.find(
            (kp) => kp.name === "right_shoulder" && kp.score
        );

        // Calculate base dimensions from face points
        const xs = facePoints.map((p) => p.x);
        const ys = facePoints.map((p) => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        const baseWidth = maxX - minX;
        const baseHeight = maxY - minY;

        // Get reference points for height calculation
        const leftEye = keypoints.find(
            (kp) => kp.name === "left_eye" && kp.score
        );
        const rightEye = keypoints.find(
            (kp) => kp.name === "right_eye" && kp.score
        );
        const nose = keypoints.find((kp) => kp.name === "nose" && kp.score);

        if (!rightEye && !leftEye) return null;
        if (!nose) return null;

        const heightBetweenEyeAndNose = Math.abs(
            (rightEye || leftEye)?.y - nose?.y
        );

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
            height: finalHeight,
        };
    }

    drawDetectionMask(ctx, keypoints, options = {}) {
        const {
            gender = "unknown",
            faceRegion = null,
            mode = "detection",
        } = options;

        ctx.save();

        if (mode == "detection") {
            ctx.strokeStyle = "#352222FF"; // we'll use this unique color to mark the detection mask that we can then use for skin detection
            ctx.fillStyle = "#352222FF";
        } else {
            ctx.strokeStyle = "#ADADAD";
            ctx.fillStyle = "#ADADAD";
        }

        const calcLineWidth = this.calculateStrokeWidth(
            ctx.canvas.width,
            ctx.canvas.height,
            mode,
            gender,
            keypoints // Pass keypoints to calculate relative size
        );
        ctx.lineWidth = calcLineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (gender === "male") {
            // Male case remains unchanged - already using segments
            const lowerBodyConnections = [
                ["left_hip", "right_hip"],
                ["left_hip", "left_knee"],
                ["right_hip", "right_knee"],
                ["left_knee", "right_knee"],
            ];

            lowerBodyConnections.forEach(([startPoint, endPoint]) => {
                const start = keypoints.find((kp) => kp.name === startPoint);
                const end = keypoints.find((kp) => kp.name === endPoint);

                if (
                    start &&
                    end &&
                    start.score > this.options.minPartScoreMale &&
                    end.score > this.options.minPartScoreMale
                ) {
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.stroke();
                }
            });
        } else {
            // New segment-based approach for female/faceless
            const bodyConnections = [
                // Shoulders and arms
                ["left_shoulder", "right_shoulder"],
                ["left_shoulder", "left_elbow"],
                ["right_shoulder", "right_elbow"],
                ["left_elbow", "left_wrist"],
                ["right_elbow", "right_wrist"],

                // Torso sides
                ["left_shoulder", "left_hip"],
                ["right_shoulder", "right_hip"],

                // Torso cross connections
                ["left_shoulder", "right_hip"],
                ["right_shoulder", "left_hip"],

                // Hips and legs
                ["left_hip", "right_hip"],
                ["left_hip", "left_knee"],
                ["right_hip", "right_knee"],
                ["left_knee", "right_knee"],
                ["left_knee", "left_ankle"],
                ["right_knee", "right_ankle"],
            ];

            // Draw all regular body segments
            bodyConnections.forEach(([startPoint, endPoint]) => {
                const start = keypoints.find((kp) => kp.name === startPoint);
                const end = keypoints.find((kp) => kp.name === endPoint);

                if (start && end && start.score && end.score) {
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.stroke();
                }
            });

            if (gender != "female") {
                ctx.restore();
                return;
            }

            // Handle special calculated points (neck and groin)
            const nose = keypoints.find((kp) => kp.name === "nose");
            const leftShoulder = keypoints.find(
                (kp) => kp.name === "left_shoulder"
            );
            const rightShoulder = keypoints.find(
                (kp) => kp.name === "right_shoulder"
            );
            const leftHip = keypoints.find((kp) => kp.name === "left_hip");
            const rightHip = keypoints.find((kp) => kp.name === "right_hip");

            // Calculate and draw neck connections if points exist
            if (nose && leftShoulder && rightShoulder) {
                // Calculate neck points
                const neckLeft = {
                    x: (nose.x + leftShoulder.x) / 2,
                    y: (nose.y + leftShoulder.y) / 2,
                };
                const neckRight = {
                    x: (nose.x + rightShoulder.x) / 2,
                    y: (nose.y + rightShoulder.y) / 2,
                };
                const neckMiddle = {
                    x: (neckLeft.x + neckRight.x) / 2,
                    y: (neckLeft.y + neckRight.y) / 2,
                };

                // Draw neck segments
                ctx.lineWidth = calcLineWidth * 2;

                // Nose to neck sides
                if (nose.score) {
                    if (leftShoulder.score) {
                        ctx.beginPath();
                        ctx.moveTo(nose.x, nose.y);
                        ctx.lineTo(neckLeft.x, neckLeft.y);
                        ctx.stroke();
                    }
                    if (rightShoulder.score) {
                        ctx.beginPath();
                        ctx.moveTo(nose.x, nose.y);
                        ctx.lineTo(neckRight.x, neckRight.y);
                        ctx.stroke();
                    }
                }

                // Draw central line from neck to groin if points exist
                if (leftHip && rightHip && leftHip.score && rightHip.score) {
                    const groinPoint = {
                        x: (leftHip.x + rightHip.x) / 2,
                        y: (leftHip.y + rightHip.y) / 2,
                    };
                    ctx.beginPath();
                    ctx.moveTo(neckMiddle.x, neckMiddle.y);
                    ctx.lineTo(groinPoint.x, groinPoint.y);
                    ctx.stroke();
                }
            }

            ctx.lineWidth = calcLineWidth;

            // Handle face region only if points exist
            const leftEye = keypoints.find((kp) => kp.name === "left_eye");
            const rightEye = keypoints.find((kp) => kp.name === "right_eye");
            let distance;
            if (leftEye && rightEye) {
                distance = Math.abs(leftEye.x - rightEye.x);

                // Draw eye region segments
                ctx.beginPath();
                ctx.moveTo(leftEye.x, leftEye.y);
                ctx.lineTo(leftEye.x, leftEye.y - distance);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(leftEye.x, leftEye.y - distance);
                ctx.lineTo(rightEye.x, rightEye.y - distance);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(rightEye.x, rightEye.y - distance);
                ctx.lineTo(rightEye.x, rightEye.y);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(rightEye.x, rightEye.y);
                ctx.lineTo(leftEye.x, leftEye.y);
                ctx.stroke();
            }

            // Handle ear region if points exist
            const leftEar = keypoints.find((kp) => kp.name === "left_ear");
            const rightEar = keypoints.find((kp) => kp.name === "right_ear");
            if (leftEar && rightEar) {
                const earDistance =
                    (distance || Math.abs(leftEar.x - rightEar.x)) * 1.5;

                // Draw ear region segments
                ctx.beginPath();
                ctx.moveTo(leftEar.x, leftEar.y);
                ctx.lineTo(leftEar.x, leftEar.y - earDistance);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(leftEar.x, leftEar.y - earDistance);
                ctx.lineTo(rightEar.x, rightEar.y - earDistance);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(rightEar.x, rightEar.y - earDistance);
                ctx.lineTo(rightEar.x, rightEar.y);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(rightEar.x, rightEar.y);
                ctx.lineTo(leftEar.x, leftEar.y);
                ctx.stroke();
            }
        }

        ctx.restore();
    }

    drawFaceDebug(ctx, faceRegion, genderInfo) {
        if (!faceRegion) return;

        ctx.save();

        // Draw rectangle around face
        ctx.strokeStyle = genderInfo.isFemale ? "#FF69B4" : "#4169E1"; // Pink for female, Blue for male
        ctx.lineWidth = 3;

        // Draw rectangle
        ctx.strokeRect(
            faceRegion.x,
            faceRegion.y,
            faceRegion.width,
            faceRegion.height
        );

        // Add gender label
        const labelText = `${genderInfo.isFemale ? "Female" : "Male"} (${(
            genderInfo.confidence * 100
        ).toFixed(1)}%)`;

        // Set up text style
        ctx.font = "bold 14px Arial";
        ctx.textBaseline = "top";
        const textMetrics = ctx.measureText(labelText);
        const textPadding = 4;

        // Draw label background
        ctx.fillStyle = genderInfo.isFemale ? "#FF69B4" : "#4169E1";
        ctx.fillRect(
            faceRegion.x,
            faceRegion.y - 20, // Position above the face box
            textMetrics.width + textPadding * 2,
            20
        );

        // Draw label text
        ctx.fillStyle = "#FFFFFF";
        ctx.fillText(
            labelText,
            faceRegion.x + textPadding,
            faceRegion.y - 18 // Slight offset from background top
        );

        ctx.restore();
    }
}

const POSE_DETECTOR_DEFAULTS = {
    minPoseScore: 0.2,
    minPartScore: 0, // Minimum score for individual parts
    minPartScoreMale: 0.07, // Minimum score for individual parts
    minFacePartScore: 0.05,
    padding: 20,
};

const skinDetector = new SkinDetector();
const skeletonDrawer = new SkeletonDrawer();
const onProcessImageMap = new Map();

//============== HELPER FUNCTIONS ==============

function createCanvas(width, height) {
    const canvas = document.createElement("canvas");
    canvas.crossOrigin = "Anonymous";
    canvas.width = width;
    canvas.height = height;
    return canvas;
}

function setImageSrc(element, url) {
    const isBackgroundImage = element.tagName !== "IMG";
    if (isBackgroundImage) {
        element.style.backgroundImage = `url(${url})`;
        element.dataset.sgIsReplaced = true
    } else {
        element.style.opacity = "unset !important";
        element.src = url;
        element.dataset.sgIsReplaced = true
        if (element.srcset) {
            element.srcset = "";
        }
    }

    // if parent is picture, remove the source elements
    if (element.parentElement.tagName === "PICTURE") {
        const sources = element.parentElement.querySelectorAll("source");
        sources.forEach((source) => source.remove());
    }
}

function handleDoubleTap(imgElement) {
    let lastTap = 0;
    let touchStartY = 0;
    const doubleTapDelay = 300; // maximum delay between taps to be considered a double tap
    const scrollThreshold = 10; // pixels of vertical movement to be considered a scroll attempt

    function handleTouchStart(e) {
        if (imgElement.getAttribute("isBlurred") === "true") {
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
        if (imgElement.getAttribute("isBlurred") === "true") {
            const touchMoveY = e.touches[0].clientY;
            const verticalDistance = Math.abs(touchMoveY - touchStartY);
            if (verticalDistance > scrollThreshold) {
                // User is attempting to scroll, so we don't interfere
                lastTap = 0; // Reset lastTap to prevent accidental double-tap detection
            }
        }
    }

    function handleTouchEnd(e) {
        if (imgElement.getAttribute("isBlurred") === "true") {
            // Only prevent default if it wasn't a scroll attempt
            if (
                Math.abs(e.changedTouches[0].clientY - touchStartY) <=
                scrollThreshold
            ) {
                e.preventDefault();
            }
        }
    }

    imgElement.addEventListener("touchstart", handleTouchStart);
    imgElement.addEventListener("touchmove", handleTouchMove, {
        passive: true,
    });
    imgElement.addEventListener("touchend", handleTouchEnd);
}

function blurImage(image, isInitial = false) {
    image.dataset.sgIsBlurred= "true";
    const blurMin = 0;
    const blurMax = 4;
    // Calculate blur value between min and max based on the window blur intensity
    const blurValue = blurMin + window.blurIntensity * (blurMax - blurMin);
    if (isInitial) {
        image.classList.add("sg-init-blur");
        return;
    }
    // Apply the calculated filter values to the image
    // image.style.filter = `blur(${blurValue}px) grayscale(100%) contrast(400%) brightness(100%) contrast(0.5) brightness(300%)`;
    // image.style.opacity = "unset !important";
}

function unblurImage(image) {
    image.classList.remove("sg-init-blur");
    // image.style.filter = "none";
    // image.style.visibility = "visible";
    image.dataset.sgIsBlurred= false;
}

function updateBluredImageOpacity() {
    const blurredElements = document.querySelectorAll('[isBlurred="true"]');
    blurredElements.forEach((element) => {
        blurImage(element);
    });
}

function pixelateRegion(ctx, originalCanvas, width, height) {
    // Calculate dynamic pixel size based on image dimensions
    // Using the smaller dimension to ensure consistent appearance across different image sizes

    const ratio =  Math.min(width, height);
    const x = Math.floor(0.08 * ratio)

    const pixelSize =  Math.min(x, ratio > 1000? 35: 29);

    // Create temporary canvases for pixelation
    const tempCanvas1 = createCanvas(width, height);
    const tempCtx1 = tempCanvas1.getContext('2d');
    
    const tempCanvas2 = createCanvas(width, height);
    const tempCtx2 = tempCanvas2.getContext('2d');
    
    // Draw original to first temp canvas
    tempCtx1.drawImage(originalCanvas, 0, 0, width, height);
    
    // Scale down and up to create pixelation effect
    const scaledWidth = Math.ceil(width / pixelSize);
    const scaledHeight = Math.ceil(height / pixelSize);
    
    tempCtx2.imageSmoothingEnabled = false;
    // Draw scaled down
    tempCtx2.drawImage(tempCanvas1,
        0, 0, width, height,
        0, 0, scaledWidth, scaledHeight
    );
    // Draw scaled up
    tempCtx2.drawImage(tempCanvas2,
        0, 0, scaledWidth, scaledHeight,
        0, 0, width, height
    );
    
    // Apply grayscale effect
    const imageData = tempCtx2.getImageData(0, 0, width, height);
    const data = imageData.data;
    
    for (let i = 0; i < data.length; i += 4) {
        // Convert to grayscale using luminosity method
        const gray = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
        data[i] = gray;     // red
        data[i + 1] = gray; // green
        data[i + 2] = gray; // blue
        // alpha remains unchanged
    }
    
    // Put the grayscale pixelated data back
    tempCtx2.putImageData(imageData, 0, 0);
    
    // Draw final result back to main context
    ctx.drawImage(tempCanvas2, 0, 0);
    
    // Clean up
    tempCanvas1.remove();
    tempCanvas2.remove();
}

function initStyleSheet() {
    const style = document.createElement('style');
    style.id = "sg-styles";
    style.innerHTML = `    
    .sg-init-blur {
        filter: blur(5px) grayscale(0.5);
        animation: fadeInOut 2s 15 forwards;
    }
    
    @keyframes fadeInOut {
        0% { 
            opacity: 0.1;
            filter: blur(5px) grayscale(0.5);
        }
        50% { 
            opacity: 0.3;
            filter: blur(5px) grayscale(0.5);
        }
        99% {
            opacity: 0.1;
            filter: blur(5px) grayscale(0.5);
        }
        100% { 
            opacity: 1;
            filter: none;
        }
    }
  `;

    // if document head is defined else wait for domcontent
    document.head ? document.head.appendChild(style) : document.addEventListener("DOMContentLoaded", () => document.head.appendChild(style));
}

//============== CORE FUNCTIONS ==============

async function safegazeOnDeviceModelHandler(uid, detectionResultStr, imgData) {
    const originalImg = onProcessImageMap.get(uid);
    if (!originalImg) return;

    unblurImage(originalImg);
    try {
        if (!detectionResultStr || !imgData?.length) {
            return;
        }

        const detectionResult = JSON.parse(detectionResultStr);
        if (!detectionResult) return;

        // 1. If the image is NSFW, blur it
        const isNsfw = detectionResult?.isNSFW;
        if (isNsfw) {
            
            // pixelate the entire image
            const width = originalImg.width;
            const height = originalImg.height;
            const canvas = createCanvas(width, height);
            const ctx = canvas.getContext('2d');
            const newImg = new Image(width, height);
            newImg.crossOrigin = "anonymous";
            try {
                if (!imgData.length) throw new Error("No image data");
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
                });
            }

            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(newImg, 0, 0, width, height);
            pixelateRegion(ctx, canvas, width, height);
            setImageSrc(originalImg, canvas.toDataURL());
            return;
        }

        // Get exact dimensions from image
        const imgWidthKotlin = detectionResult.imageWidth;
        const imgHeightKotlin = detectionResult.imageHeight;

        let width, height, ratioX, ratioY;

        let newImg,
            originalCanvas = originalImg.ourCanvas,
            originalCtx = originalImg.ourContext;
        if (!originalCanvas || !originalCtx) {
            // we couldn't convert the image to base64 earlier
            width = originalImg.width;
            height = originalImg.height;
            ratioX = width / imgWidthKotlin;
            ratioY = height / imgHeightKotlin;

            newImg = new Image(width, height);
            newImg.crossOrigin = "anonymous";
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
                });
            }
            originalCanvas = createCanvas(width, height);
            originalCtx = originalCanvas.getContext("2d", {
                alpha: true,
                willReadFrequently: true,
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
        const ctx = canvas.getContext("2d", {
            alpha: true,
            willReadFrequently: true,
        });

        // Clear and draw original image
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(originalCanvas, 0, 0, width, height);

        let shouldBlur = false;
        let facesToRedraw = [];

        // 2. Loop over all the poses and draw the body masks.
        for (const [key, value] of Object.entries(
            detectionResult?.persons ?? {}
        )) {
            let {
                faceBox,
                poseBox, // doesn't seem like this is needed
                isFemale,
                genderScore,
                keypoints,
                id,
                poseScore, // i'll sstil see if neeed
                faceScore, // i'll still see if needed
            } = value;
            if (poseScore < POSE_DETECTOR_DEFAULTS.minPoseScore) continue;

            if (!faceBox) isFemale = null;

            const isMale = isFemale === null ? null : !isFemale;
            const gender =
                isFemale === null ? "" : isFemale == true ? "female" : "male";

            faceBox = faceBox
                ? {
                        xMin: faceBox.xMin * ratioX,
                        yMin: faceBox.yMin * ratioY,
                        width: faceBox.width * ratioX,
                        height: faceBox.height * ratioY,
                  }
                : null;

            keypoints = keypoints
                .map((kp) => ({
                    ...kp,
                    x: kp.x * ratioX,
                    y: kp.y * ratioY,
                }))
                ?.filter((kp) => {
                    const scoreThreshold = [
                        "left_eye",
                        "right_eye",
                        "nose",
                        "left_ear",
                        "right_ear",
                    ].includes(kp.name)
                        ? POSE_DETECTOR_DEFAULTS.minFacePartScore
                        : isMale
                        ? POSE_DETECTOR_DEFAULTS.minPartScoreMale
                        : POSE_DETECTOR_DEFAULTS.minPartScore;
                    return kp.score > scoreThreshold;
                });

            // Create detection mask for skin analysis
            const maskCanvas = createCanvas(width, height);
            const maskCtx = maskCanvas.getContext("2d", {
                alpha: true,
                willReadFrequently: true,
            });

            // Draw the detection mask
            skeletonDrawer.drawDetectionMask(maskCtx, keypoints, {
                gender: isMale ? "male" : "female",
                faceRegion: faceBox, // will be null for faceless
                mode: "detection",
            });

            // analyze skin for everyone (no face, no gender, males) but not for female with face
            const shouldAnalyzeSkin = !isFemale || !faceBox;

            // Analyze skin using the mask
            const imageData = ctx.getImageData(0, 0, width, height);
            const maskImageData = maskCtx.getImageData(0, 0, width, height);
            const analysis = !shouldAnalyzeSkin
                ? null
                : skinDetector.analyzeSkeleton(
                        imageData,
                        maskImageData,
                        isMale ? "lowerBody" : "full"
                  );

            // If female or enough skin detected, apply gray mask
            if (!shouldAnalyzeSkin || analysis?.hasSkin) {
                ctx.save();
                // ctx.globalAlpha = 0.7;

                // Create a clipping path using the detection mask
                ctx.beginPath();
                maskCtx.globalCompositeOperation = 'source-atop';
                

                // Apply the mask as a clipping path
                const maskData = maskCtx.getImageData(0, 0, width, height).data;
                const region = new Path2D();


                for (let y = 0; y < height; y++) {
                    for (let x = 0; x < width; x++) {
                        const index = (y * width + x) * 4;
                        if (maskData[index] === 53 && maskData[index + 1] === 34 && maskData[index + 2] === 34) {
                        region.rect(x, y, 1, 1);
                        }
                    }
                }

                ctx.clip(region);

                pixelateRegion(ctx, originalCanvas, width, height);

                // Fill the masked area with gray
                ctx.globalCompositeOperation = "source-atop";

                ctx.restore();

                shouldBlur = true;
            }

            faceBox && facesToRedraw.push(faceBox);

            if (window.sgSettings?.debug) {
                faceBox &&
                    skeletonDrawer.drawFaceDebug(
                        ctx,
                        {
                            x: faceBox.xMin,
                            y: faceBox.yMin,
                            width: faceBox.width,
                            height: faceBox.height,
                        },
                        {
                            isFemale,
                            confidence: isFemale
                                ? genderScore
                                : 1 - genderScore,
                        }
                    );

                ctx.fillStyle = "#800080";
                ctx.font = "16px Arial";
                const textY = 150;

                gender && ctx.fillText(`Gender: ${gender}`, 10, textY - 25);
                if (analysis) {
                    ctx.fillText(
                        `Analysis Region: ${analysis.analysisRegion}`,
                        10,
                        textY
                    );
                    ctx.fillText(
                        `Skin Pixels: ${analysis.skinPixels}/${analysis.totalPixels}`,
                        10,
                        textY + 50
                    );
                    ctx.fillText(
                        `Skin Ratio: ${(analysis.skinRatio * 100).toFixed(1)}%`,
                        10,
                        textY + 75
                    );
                    ctx.fillText(
                        `Threshold: ${
                            (gender != "male"
                                ? skinDetector.options.minSkinRatio
                                : skinDetector.options.lowerBodyMinSkinRatio) *
                            100
                        }%`,
                        10,
                        textY + 100
                    );

                    if (analysis.visualization) {
                        ctx.drawImage(analysis.visualization, 0, 0);
                    }
                }
                skeletonDrawer.drawSkeleton(ctx, keypoints, "debug");
            }
        }

        // draw the faces
        if (shouldBlur) {
            // Redraw faces to avoid blurring them
            for (const faceBox of facesToRedraw) {
                skeletonDrawer.drawOvalFaceRegion(ctx, originalCanvas, {
                    x: faceBox.xMin,
                    y: faceBox.yMin,
                    width: faceBox.width,
                    height: faceBox.height,
                });
            }
            const newSrcUrl = canvas.toDataURL("image/png", 1.0);
            setImageSrc(originalImg, newSrcUrl);
        }
    } catch (e) {
        console.error(e);
        originalImg.dataset.sgError = JSON.stringify(e);
    }
}

const debouncer = (func, wait) => {
    let timeout;
    return (...args) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => func.apply(this, args), wait);
    };
};

async function getImageElements() {
    console.log ("document state", document.readyState)
    const shouldDebug = localStorage.getItem("sgDebug") === "true";
    window.sgSettings = {
        debug: shouldDebug,
    };

    // add a style sheet with custom styles:
    initStyleSheet();

    try {
        const minImageSize = 45; // Minimum image size in pixels

        const hasMinRenderedSize = (element) => {
            const width = element.width || element.clientWidth;
            const height = element.height || element.clientHeight;
            if (width || height) {
                return true; // if the image has not been rendered yet, skip it
            }
            return (
                width >= minImageSize &&
                height >= minImageSize
            );
        };
        async function getImageData(src) {
            const corsImage = new Image();
            corsImage.crossOrigin = "anonymous";
            await new Promise((resolve, reject) => {
                corsImage.onload = resolve;
                corsImage.onerror = reject;
                corsImage.src = src;
            });

            const { width, height, ratio } = calculateResizeDimensions(
                corsImage.width,
                corsImage.height,
                800,
                800
            );

            const canvas = createCanvas(width, height);
            const ctx = canvas.getContext("2d", {
                alpha: false,
                willReadFrequently: true,
            });

            ctx.drawImage(corsImage, 0, 0, width, height);
            const imgData = canvas.toDataURL("image/png", 0.8).split(",")[1];
            return { imgData, canvas, ctx, ratio };
        }

        function calculateResizeDimensions(width, height, maxWidth, maxHeight) {
            const ratio = Math.min(maxWidth / width, maxHeight / height);
            return {
                width: width * ratio,
                height: height * ratio,
                ratio,
            };
        }

        const processImage = async (
            htmlElement,
            src,
            type = "image",
            srcChanged = false
        ) => {
            try {
                if (htmlElement.dataset.sgIsSent === type && !srcChanged)
                    return;
                blurImage(htmlElement, true);

                // Handle image loading state
                if (type === "image") {
                    htmlElement.removeEventListener("load", processImage);
                    if (
                        htmlElement.complete ||
                        htmlElement.complete === undefined
                    ) {
                        if (!hasMinRenderedSize(htmlElement)) {
                            unblurImage(htmlElement);
                            return;
                        }
                    } else {
                        htmlElement.addEventListener(
                            "load",
                            processImage.bind(
                                null,
                                htmlElement,
                                src,
                                type,
                                srcChanged
                            ),
                            { once: true }
                        );
                        return;
                    }
                } else {
                    if (hasMinRenderedSize(htmlElement) === false) return;
                }

                handleDoubleTap(htmlElement);

                const srcEdited = src?.startsWith("://")
                    ? "https:" + src
                    : src?.startsWith("data:")
                    ? src
                    : src;

                const uid = Math.random().toString(36).substr(2, 9);

                try {
                    const { imgData, canvas, ctx, ratio } = await getImageData(
                        srcEdited
                    );
                    htmlElement.ourCanvas = canvas;
                    htmlElement.ourContext = ctx;
                    htmlElement.ourRatio = ratio;
                    sendMessage(
                        "coreML/-/" + srcEdited + "/-/" + uid + "/-/" + imgData
                    );
                } catch (e) {
                    sendMessage("coreML/-/" + srcEdited + "/-/" + uid);
                }

                htmlElement.dataset.sgIsSent = type;
                htmlElement.ourSrc = srcEdited;
                htmlElement.ourType = type;
                onProcessImageMap.set(uid, htmlElement);
            } catch (error) {
                console.error(error);
            }
        };

        const observeElement = (el, srcChanged = false) => {
            try {
                if (!el.getAttribute) return;
                if (el.dataset.sgIsObserved && !srcChanged) return;
                el.dataset.sgIsObserved = "true";

                let src = el.src;
                if (el.tagName === "IMG") {
                    if (el.src?.length > 0) {
                        processImage(el, src, "image", srcChanged);
                    }
                    return;
                }

                const srcChecker = /url\(\s*?['"]?\s*?(\S+?)\s*?["']?\s*?\)/i;
                let bgImage = window
                    .getComputedStyle(el, null)
                    .getPropertyValue("background-image");
                let match = bgImage.match(srcChecker);

                if (match) {
                    el.dataset.sgIsBg = "true";
                    src = match[1];
                    processImage(el, src, "backgroundImage");
                }
            } catch (e) {
                console.error(e);
            }
        };

        // Add efficient background image checking
        const checkForBgImages = debouncer(() => {
            const elements = document.querySelectorAll(
                `*:not(img):not([data-sg-is-observed]):not([data-sg-is-bg])`
            );
            elements.forEach((el) => observeElement(el));
        }, 300);

        const fetchNewImages = (mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === "childList") {
                    if (mutation.addedNodes?.length) checkForBgImages();
                    mutation.addedNodes.forEach((node) => {
                        if (!node) return;
                        if (!node.getElementsByTagName) return;

                        // Focus on IMG elements specifically
                        const allElements = node.getElementsByTagName("IMG");
                        for (let i = 0; i < allElements.length; i++) {
                            observeElement(allElements[i]);
                        }
                        if (node.tagName === "IMG") {
                            observeElement(node);
                        }
                    });
                } else if (mutation.type === "attributes") {
                    const el = mutation.target;
                    observeElement(
                        el,
                        mutation.attributeName === "src" &&
                            !el.dataset.sgIsReplaced
                    );
                }
            });
        };

        const observer = new MutationObserver(fetchNewImages);
        observer.observe(document, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ["src"],
        });

        // Process initial images
        fetchNewImages([
            {
                type: "childList",
                addedNodes: [document.body],
            },
        ]);

        window.addEventListener("unload", () => sendMessage("page_refresh"));
    } catch (e) {
        console.error(e);
    }
}

//============== INITIALIZAITON ==============

window.safegazeOnDeviceModelHandler = safegazeOnDeviceModelHandler;
window.updateBluredImageOpacity = updateBluredImageOpacity;
window.sendMessage = function (message) {
    console.log(message);
    try {
        SafeGazeInterface.sendMessage(message);
    } catch {}
};

getImageElements();
