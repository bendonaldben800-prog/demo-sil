const detectedLabel = document.getElementById("detectedLabel");
const downloadBtn = document.getElementById("downloadBtn");
const platformSelect = document.getElementById("platformSelect");
const manualApply = document.getElementById("manualApply");
const downloadList = document.getElementById("downloadList");
const checksumList = document.getElementById("checksumList");

function detectPlatformKey() {
  const ua = navigator.userAgent || "";
  const platform = navigator.platform || "";

  const looksLikeWindows = /Win/i.test(platform) || /Windows/i.test(ua);
  const looksLikeMac = /Mac/i.test(platform) || /Macintosh|Mac OS X/i.test(ua);
  const looksLikeArm = /ARM|AArch64|arm64/i.test(ua);

  if (looksLikeWindows) {
    return looksLikeArm ? "windows-arm64" : "windows-x64";
  }

  if (looksLikeMac) {
    return looksLikeArm ? "macos-arm64" : "macos-intel";
  }

  return "";
}

function setPrimaryDownload(key, manifest) {
  const item = manifest.downloads[key];
  if (!item) {
    detectedLabel.textContent = "Could not detect your exact platform. Please choose manually.";
    downloadBtn.textContent = "Select a platform";
    downloadBtn.href = "#";
    downloadBtn.setAttribute("aria-disabled", "true");
    return;
  }

  detectedLabel.textContent = `Detected: ${item.label}`;
  downloadBtn.textContent = `Download for ${item.label}`;
  downloadBtn.href = item.url;
  downloadBtn.removeAttribute("aria-disabled");
}

function renderManifestLists(manifest) {
  const entries = Object.entries(manifest.downloads);

  downloadList.innerHTML = "";
  checksumList.innerHTML = "";

  for (const [key, item] of entries) {
    const downloadLi = document.createElement("li");
    const link = document.createElement("a");
    link.href = item.url;
    link.textContent = item.label;
    link.setAttribute("data-platform", key);
    downloadLi.appendChild(link);
    downloadList.appendChild(downloadLi);

    const checksumLi = document.createElement("li");
    checksumLi.textContent = `${item.label}: ${item.checksum}`;
    checksumList.appendChild(checksumLi);
  }
}

async function init() {
  const response = await fetch("manifest.json", { cache: "no-store" });
  if (!response.ok) {
    detectedLabel.textContent = "Unable to load download manifest.";
    return;
  }

  const manifest = await response.json();
  renderManifestLists(manifest);

  const autoKey = detectPlatformKey();
  setPrimaryDownload(autoKey, manifest);

  manualApply.addEventListener("click", () => {
    const key = platformSelect.value;
    setPrimaryDownload(key, manifest);
  });
}

init().catch(() => {
  detectedLabel.textContent = "Unable to initialize platform detection.";
});
