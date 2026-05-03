<script>
  import { base } from '$app/paths';
  import { GITHUB_URL } from '$lib/links.js';
</script>

<footer class="ftr">
  <span>MIT License</span>
  <span class="ftr-sep" aria-hidden="true">·</span>
  <span>Built with Swift &amp; Svelte</span>
  <span class="ftr-sep" aria-hidden="true">·</span>
  <a href={`${base}/docs`}>Docs</a>
  <span class="ftr-sep" aria-hidden="true">·</span>
  <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>
</footer>

<style>
  .ftr {
    position: relative;
    z-index: 1;
    border-top: 1px solid var(--line-soft);
    padding: 2rem clamp(1.25rem, 4vw, 3rem);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
    gap: 0.75rem;
    color: var(--dim);
    font-size: 12px;
  }

  .ftr a {
    color: var(--muted);
    border-bottom: 1px solid transparent;
    text-decoration: none;
    transition: color 120ms ease, border-color 120ms ease;
  }

  .ftr a:hover {
    color: var(--fg);
    border-bottom-color: color-mix(in srgb, var(--fg) 30%, transparent);
  }

  .ftr-sep {
    opacity: 0.5;
  }
</style>
