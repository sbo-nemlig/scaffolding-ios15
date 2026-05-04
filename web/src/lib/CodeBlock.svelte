<script>
  import { highlight } from '$lib/swift-highlight.js';

  let { code = '', label = '' } = $props();

  let html = $derived(highlight(code));

  let copied = $state(false);
  let copyTimer;

  async function copy() {
    try {
      await navigator.clipboard.writeText(code);
      copied = true;
      clearTimeout(copyTimer);
      copyTimer = setTimeout(() => (copied = false), 1400);
    } catch (_) {
      // Clipboard may be unavailable (insecure context, denied permission).
      copied = false;
    }
  }
</script>

<figure class="block">
  <div class="bar">
    {#if label}
      <span class="label">{label}</span>
    {:else}
      <span class="label dim">swift</span>
    {/if}
    <button
      type="button"
      class="copy"
      onclick={copy}
      aria-label="Copy code to clipboard"
    >
      {copied ? 'Copied' : 'Copy'}
    </button>
  </div>
  <pre><code>{@html html}</code></pre>
</figure>

<style>
  .block {
    margin: 0;
    border: 1px solid var(--code-line);
    background: var(--code-bg);
    border-radius: 6px;
    overflow: hidden;
    transition: border-color 220ms ease, background-color 220ms ease;
  }

  .bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    padding: 0.55rem 0.85rem 0.55rem 1.1rem;
    border-bottom: 1px solid var(--code-line);
    background: color-mix(in srgb, var(--code-bg) 92%, var(--fg) 8%);
  }

  .label {
    font-size: 11px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--dim);
  }

  .label.dim {
    color: color-mix(in srgb, var(--code-fg) 45%, transparent);
  }

  .copy {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.04em;
    color: color-mix(in srgb, var(--code-fg) 70%, transparent);
    border: 1px solid var(--code-line);
    border-radius: 3px;
    padding: 0.2rem 0.55rem;
    background: transparent;
    cursor: pointer;
    transition: color 140ms ease, border-color 140ms ease, background-color 140ms ease;
  }

  .copy:hover {
    color: var(--code-fg);
    border-color: color-mix(in srgb, var(--code-fg) 30%, transparent);
    background: color-mix(in srgb, var(--code-fg) 6%, transparent);
  }

  pre {
    margin: 0;
    padding: 1.15rem 1.25rem 1.25rem;
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.7;
    overflow-x: auto;
    color: var(--code-fg);
    tab-size: 4;
    -moz-tab-size: 4;
  }

  /* Theme-aware syntax tokens (Xcode-inspired). */
  :global(.kw)  { color: var(--syn-kw); font-weight: 500; }
  :global(.ty)  { color: var(--syn-ty); }
  :global(.att) { color: var(--syn-att); }
  :global(.fn)  { color: var(--syn-fn); }
  :global(.mem) { color: var(--syn-mem); }
  :global(.lab) { color: var(--syn-lab); }
  :global(.id)  { color: var(--syn-id); }
  :global(.num) { color: var(--syn-num); }
  :global(.str) { color: var(--syn-str); }
  :global(.cmt) { color: var(--syn-cmt); font-style: italic; }
  :global(.op)  { color: var(--syn-op); }
</style>
