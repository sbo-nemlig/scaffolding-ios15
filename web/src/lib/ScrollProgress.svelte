<script>
  const DEFAULT_SECTIONS = [
    { id: 'hero',       label: 'Intro' },
    { id: 'examples',   label: 'API' },
    { id: 'arch',       label: 'Architecture' },
    { id: 'play',       label: 'Playground' },
    { id: 'features',   label: 'Features' }
  ];

  let { sections = DEFAULT_SECTIONS } = $props();

  let activeIndex = $state(0);

  $effect(() => {
    // Re-resolve element list whenever the `sections` prop changes.
    const els = sections
      .map((s) => ({ s, el: document.getElementById(s.id) }))
      .filter((x) => x.el);

    if (els.length === 0) return;

    // Active section = the one whose center is closest to the viewport center.
    function recompute() {
      const mid = window.innerHeight / 2;
      let bestIdx = 0;
      let bestDist = Infinity;
      els.forEach(({ s, el }) => {
        const r = el.getBoundingClientRect();
        const center = r.top + r.height / 2;
        const dist = Math.abs(center - mid);
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = sections.findIndex((x) => x.id === s.id);
        }
      });
      // Only assign when the index actually changes — avoids unnecessary
      // re-renders mid-scroll, which contribute to the flicker.
      if (bestIdx !== activeIndex) activeIndex = bestIdx;
    }

    recompute();
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        recompute();
      });
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', recompute);

    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', recompute);
      if (raf) cancelAnimationFrame(raf);
    };
  });

  function go(id) {
    const el = document.getElementById(id);
    el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
</script>

<nav class="prog" aria-label="Page sections">
  <span class="rail" aria-hidden="true"></span>
  <span
    class="rail-fill"
    aria-hidden="true"
    style="--p: {sections.length > 1 ? activeIndex / (sections.length - 1) : 0}"
  ></span>

  {#each sections as s, i}
    <a
      class="step"
      class:active={i === activeIndex}
      class:passed={i < activeIndex}
      href={`#${s.id}`}
      aria-current={i === activeIndex ? 'true' : undefined}
      onclick={(e) => { e.preventDefault(); go(s.id); }}
    >
      <span class="label">{s.label}</span>
      <span class="tick" aria-hidden="true"></span>
    </a>
  {/each}
</nav>

<style>
  .prog {
    position: fixed;
    right: 1.4rem;
    /* `svh` is the *small* viewport height — locked when the URL bar is
       fully expanded — which keeps the rail steady on iOS as the URL bar
       hides/shows during scroll. `vh` falls back if the unit is unknown. */
    top: 50vh;
    top: 50svh;
    transform: translate3d(0, -50%, 0);
    display: flex;
    flex-direction: column;
    gap: 1.4rem;
    z-index: 20;
    padding: 0.5rem 0;
    /* Promote the whole rail to its own compositor layer. Avoids
       per-frame re-paints when sibling content scrolls underneath. */
    will-change: transform;
    backface-visibility: hidden;
  }

  /* Rail: a vertical line behind the dots. */
  .rail,
  .rail-fill {
    position: absolute;
    /* Stand the rail behind the ticks (tick is 8px wide → +4px from the
       right edge of the column gives perfect centering). */
    right: 4px;
    top: 0.55rem;
    bottom: 0.55rem;
    width: 1px;
    border-radius: 1px;
  }

  .rail {
    background: color-mix(in srgb, var(--fg) 18%, transparent);
  }

  .rail-fill {
    background: color-mix(in srgb, var(--fg) 70%, transparent);
    transform-origin: top;
    transform: scaleY(var(--p, 0));
    transition: transform 220ms cubic-bezier(0.2, 0.7, 0.3, 1);
  }

  .step {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.7rem;
    text-decoration: none;
    color: inherit;
    /* Make the whole row a generous click target without blocking the rail. */
    padding: 0.15rem 0;
  }

  .tick {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: var(--bg);
    border: 1px solid color-mix(in srgb, var(--fg) 35%, transparent);
    flex-shrink: 0;
    transition:
      background-color 200ms ease,
      border-color 200ms ease,
      transform 200ms cubic-bezier(0.2, 0.7, 0.3, 1);
  }

  .step.passed .tick {
    background: color-mix(in srgb, var(--fg) 70%, transparent);
    border-color: color-mix(in srgb, var(--fg) 70%, transparent);
  }

  .step.active .tick {
    background: var(--fg);
    border-color: var(--fg);
    transform: scale(1.4);
  }

  /* Labels are always visible but greyed out for inactive steps —
     hover, focus, active, and passed states tighten the colour. */
  .label {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.06em;
    color: color-mix(in srgb, var(--fg) 28%, transparent);
    transition: color 200ms ease;
    white-space: nowrap;
  }

  .step.passed .label {
    color: color-mix(in srgb, var(--fg) 50%, transparent);
  }

  .step:hover .label,
  .step:focus-visible .label,
  .step.active .label {
    color: var(--fg);
  }

  .step:focus-visible {
    outline: none;
  }

  .step:focus-visible .tick {
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--fg) 30%, transparent);
  }

  /* Mid-width viewports (laptops ~1100–1340) have just enough room for
     the rail's ticks but not the labels — collapse to ticks only so
     the labels don't overlap the article column. */
  @media (max-width: 1340px) {
    .label { display: none; }
  }
  @media (max-width: 1100px) {
    .prog { display: none; }
  }
</style>
