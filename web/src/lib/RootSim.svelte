<script>
  import { fade } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  import PhoneFrame from '$lib/PhoneFrame.svelte';

  /**
   * Mini simulator for a RootCoordinator. Shows one of N "roots" at a
   * time, animated with a cross-fade — the same atomic swap that
   * `setRoot(_:)` performs on a real RootCoordinatable.
   */
  let {
    coordName = 'AppCoordinator',
    roots = [],         // { id, screen: { title, body?, list? } }
    initial = '',
    actions = [],
    showState = false,
    showConsole = false
  } = $props();

  let activeRoot = $state(initial || roots[0]?.id || '');
  let log = $state([]);
  let counter = 0;
  const nid = () => `l-${++counter}`;

  function logCall(code) {
    log = [...log, { id: nid(), code }];
    if (log.length > 5) log = log.slice(-5);
  }

  const ctx = {
    setRoot(id) {
      if (activeRoot === id) return false;
      activeRoot = id;
      return true;
    },
    get root() { return activeRoot; }
  };

  function run(action) {
    if (typeof action.fn === 'function') action.fn(ctx);
    logCall(action.code);
  }

  let activeScreen = $derived(roots.find((r) => r.id === activeRoot)?.screen ?? null);
</script>

<div class="sim">
  <PhoneFrame size="compact">
    {#key activeRoot}
      <div class="screen-area" in:fade={{ duration: 280, easing: cubicOut }}>
        <div class="screen-content">
          {#if activeScreen}
            <h4>{activeScreen.title}</h4>
            {#if activeScreen.body}<p>{activeScreen.body}</p>{/if}
            {#if activeScreen.list}
              <ul class="list">
                {#each activeScreen.list as line}
                  <li>{line}</li>
                {/each}
              </ul>
            {/if}
          {/if}
        </div>
      </div>
    {/key}
  </PhoneFrame>

  <div class="action-strip">
    {#each actions as a}
      <button class="action" type="button" onclick={() => run(a)}>
        <code>{a.code}</code>
        {#if a.hint}<span class="hint">{a.hint}</span>{/if}
      </button>
    {/each}
  </div>

  {#if showState}
    <div class="state">
      <span class="k">{coordName}.root</span>
      <code>.{activeRoot}</code>
    </div>
  {/if}

  {#if showConsole}
    <ol class="console" class:empty={log.length === 0}>
      {#if log.length === 0}
        <li class="muted"><code>// run an action</code></li>
      {/if}
      {#each log as entry (entry.id)}
        <li><code><span class="prompt">›</span>{coordName.toLowerCase()}.{entry.code}</code></li>
      {/each}
    </ol>
  {/if}
</div>

<style>
  .sim {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    align-items: stretch;
    width: clamp(200px, 32vw, 260px);
  }

  .screen-area {
    position: absolute;
    inset: 0;
    background: var(--bg);
  }

  .screen-content {
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    height: 100%;
  }
  .screen-content h4 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 14.5px;
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.01em;
  }
  .screen-content p {
    margin: 0;
    font-size: 11.5px;
    line-height: 1.5;
    color: color-mix(in srgb, var(--fg) 60%, transparent);
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .list li {
    padding: 6px 8px;
    border-radius: 5px;
    font-size: 11.5px;
    color: color-mix(in srgb, var(--fg) 80%, transparent);
    background: color-mix(in srgb, var(--fg) 5%, transparent);
    border: 1px solid color-mix(in srgb, var(--fg) 8%, transparent);
  }

  /* Action / state / console — shared with the other sims. */
  .action-strip {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  .action {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.55rem 0.75rem;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--bg);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.3;
    text-align: left;
    cursor: pointer;
    transition: border-color 140ms ease, background-color 140ms ease, transform 100ms ease;
  }
  .action:hover {
    border-color: color-mix(in srgb, var(--fg) 35%, transparent);
    background: color-mix(in srgb, var(--fg) 4%, var(--bg));
  }
  .action:active { transform: translateY(1px); }
  .action code { color: var(--fg); }
  .action .hint {
    font-family: var(--font-sans);
    font-size: 10.5px;
    line-height: 1.45;
    color: color-mix(in srgb, var(--fg) 60%, transparent);
  }

  .state {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.3rem 0.7rem;
    align-items: baseline;
    font-family: var(--font-mono);
    font-size: 11.5px;
    padding: 0.65rem 0.8rem;
    background: var(--code-bg);
    border: 1px solid var(--code-line);
    border-radius: 6px;
  }
  .state .k { color: color-mix(in srgb, var(--code-fg) 55%, transparent); }
  .state code { color: var(--syn-ty); word-break: break-word; }

  .console {
    list-style: none;
    margin: 0;
    padding: 0.7rem 0.8rem;
    background: var(--code-bg);
    border: 1px solid var(--code-line);
    border-radius: 6px;
    font-family: var(--font-mono);
    font-size: 11.5px;
    color: var(--code-fg);
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    max-height: 130px;
    overflow-y: auto;
  }
  .console.empty { color: color-mix(in srgb, var(--code-fg) 40%, transparent); }
  .console .muted code { color: inherit; font-style: italic; }
  .console code { word-break: break-word; }
  .console .prompt {
    color: color-mix(in srgb, var(--code-fg) 45%, transparent);
    margin-right: 0.4rem;
  }
</style>
