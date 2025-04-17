//
//  test.js
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

function calculateVideoDimensions$1(source) {
  if (!source.videoWidth) {
    return [source.clientWidth, source.clientHeight];
  }
  const videoWidth = source.videoWidth;
  const videoHeight = source.videoHeight;
  const clientWidth = source.clientWidth;
  const clientHeight = source.clientHeight;
  const aspectRatio = videoWidth / videoHeight;
  let scaledWidth, scaledHeight;
  scaledHeight = clientWidth / aspectRatio;
  if (scaledHeight <= clientHeight) {
    scaledWidth = clientWidth;
  } else {
    scaledHeight = clientHeight;
    scaledWidth = clientHeight * aspectRatio;
  }
  const horizontalPadding = (clientWidth - scaledWidth) / 2;
  const verticalPadding = (clientHeight - scaledHeight) / 2;
  return [
    Math.round(scaledWidth),
    Math.round(scaledHeight),
    Math.round(horizontalPadding) + "px",
    Math.round(verticalPadding) + "px"
  ];
}
function createCanvasForVideo(source) {
  let container = source.parentNode;
  let existingCanvas = container.querySelector("canvas[porda-canva]");
  if (existingCanvas) {
    const result2 = calculateVideoDimensions$1(source);
    console.log(result2);
    if (existingCanvas.width != result2[0] || existingCanvas.height != result2[1]) {
      existingCanvas.width = result2[0];
      existingCanvas.height = result2[1];
    }
    if (source.style.top) {
      if (existingCanvas.style.top != source.style.top || existingCanvas.style.left != source.style.left) {
        existingCanvas.style.top = source.style.top;
        existingCanvas.style.left = source.style.left;
      }
    } else {
      if (existingCanvas.style.left != result2[2] || existingCanvas.style.top != result2[3]) {
        existingCanvas.style.left = result2[2];
        existingCanvas.style.top = result2[3];
      }
    }
    return existingCanvas.getContext("2d");
  }
  if (container.tagName !== "DIV") {
    container = document.createElement("div");
    container.style.position = "relative";
    container.style.display = "inline-block";
    source.parentNode.insertBefore(container, source);
    container.appendChild(source);
  }
  const canvas = document.createElement("canvas");
  canvas.setAttribute("porda-canva", true);
  canvas.style.position = "absolute";
  const result = calculateVideoDimensions$1(source);
  canvas.width = result[0];
  canvas.height = result[1];
  canvas.style.left = result[2];
  canvas.style.top = result[3];
  canvas.style.pointerEvents = "none";
  container.appendChild(canvas);
  return canvas.getContext("2d");
}
const tempCanvas = document.createElement("canvas");
tempCanvas.getContext("2d");
const img$1 = new Image();
const replaceImgOnVideo = (ctx, base64Image) => {
  console.log(base64Image.substring(0, 20));
  img$1.src = base64Image;
  img$1.onload = () => {
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.drawImage(img$1, 0, 0, ctx.canvas.width, ctx.canvas.height);
  };
  img$1.onerror = () => {
    console.log("Image error");
  };
};
performance.now();
let isProcessingFrame = false;
let videoFrameDrawingCanva;
let videoFrameDrawingCtx;
let video_canva;
let idleCallbackId;
function generateTaskIdFromVideo() {
  const timestamp = Date.now();
  const taskId = timestamp.toString(16);
  return taskId;
}
const sendVideoFrameBackground = async (frameInfo) => {
  const frameInfoString = JSON.stringify(frameInfo);
  sendMessageToKotlin("detectVideoFrame", frameInfoString);
};
function delay$1(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
function calculateVideoDimensions(source) {
  if (!source.videoWidth) {
    return [source.clientWidth, source.clientHeight];
  }
  const videoWidth = source.videoWidth;
  const videoHeight = source.videoHeight;
  const clientWidth = source.clientWidth;
  const clientHeight = source.clientHeight;
  const aspectRatio = videoWidth / videoHeight;
  let scaledWidth, scaledHeight;
  scaledHeight = clientWidth / aspectRatio;
  if (scaledHeight <= clientHeight) {
    scaledWidth = clientWidth;
  } else {
    scaledHeight = clientHeight;
    scaledWidth = clientHeight * aspectRatio;
  }
  return [Math.round(scaledWidth), Math.round(scaledHeight)];
}
function handlePlay(event) {
  const video = event.target;
  startsCaptutingVideo(video);
  performance.now();
}
const cancelVideoDetection = (video) => {
  if (video == null ? void 0 : video.frameRequestId) {
    cancelAnimationFrame(video.frameRequestId);
    video.frameRequestId = null;
  }
  if (video == null ? void 0 : video.idleCbId) {
    cancelIdleCallback(video.idleCbId);
    video.idleCbId = null;
  }
};
function handlePauseEnd(event) {
  const video = event.target;
  cancelVideoDetection(video);
}
function addVideoListeners(video) {
  video.addEventListener("play", handlePlay);
  video.addEventListener("pause", handlePauseEnd);
  video.addEventListener("ended", handlePauseEnd);
}
const loadVideoElement = async (video) => {
  console.log("element loading video");
  if (video == null ? void 0 : video.isLoaded)
    return true;
  if (!video || !(video instanceof HTMLVideoElement)) {
    throw new Error("Invalid video element");
  }
  return new Promise((resolve, reject) => {
    video.crossOrigin = "anonymous";
    video.setAttribute("crossOrigin", "anonymous");
    if (video.readyState >= 3 && video.videoHeight > 2) {
      video.isLoaded = true;
      video.dataset.taskid = generateTaskIdFromVideo();
      addVideoListeners(video);
      resolve(true);
      return;
    }
    video.onloadeddata = () => {
      if (video.videoHeight) {
        video.isLoaded = true;
        video.dataset.taskid = generateTaskIdFromVideo();
        addVideoListeners(video);
        resolve(true);
      } else {
        reject(new Error("Video loaded but has no valid height"));
      }
    };
    video.onerror = () => reject(new Error("Failed to load video"));
  });
};
const startsCaptutingVideo = async (node) => {
  console.log("ready for capturing video");
  try {
    let newWidth = 0;
    let newHeight = 0;
    const result = calculateVideoDimensions(node);
    const finelWidth = result[0];
    const finelHeight = result[1];
    if (finelWidth > 224 || finelHeight > 224) {
      const maxSize = Math.max(finelWidth, finelHeight);
      if (maxSize === finelWidth) {
        newWidth = 224;
        const downscaleFactor = maxSize / 224;
        newHeight = parseInt(finelHeight / downscaleFactor);
      } else {
        newHeight = 224;
        const downscaleFactor = maxSize / 224;
        newWidth = parseInt(finelWidth / downscaleFactor);
      }
    } else {
      newWidth = finelWidth;
      newHeight = finelHeight;
    }
    newWidth = node.clientWidth;
    newHeight = node.clientHeight;
    if (!videoFrameDrawingCanva) {
      videoFrameDrawingCanva = document.createElement("canvas");
      videoFrameDrawingCanva.width = newWidth;
      videoFrameDrawingCanva.height = newHeight;
      videoFrameDrawingCtx = videoFrameDrawingCanva.getContext("2d", {
        alpha: false,
        willReadFrequently: true
      });
    }
    if (videoFrameDrawingCanva.width !== newWidth || videoFrameDrawingCanva.height !== newHeight) {
      videoFrameDrawingCanva.width = newWidth;
      videoFrameDrawingCanva.height = newHeight;
    }
    if (node.idleCbId) {
      detectionCycle(node, newWidth, newHeight);
    } else {
      idleCallbackId = requestIdleCallback(() => {
        detectionCycle(node, newWidth, newHeight);
      });
      node.idleCbId = idleCallbackId;
    }
  } catch (e) {
  }
};
const readyVideoElementForProcessing = async (node, isfb = false) => {
  console.log("ready for processing video");
  try {
    node.dataset.PordaCondition = "Loading";
    if (!node.isLoaded) {
      await loadVideoElement(node);
    }
    node.dataset.PordaCondition = "processing";
    console.log("========isfb===========", isfb);
    if (!isfb) {
      startsCaptutingVideo(node);
    }
  } catch (er) {
  }
};
const detectionCycle = async (video, width, height) => {
  console.log("detection cycle");
  try {
    if (true) {
      isProcessingFrame = true;
      videoFrameDrawingCtx.drawImage(video, 0, 0, width, height);
      const framedataUrl = videoFrameDrawingCanva.toDataURL(
        "image/jpeg",
        0.7
      );
      const frameInfo = {
        src: framedataUrl,
        id: video.dataset.taskid,
        width,
        height
      };
      sendVideoFrameBackground(frameInfo);
      console.log("img sent to kotlin");
    }
  } catch (er) {
    console.log(er);
    isProcessingFrame = false;
    await delay$1(200);
  }
  await delay$1(100);
  if (video.paused || video.ended) {
    video.onplay = () => {
      video.frameRequestId = requestAnimationFrame(
        () => detectionCycle(video, width, height)
      );
    };
  } else {
    video.frameRequestId = requestAnimationFrame(
      () => detectionCycle(video, width, height)
    );
  }
};
let targetVideo;
const putCoverOnVideoAsResult = async (response) => {
  let width;
  let height;
  try {
    const parsedData = JSON.parse(response);
    const detectionResult = parsedData.result;
    const taskId = parsedData.id;
    width = parsedData.width;
    height = parsedData.height;
    targetVideo = document.querySelector(`[data-taskid='${taskId}']`);
    if (!targetVideo) {
      console.log("Video not found");
      if (video_canva) {
        video_canva.clearRect(
          0,
          0,
          video_canva.canvas.width,
          video_canva.canvas.height
        );
      }
      return;
    }
    if (detectionResult === "null") {
      console.log("null result");
      if (video_canva) {
        video_canva.clearRect(
          0,
          0,
          video_canva.canvas.width,
          video_canva.canvas.height
        );
      }
      return;
    }
    if (detectionResult === "concurrent") {
      console.log("concurrent result");
      return;
    }
    video_canva = createCanvasForVideo(targetVideo);
    if (video_canva) {
      replaceImgOnVideo(video_canva, detectionResult);
    } else {
      console.log("video canvas not found");
    }
  } catch (e) {
    console.log("error ", e);
  } finally {
    isProcessingFrame = false;
  }
};
let settignsnode = [];
let isSiteFacebook = false;
const updateSettingInObserveNode = (settign) => {
  settignsnode = settign;
};
const updateVariable = (fbSite, isAdWhite = "") => {
  isSiteFacebook = fbSite;
};
const observeChildNode = async (childNode) => {
  console.log(childNode.nodeType);
  if (true) {
    const imagesAndVideosAndIframes = childNode.querySelectorAll(
      "img, video, iframe,svg image"
    );
    imagesAndVideosAndIframes.forEach((element) => {
      observeElement(element);
    });
  }
};
const observeElement = (node) => {
  var _a, _b, _c, _d, _e, _f;
  console.log(node);
  if (node.tagName === "IMG") {
    if (((_a = node.dataset) == null ? void 0 : _a.UnderProcessing) === "true") {
      return;
    }
    node.dataset.PordaCondition = "CheckingByMutationObserver";
    const nodeSrc = node.hasAttribute("src") ? node.src : node.getAttribute("srcset");
    if (!(node.dataset.PordaOriginalSrc === nodeSrc)) {
      (_b = node.dataset) == null ? true : delete _b.PordaCondition;
      (_c = node.dataset) == null ? true : delete _c.pordaDone;
      (_d = node.dataset) == null ? true : delete _d.PordaResult;
      (_e = node.dataset) == null ? true : delete _e.currentTabid;
      (_f = node.dataset) == null ? true : delete _f.currentTaburl;
      node.dataset.PordaCondition = "CheckingByMutationObserver-NodeSrcUpdateds";
    }
    observeImgNode(node);
    return;
  }
  if (node.tagName === "VIDEO") {
    observeVideoNode(node);
    return;
  }
  if (!settignsnode.isDetectAds)
    return;
  if (node.tagName === "IFRAME") {
    if (settignsnode.isDetectAds) {
      observeIframe(node);
      return;
    }
  }
  if (node.tagName.toLowerCase() === "image" && node.namespaceURI === "http://www.w3.org/2000/svg") {
    if (settignsnode.isBlockAllImage) {
      img.style.opacity = "0";
      return;
    }
    let width = parseFloat(node.style.width);
    let height = parseFloat(node.style.height);
    if (isNaN(width) || isNaN(height)) {
      width = parseFloat(node.getAttribute("width"));
      height = parseFloat(node.getAttribute("height"));
      if (isNaN(width) || isNaN(height)) {
        const bbox = node.getBBox();
        width = bbox.width;
        height = bbox.height;
      }
    }
    if (height < 60 || width < 60) {
      return;
    }
    node.dataset.svg = "observed";
    observeImgNode(node);
    return;
  }
};
const observeImgNode = async (img2) => {
  if (settignsnode.isBlockAllImage) {
    img2.style.opacity = "0";
    return;
  }
  if (img2.dataset.pordaDone)
    return;
  if (img2.dataset.PordaResult)
    return;
  if (settignsnode.isInitiallyImgBlur) {
    if (img2.naturalWidth > 500) {
      img2.style.filter = "blur(20px)";
    } else if (img2.naturalWidth > 300) {
      img2.style.filter = "blur(15px)";
    } else {
      img2.style.filter = "blur(8px)";
    }
  }
  let imgSrc = img2.hasAttribute("src") ? img2.src : img2.getAttribute("srcset");
  if (!imgSrc) {
    imgSrc = img2.getAttributeNS("http://www.w3.org/1999/xlink", "href");
    if (!imgSrc) {
      imgSrc = img2.getAttribute("href");
    }
  }
  if (img2.naturalHeight < 2 || img2.naturalWidth < 2) {
    img2.addEventListener("load", recheckImage);
    return;
  } else if (img2.height < 80 || img2.width < 80) {
    img2.style.filter = "none";
    img2.dataset.PordaCondition = "ImgSmall";
    return;
  } else if (!imgSrc) {
    img2.dataset.PordaCondition = "request-reobserve";
    img2.dataset.PordaReason = "img-src-less";
    return;
  } else {
    img2.dataset.PordaCondition = "ImgReadyToProcess";
    setTimeout(() => {
      sendImgForDetection(img2, imgSrc);
    }, 5);
  }
};
const observeVideoNode = (videoNode) => {
  var _a, _b;
  if (videoNode.clientHeight < 200)
    return;
  if (videoNode.clientHeight < 200)
    return;
  if (videoNode.clientWidth < 150)
    return;
  if (videoNode.clientWidth < 300 && videoNode.clientHeight < 200)
    return;
  if (!videoNode.dataset.PordaCondition && (((_a = videoNode.src) == null ? void 0 : _a.length) > 0 || ((_b = videoNode.getElementsByTagName("source")) == null ? void 0 : _b.length) > 2)) {
    readyVideoElementForProcessing(videoNode, isSiteFacebook);
    videoNode.dataset.PordaCondition = "Checked";
  }
};
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
const recheckImage = async (event) => {
  const targetImg = event.target;
  if (targetImg.height < 80 || targetImg.width < 80) {
    targetImg.dataset.PordaCondition = "ImgSmall";
    targetImg.style.filter = "none";
    return;
  }
  if (targetImg.naturalHeight > 2 && targetImg.naturalWidth > 2) {
    targetImg.dataset.PordaCondition = "ImgReadyToProcessinrecheck";
    targetImg.dataset.PordaStep = "recheckByEventListning";
    await delay(10);
    sendImgForDetection(targetImg);
  }
  targetImg.removeEventListener("load", recheckImage);
  return;
};
const defaultSettings$1 = {
  pordaAppStatus: true,
  isDetectMale: true,
  isDetectFemale: true,
  isDetectImage: true,
  isDetectVideo: true,
  isObjectCoverBlur: true,
  isObjectCoverColor: false,
  colorPickerValue: "#B4B4B4",
  isRoundBox: true,
  isBgImgColor: false,
  isFullImgBlur: false,
  accuracyScore: "40",
  accuracyScoreNumber: 20,
  isInitiallyImgBlur: true,
  isBlockAllImage: false,
  isFbBlockSponsored: true,
  isFbBlockSuggestPost: false,
  isFbBlockSuggestFriend: true,
  isFbBlockSuggestGroup: false,
  isFbBlockFollowPost: true,
  isFbBlockRealShort: true,
  targetClasses: [0, 1]
};
async function runCommon$1() {
  const settings = defaultSettings$1;
  console.log(settings);
  const hostname = window.location.hostname;
  const isSiteFacebook2 = hostname.includes("fb.com") || hostname.includes("facebook.com");
  updateVariable(isSiteFacebook2);
  console.log("==================", hostname);
  settingsUpdate(settings);
  runObserving();
}
//runCommon$1();
function sendMessageToKotlin(messageType, data) {
  if (window.Android) {
    window.Android.sendMessageFromWebView(messageType, data);
  }
}
function sendMessageToIOS(messageType, data) {
    try {
        webkit.messageHandlers.safegazeMessage.postMessage({"messageType": messageType, "data": data});
    } catch {
      console.log("vdoLog -- error sending message to kotlin");
    }
}
let pordaSettings = [];
const replaceImgSrc = (imageNode, newSrc) => {
  const srcsetAttributesRegex = /.*srcset.*/;
  const srcAttributesRegex = /.*src.*/;
  Array.from(imageNode.attributes).forEach((attr) => {
    if (attr.name === "srcset" || attr.name === "src" || srcsetAttributesRegex.test(attr.name) || srcAttributesRegex.test(attr.name)) {
      imageNode.setAttribute(attr.name, newSrc);
    }
  });
  const pictureElement = imageNode.closest("picture");
  if (pictureElement) {
    const sourceElements = pictureElement.querySelectorAll("source");
    sourceElements.forEach((source) => {
      if (source.hasAttribute("srcset")) {
        source.setAttribute("srcset", newSrc);
      }
      if (source.hasAttribute("data-srcset")) {
        source.setAttribute("data-srcset", newSrc);
      }
    });
  }
  if (imageNode.hasAttributeNS("http://www.w3.org/1999/xlink", "href")) {
    imageNode.setAttributeNS(
      "http://www.w3.org/1999/xlink",
      "href",
      newSrc
    );
  } else if (imageNode.hasAttribute("href")) {
    imageNode.setAttribute("href", newSrc);
    console.log("href", newSrc);
  }
  imageNode.dataset.pordaDone = "true";
  imageNode.dataset.PordaCondition = "Detected";
  imageNode.style.filter = "none";
  imageNode.onload = () => {
    URL.revokeObjectURL(newSrc);
  };
};
function generateTaskIdFromImageSrc(imgSrc) {
  const filename = imgSrc.split("/").pop().split(".")[0]; // extract file name without extension
  const timestamp = Date.now().toString(16); // hex timestamp
  const randomPart = Math.random().toString(16).substring(2, 8); // 6 hex chars
  const taskId = `${filename}-${timestamp}-${randomPart}`;
  return taskId;
}
const updateSettingsImgProcessing = (settings) => {
  pordaSettings = settings;
  receiveMessageFromKotlin("null", "null");
};
const sendImgBackground = (imgInfo) => {
  const imgInfoString = JSON.stringify(imgInfo);
  sendMessageToKotlin("detectImg", imgInfoString);
  sendMessageToIOS("detectImg", imgInfoString);
};
const sendImgForDetection = async (node, imgSrc = null) => {
  try {
    let imgTaskID;
    let nodeSrc;
    if (imgSrc) {
      nodeSrc = imgSrc;
    } else {
      nodeSrc = node.hasAttribute("src") ? node.src : node.getAttribute("srcset");
      if (!nodeSrc) {
        nodeSrc = node.getAttributeNS(
          "http://www.w3.org/1999/xlink",
          "href"
        );
        if (!nodeSrc) {
          nodeSrc = node.getAttribute("href");
        }
      }
    }
    node.dataset.PordaOriginalSrc = nodeSrc;
    imgTaskID = generateTaskIdFromImageSrc(nodeSrc);
    node.dataset.podaTaskId = imgTaskID;
    const shouldDetectImg = pordaSettings.pordaAppStatus && pordaSettings.isDetectImage && (pordaSettings.isDetectMale || pordaSettings.isDetectFemale);
    if (!shouldDetectImg) {
      node.style.filter = "none";
      node.dataset.PordaCondition = "Detection Off";
      return;
    }
    node.dataset.UnderProcessing = "true";
    const imgInfo = {
      src: nodeSrc,
      id: imgTaskID,
      width: node.width,
      height: node.height
    };
    sendImgBackground(imgInfo);
  } catch (e) {
    node.style.filter = "none";
    node.dataset.PordaCondition = "Got Error while processing";
  } finally {
    if (node.dataset.pordaDone) {
      node.style.filter = "none";
    }
  }
};
function receiveMessageFromKotlin(messageType, data) {
  console.log("receiveMessageFromKotlin, ", messageType);
  if (messageType === "detectionResult") {
    setTimeout(() => {
      putCover(data);
    }, 0);
  }
  if (messageType === "videoResult") {
    setTimeout(() => {
      putCoverOnVideoAsResult(data);
    }, 0);
  }
  if (messageType === "settingsUpdate") {
    settingsUpdated(data);
  }
}
const putCover = async (data, insidesettings) => {
  console.log("putCover data, ", data);
  const parsedData = JSON.parse(data);
  console.log("putCover parsedData, ", parsedData);
  const detectionResult = parsedData.result;
  const taskId = parsedData.id;
  console.log("putCover, ", parsedData);
  let node;
  if (detectionResult === "null") {
    node = document.querySelector(`[data-poda-task-id='${taskId}']`);
    if (!node)
      return;
    node.dataset.UnderProcessing = "false";
    node.style.filter = "none";
    return;
  }
  node = document.querySelector(`[data-poda-task-id='${taskId}']`);
  if (!node)
    return;
  replaceImgSrc(node, detectionResult);
  node.dataset.UnderProcessing = "false";
  return;
};
const settingsUpdate = (settings) => {
  updateSettingsImgProcessing(settings);
  updateSettingInObserveNode(settings);
};
const config = {
  childList: true,
  // Observe changes to child nodes
  subtree: true,
  // Observe the entire subtree
  attributes: true,
  // Observe changes to attributes
  //attributeFilter: ['src', 'srcset', 'data-src'],  // Only observe changes to these attributes
  attributeFilter: ["src", "srcset", "data-src", "srcdoc", "id", "name", "title"],
  characterData: false
  // Do not observe text changes
};
const runObserving = () => {
  const observer = new MutationObserver(handleMutations);
  const targetNode = document;
  const initializeObserver = () => {
    if (targetNode) {
      observer.observe(targetNode, config);
    } else {
      console.error("Target node is not valid. Retrying...");
      setTimeout(initializeObserver, 500);
    }
  };
  initializeObserver();
};
function handleMutations(mutationsList, observer) {
  mutationsList.forEach((mutation) => {
    if (mutation.type === "childList") {
      mutation.addedNodes.forEach((childNode) => {
        observeChildNode(childNode);
      });
    } else if (mutation.type === "attributes") {
      const { target, attributeName } = mutation;
      if (target.tagName === "IMG" || target.tagName === "VIDEO") {
        console.log(target.tagName)
        observeElement(target);
      }
    }
  });
}
const defaultSettings = {
  pordaAppStatus: true,
  isDetectMale: true,
  isDetectFemale: true,
  isDetectImage: true,
  isDetectVideo: true,
  isObjectCoverBlur: true,
  isObjectCoverColor: false,
  colorPickerValue: "#B4B4B4",
  isRoundBox: true,
  isBgImgColor: false,
  isFullImgBlur: false,
  accuracyScore: "40",
  accuracyScoreNumber: 20,
  isInitiallyImgBlur: true,
  isBlockAllImage: false,
  isFbBlockSponsored: true,
  isFbBlockSuggestPost: false,
  isFbBlockSuggestFriend: true,
  isFbBlockSuggestGroup: false,
  isFbBlockFollowPost: true,
  isFbBlockRealShort: true,
  targetClasses: [0, 1]
};
async function runCommon() {
  const settings = defaultSettings;
  console.log(settings);
  const hostname = window.location.hostname;
  const isSiteFacebook2 = hostname.includes("fb.com") || hostname.includes("facebook.com");
  updateVariable(isSiteFacebook2);
  console.log("==================", hostname);
  settingsUpdate(settings);
  runObserving();
}
window.receiveMessageFromKotlin = receiveMessageFromKotlin;
runCommon();
