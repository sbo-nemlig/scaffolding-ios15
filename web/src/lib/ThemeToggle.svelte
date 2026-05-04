<script>
  import { onMount } from 'svelte';

  let theme = $state('dark');

  onMount(() => {
    const initial = document.documentElement.getAttribute('data-theme') || 'dark';
    theme = initial;
  });

  function toggle() {
    const next = theme === 'dark' ? 'light' : 'dark';
    theme = next;
    document.documentElement.setAttribute('data-theme', next);
    try {
      localStorage.setItem('scaffolding-theme', next);
    } catch (_) {
      /* storage may be unavailable */
    }
  }

  let label = $derived(theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
</script>

<button
  type="button"
  class="toggle"
  onclick={toggle}
  aria-label={label}
  title={label}
  data-theme={theme}
>
  <span class="track" aria-hidden="true">
    <span class="dot dot-dark"></span>
    <span class="dot dot-light"></span>
    <span class="thumb"></span>
  </span>
</button>

<style>
  .toggle {
    display: inline-flex;
    align-items: center;
    padding: 0;
    border: 0;
    background: transparent;
    cursor: pointer;
  }

  .track {
    position: relative;
    width: 38px;
    height: 20px;
    border-radius: 999px;
    border: 1px solid var(--line);
    background: var(--surface);
    transition: border-color 160ms ease, background-color 160ms ease;
  }

  .toggle:hover .track {
    border-color: color-mix(in srgb, var(--fg) 35%, transparent);
  }

  .dot {
    position: absolute;
    top: 50%;
    width: 4px;
    height: 4px;
    border-radius: 50%;
    transform: translateY(-50%);
    background: var(--fg);
    opacity: 0.5;
    transition: opacity 160ms ease;
  }
  .dot-dark { left: 6px; }
  .dot-light { right: 6px; }

  .toggle[data-theme='dark'] .dot-dark { opacity: 1; }
  .toggle[data-theme='light'] .dot-light { opacity: 1; }

  .thumb {
    position: absolute;
    top: 1px;
    left: 1px;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--fg);
    transition: transform 180ms cubic-bezier(0.2, 0.7, 0.3, 1);
  }

  .toggle[data-theme='light'] .thumb {
    transform: translateX(18px);
  }
</style>
