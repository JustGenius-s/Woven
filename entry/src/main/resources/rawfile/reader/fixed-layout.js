/* Fits the original PDF canvas as one unit; never override its text metrics. */
(() => {
  // A few headings and captions use .ff3 for their romanized readings. This
  // font also supplies parentheses before Japanese dialogue, so only hide
  // wholly Latin reading lines. Keep the original boxes and glyph advances.
  document.querySelectorAll('.t.ff3').forEach(line => {
    const text = line.textContent || '';
    if (/[a-zA-Z]/.test(text) && !/[\u3040-\u30ff\u3400-\u9fff]/.test(text)) {
      line.style.setProperty('visibility', 'hidden', 'important');
      line.setAttribute('aria-hidden', 'true');
    }
  });

  const fitPage = () => {
    const page = document.querySelector('.pf');
    const container = document.getElementById('page-container');
    if (!page || !container) return;
    const width = page.offsetWidth;
    const height = page.offsetHeight;
    const viewportWidth = document.documentElement.clientWidth;
    const viewportHeight = document.documentElement.clientHeight;
    const scale = Math.min(viewportWidth / width, viewportHeight / height);
    Object.assign(container.style, {
      width: `${width}px`, height: `${height}px`,
      left: `${Math.max(0, (viewportWidth - width * scale) / 2)}px`,
      top: `${Math.max(0, (viewportHeight - height * scale) / 2)}px`,
      transform: `scale(${scale})`
    });
  };
  window.addEventListener('resize', fitPage);
  window.addEventListener('load', fitPage);
  document.fonts.ready.then(fitPage);
  fitPage();
})();
