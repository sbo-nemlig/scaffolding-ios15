<script>
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import ThemeToggle from '$lib/ThemeToggle.svelte';
  import { GITHUB_URL } from '$lib/links.js';

  let isDocs = $derived(page.route?.id === '/docs');
  let isHome = $derived(page.route?.id === '/');
</script>

<header class="hdr">
  <a href={`${base}/`} class="brand" aria-label="Scaffolding home" aria-current={isHome ? 'page' : undefined}>
    <span class="brand-mark" aria-hidden="true">[ ]</span>
    <span class="brand-name">Scaffolding</span>
  </a>
  <nav class="nav">
    <a href={`${base}/docs`} class:active={isDocs} aria-current={isDocs ? 'page' : undefined}>Docs</a>
    <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
    <ThemeToggle />
  </nav>
</header>

<style>
  .hdr {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.5rem clamp(1.25rem, 4vw, 3rem);
    border-bottom: 1px solid var(--line-soft);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    background: var(--header-bg);
    position: sticky;
    top: 0;
    z-index: 10;
    /* Promote to its own compositor layer so the backdrop-filter blur
       does not force a full re-paint on every scroll frame, which is
       what causes the flicker on Chromium/Safari sticky headers. */
    will-change: backdrop-filter;
    transform: translateZ(0);
    transition: background-color 220ms ease, border-color 220ms ease;
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 0.65rem;
    font-size: 14px;
    letter-spacing: -0.005em;
    text-decoration: none;
    color: inherit;
  }

  .brand-mark {
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.05em;
  }

  .brand-name {
    color: var(--fg);
    font-weight: 500;
  }

  .nav {
    display: flex;
    align-items: center;
    gap: 1.4rem;
    font-size: 13px;
    color: var(--muted);
  }

  .nav a {
    text-decoration: none;
    color: inherit;
    transition: color 120ms ease, border-color 120ms ease;
    border-bottom: 1px solid transparent;
    padding-bottom: 1px;
  }

  .nav a:hover,
  .nav a.active {
    color: var(--fg);
    border-bottom-color: color-mix(in srgb, var(--fg) 40%, transparent);
  }
</style>
