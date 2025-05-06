console.log(
  "PordaAi is running, Code and Ai Model are under copyright, Unauthorized use, reproduction, or distribution of any part of this project is strictly prohibited - pordaai.com "
);

function sendMessageToKotlin(messageType, data) {
  if (window.Android) {
    window.Android.sendMessageFromWebView(messageType, data);
  }
  else{
     try {
          webkit.messageHandlers.safegazeMessage.postMessage({"messageType": messageType, "data": data});
      } catch {
        console.log("vdoLog -- error sending message to kotlin");
        }
        }

}
if (!window.Android){
window.receiveMessageFromKotlin = receiveMessageFromKotlin;
}

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
const img = new Image();
const replaceImgOnVideo = (ctx, base64Image) => {
  console.log(base64Image.substring(0, 20));
  img.src = base64Image;
  img.onload = () => {
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.drawImage(img, 0, 0, ctx.canvas.width, ctx.canvas.height);
  };
  img.onerror = () => {
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
    startsCaptutingVideo(node);
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
  imageNode.onload = () => {
    imageNode.style.filter = "none";
    URL.revokeObjectURL(newSrc);
  };
};
function generateTaskIdFromImageSrc(imgSrc) {
  return crypto.randomUUID();
}
const sendImgBackground = (imgInfo) => {
  const imgInfoString = JSON.stringify(imgInfo);
  sendMessageToKotlin("detectImg", imgInfoString);
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
    if (!nodeSrc) {
      const picture = node.closest("picture");
      if (picture) {
        const sources = picture.querySelectorAll("source");
        for (let source of sources) {
          const srcset = source.getAttribute("srcset");
          if (srcset) {
            nodeSrc = srcset.split(",")[0].trim().split(" ")[0];
            if (nodeSrc) {
              node.dataset.PordaOriginalSrc = nodeSrc;
            } else {
              node.dataset.PordaOriginalSrc = "src not found";
              node.style.filter = "none";
            }
          }
        }
      }
    }
    node.dataset.PordaOriginalSrc = nodeSrc;
    if (!(node == null ? void 0 : node.dataset.podaTaskId)) {
      imgTaskID = generateTaskIdFromImageSrc();
      node.dataset.podaTaskId = imgTaskID;
    }
    let base64Image;
    node.dataset.UnderProcessing = "true";
    if (!nodeSrc.startsWith("data:image")) {
      base64Image = await generateBase64Image(
        nodeSrc,
        node.width,
        node.height
      );
    } else {
      base64Image = "none";
    }
    const imgInfo = {
      src: nodeSrc,
      baseImg: base64Image,
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
const generateBase64Image = async (nodeSrc, nodeWidth, nodeHeight) => {
  try {
//    return "none";
    const img2 = new Image();
    img2.crossOrigin = "anonymous";
    const loadImage = new Promise((resolve, reject) => {
      img2.onload = () => resolve();
      img2.onerror = () => reject();
      img2.src = nodeSrc;
    });
    await loadImage;
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");
    const aspectRatio = img2.width / img2.height;
    canvas.width = nodeWidth / nodeHeight > aspectRatio ? nodeHeight * aspectRatio : nodeWidth;
    canvas.height = nodeWidth / nodeHeight > aspectRatio ? nodeWidth / aspectRatio : nodeHeight;
    ctx.drawImage(img2, 0, 0, canvas.width, canvas.height);
    const base64Image = canvas.toDataURL("image/jpeg", 0.7);
    canvas.width = 0;
    canvas.height = 0;
    canvas = null;
    return base64Image;
  } catch (error) {
    return "none";
  }
};
function receiveMessageFromKotlin(messageType, data) {
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
}
receiveMessageFromKotlin("demo", "dfd");
const putCover = async (data) => {
  const parsedData = JSON.parse(data);
  const detectionResult = parsedData.result;
  const taskId = parsedData.id;
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
  if (detectionResult === "nsfw") {
    node.classList.add("porda-filter-nsfw");
    return;
  }
  replaceImgSrc(node, detectionResult);
  node.dataset.UnderProcessing = "false";
  return;
};
let isSiteFacebook = false;
const observeChildNode = async (childNode) => {
  if (childNode.nodeType === Node.ELEMENT_NODE) {
    const imagesAndVideosAndIframes = childNode.querySelectorAll(
      "img, video, svg image"
    );
    imagesAndVideosAndIframes.forEach((element) => {
      observeElement(element);
    });
  }
};
const observeElement = (node) => {
  var _a, _b, _c, _d, _e, _f;
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
  if (node.tagName.toLowerCase() === "image" && node.namespaceURI === "http://www.w3.org/2000/svg") {
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
  if (img2.dataset.pordaDone)
    return;
  if (img2.dataset.PordaResult)
    return;
  let imgSrc = img2.hasAttribute("src") ? img2.src : img2.getAttribute("srcset");
  if (imgSrc && (imgSrc.startsWith("data:image/svg+xml") || imgSrc.match(/\.(svg|gif)(\?|$)/i))) {
    img2.classList.add("porda-no-filter");
    img2.dataset.PordaCondition = "Img svg or gif";
    img2.dataset.pordaGifSrc = imgSrc;
    return;
  }
  const hasBlur = (img3) => {
    const computedStyle = window.getComputedStyle(img3);
    return computedStyle.filter.includes("blur");
  };
  if (!hasBlur(img2)) {
    img2.classList.add("porda-filter");
  }
  if (!imgSrc) {
    imgSrc = img2.getAttributeNS("http://www.w3.org/1999/xlink", "href");
    if (!imgSrc) {
      imgSrc = img2.getAttribute("href");
    }
  }
  if (img2.naturalHeight < 2 || img2.naturalWidth < 2) {
    img2.addEventListener("load", recheckImage);
    return;
  } else if (img2.height < 40 || img2.width < 40) {
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
  if (targetImg.height < 40 || targetImg.width < 40) {
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
const config = {
  childList: true,
  // Observe changes to child nodes
  subtree: true,
  // Observe the entire subtree
  attributes: true,
  // Observe changes to attributes
  //attributeFilter: ['src', 'srcset', 'data-src'],  // Only observe changes to these attributes
  attributeFilter: [
    "src",
    "srcset",
    "data-src",
    "srcdoc",
    "id",
    "name",
    "title"
  ],
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
        observeElement(target);
      }
    }
  });
}
const intervalChecking = async () => {
  const images = document.querySelectorAll(
    "img:not([data--porda-condition])"
  );
  images.forEach((img2) => {
    if (!img2.dataset.PordaCondition) {
      observeImgNode(img2);
    }
  });
};
setTimeout(() => {
  setInterval(intervalChecking, 2500);
  intervalChecking();
}, 10);
const style = document.createElement("style");
style.textContent = `
  img {
    filter: blur(40px) grayscale(10%);
  }
    img.porda-filter{
    filter: blur(40px) grayscale(10%);
    }
  img.porda-no-filter {
    filter: none !important;
  }
    img.porda-filter-nsfw {
    filter: blur(40px) sepia(100%) saturate(500%) hue-rotate(-50deg);
  }
`;
document.documentElement.appendChild(style);
console.log(
  "PordaAi is running, Code and Ai Model are under copyright, Unauthorized use, reproduction, or distribution of any part of this project is strictly prohibited - pordaai.com "
);
async function runCommon() {
  const hostname = window.location.hostname;
  console.log("==================", hostname);
  runObserving();
}
runCommon();

