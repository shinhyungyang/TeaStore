/*
 * Resizes the iFrame height when the page changes
 *
 * @author Gines Moratalla
 *
 * */

// Initialize Zoom
let zoom = window.devicePixelRatio;
let offset = 0;

const iframe = document.getElementById('pdf-viewer');

function isChangedZoom() {
  const currentZoom = window.devicePixelRatio;
  if (currentZoom !== zoom) {
    console.log('Zoom changed. Old: ', zoom, 'New: ', currentZoom);
    let height = newHeight(zoom, currentZoom);
    resizeIframe(height);
    zoom = currentZoom;
  }
}

function newHeight(zoom, currentZoom) {
  if (zoom - currentZoom >= 0) {
    offset = 1.7;
  } else {
    offset = 2.5;
  }
  height = 800 + ((zoom - currentZoom) * 800 * offset);
  console.log('New Height:', height);
  return height;
}

function resizeIframe(newHeight) {
  iframe.style.height = newHeight + 'px';
  console.log('Resizing iframe to:', iframe.style.height);
}

resizeIframe();

// Adjust height with window listener
window.addEventListener('resize', isChangedZoom);
