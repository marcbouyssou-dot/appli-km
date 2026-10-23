// PDF.js est livré localement (legacy Safari), sans CDN ni upload du document.
import { getDocument, GlobalWorkerOptions } from './vendor/pdf.min.mjs';
GlobalWorkerOptions.workerSrc = new URL('./vendor/pdf.worker.min.mjs', import.meta.url).href;
const canvas = document.querySelector('#page');
const viewport = document.querySelector('#viewport');
const status = document.querySelector('#status');
const pageNumber = document.querySelector('#page-number');
const previous = document.querySelector('#previous');
const next = document.querySelector('#next');
const zoomIn = document.querySelector('#zoom-in');
const zoomOut = document.querySelector('#zoom-out');
let pdf, page = 1, zoom = 1, rendering = false, pending = false, currentPage;
const send = (type) => parent.postMessage({ type }, location.origin);
function controls() {
  previous.disabled = !pdf || page <= 1;
  next.disabled = !pdf || page >= pdf.numPages;
  zoomOut.disabled = !pdf || zoom <= 1;
  zoomIn.disabled = !pdf || zoom >= 2.5;
}
async function render() {
  if (!pdf) return;
  if (rendering) { pending = true; return; }
  rendering = true;
  controls();
  try {
    currentPage?.cleanup();
    const renderedPage = page;
    currentPage = await pdf.getPage(renderedPage);
    const base = currentPage.getViewport({ scale: 1 });
    const scale = Math.max(.1, (viewport.clientWidth - 20) / base.width) * zoom;
    const view = currentPage.getViewport({ scale });
    // Une seule page, résolution adaptée et mémoire bornée sur iPhone.
    const ratio = Math.min(devicePixelRatio || 1, 2, Math.sqrt(8e6 / (view.width * view.height)));
    canvas.width = Math.ceil(view.width * ratio);
    canvas.height = Math.ceil(view.height * ratio);
    canvas.style.width = `${view.width}px`;
    canvas.style.height = `${view.height}px`;
    canvas.hidden = false;
    await currentPage.render({
      canvasContext: canvas.getContext('2d'),
      viewport: view,
      transform: [ratio, 0, 0, ratio, 0, 0],
    }).promise;
    canvas.setAttribute('aria-label', `Page ${renderedPage} sur ${pdf.numPages}`);
    pageNumber.textContent = `${renderedPage} / ${pdf.numPages}`;
    status.textContent = '';
    send('meskm-pdf-rendered');
  } catch (error) {
    status.textContent = 'Impossible d’afficher l’aperçu. Revenez au document et réessayez.';
    console.error('PDF preview render failed', error);
  } finally {
    rendering = false;
    if (pending) { pending = false; render(); }
  }
}
previous.addEventListener('click', () => { if (page > 1) { page--; viewport.scrollTo(0, 0); render(); } });
next.addEventListener('click', () => { if (pdf && page < pdf.numPages) { page++; viewport.scrollTo(0, 0); render(); } });
zoomIn.addEventListener('click', () => { zoom = Math.min(2.5, zoom + .5); render(); });
zoomOut.addEventListener('click', () => { zoom = Math.max(1, zoom - .5); render(); });
let resizeTimer;
new ResizeObserver(() => { clearTimeout(resizeTimer); resizeTimer = setTimeout(render, 100); }).observe(viewport);
window.addEventListener('message', async (event) => {
  if (event.source !== parent || event.origin !== location.origin ||
      event.data?.type !== 'meskm-pdf-document' || pdf) return;
  try {
    pdf = await getDocument({
      data: event.data.bytes,
      isEvalSupported: false,
      useSystemFonts: false,
      // Les PDF Mes Km intègrent leurs polices ; aucune ressource distante.
    }).promise;
    await render();
  } catch (error) {
    status.textContent = 'Impossible d’ouvrir l’aperçu. Revenez au document et réessayez.';
    console.error('PDF preview load failed', error);
  }
});
send('meskm-pdf-ready');
