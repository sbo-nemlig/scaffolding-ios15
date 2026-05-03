<script>
  let canvas = $state(null);

  // Grid + interaction params (in CSS pixels).
  const SPACING = 28;
  const DOT_BASE_RADIUS = 1;
  const DOT_PEAK_RADIUS = 1.25;
  const INFLUENCE_RADIUS = 120;

  let mouseX = -10000;
  let mouseY = -10000;
  let targetX = -10000;
  let targetY = -10000;

  $effect(() => {
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = 0;
    let height = 0;
    let dpr = 1;
    let raf;

    let dotRgb = '255, 255, 255';
    let baseAlpha = 0.07;
    let peakAlpha = 0.85;
    let lastMoveAt = 0;
    let needsRedraw = true;

    const readThemeFromCSS = () => {
      const cs = getComputedStyle(document.documentElement);
      const rgb = cs.getPropertyValue('--dot-rgb').trim();
      const base = parseFloat(cs.getPropertyValue('--dot-base-alpha'));
      const peak = parseFloat(cs.getPropertyValue('--dot-peak-alpha'));
      if (rgb) dotRgb = rgb;
      if (!Number.isNaN(base)) baseAlpha = base;
      if (!Number.isNaN(peak)) peakAlpha = peak;
    };

    const resize = () => {
      width = window.innerWidth;
      height = window.innerHeight;
      dpr = window.devicePixelRatio || 1;
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      wake();
    };

    const wake = () => {
      lastMoveAt = performance.now();
      needsRedraw = true;
      if (!raf) raf = requestAnimationFrame(draw);
    };

    const onPointerMove = (e) => {
      targetX = e.clientX;
      targetY = e.clientY;
      wake();
    };

    const onPointerLeave = () => {
      targetX = -10000;
      targetY = -10000;
      wake();
    };

    const draw = () => {
      // Ease toward the target position.
      const prevX = mouseX;
      const prevY = mouseY;
      mouseX += (targetX - mouseX) * 0.18;
      mouseY += (targetY - mouseY) * 0.18;

      // Idle if the cursor target hasn't moved recently *and* the eased
      // position has converged. Once idle, stop scheduling new frames so
      // the canvas stops repainting — which lets the sticky header's
      // `backdrop-filter` settle instead of recomputing every frame.
      const dxMoved = Math.abs(prevX - mouseX) + Math.abs(prevY - mouseY);
      const idle =
        dxMoved < 0.05 &&
        performance.now() - lastMoveAt > 250;

      if (!needsRedraw && idle) {
        raf = 0;
        return;
      }

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, height);

      const r2 = INFLUENCE_RADIUS * INFLUENCE_RADIUS;
      const startX = SPACING / 2;
      const startY = SPACING / 2;

      for (let y = startY; y < height; y += SPACING) {
        for (let x = startX; x < width; x += SPACING) {
          const dx = mouseX - x;
          const dy = mouseY - y;
          const d2 = dx * dx + dy * dy;

          let influence = 0;
          if (d2 < r2) {
            const t = 1 - d2 / r2;
            influence = t * t;
          }

          const alpha = baseAlpha + influence * (peakAlpha - baseAlpha);
          const radius = DOT_BASE_RADIUS + influence * (DOT_PEAK_RADIUS - DOT_BASE_RADIUS);

          ctx.beginPath();
          ctx.fillStyle = `rgba(${dotRgb}, ${alpha})`;
          ctx.arc(x, y, radius, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      needsRedraw = false;
      raf = requestAnimationFrame(draw);
    };

    readThemeFromCSS();
    resize();

    // Re-read CSS vars whenever the theme attribute flips, then wake the
    // canvas for one repaint with the new colors.
    const themeObserver = new MutationObserver(() => {
      readThemeFromCSS();
      wake();
    });
    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme']
    });

    window.addEventListener('resize', resize);
    window.addEventListener('pointermove', onPointerMove, { passive: true });
    document.addEventListener('mouseleave', onPointerLeave);
    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      themeObserver.disconnect();
      window.removeEventListener('resize', resize);
      window.removeEventListener('pointermove', onPointerMove);
      document.removeEventListener('mouseleave', onPointerLeave);
    };
  });
</script>

<canvas bind:this={canvas} class="dot-grid" aria-hidden="true"></canvas>

<style>
  .dot-grid {
    position: fixed;
    inset: 0;
    width: 100%;
    height: 100%;
    z-index: 0;
    pointer-events: none;
    mask-image: radial-gradient(
      ellipse at center,
      var(--grid-mask-stop-1) 55%,
      var(--grid-mask-stop-2) 90%,
      transparent 100%
    );
    -webkit-mask-image: radial-gradient(
      ellipse at center,
      var(--grid-mask-stop-1) 55%,
      var(--grid-mask-stop-2) 90%,
      transparent 100%
    );
  }
</style>
