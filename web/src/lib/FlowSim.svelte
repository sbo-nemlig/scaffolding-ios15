<script>
  import { fly, fade } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  import PhoneFrame from '$lib/PhoneFrame.svelte';

  /**
   * Configurable mini simulator for a single FlowCoordinator.
   *
   * @prop coordName    The coordinator class name shown in the console.
   * @prop root         The starting screen `{ title, body? }`.
   * @prop actions      Array of `{ code, hint?, fn(ctx) }` rendered as
   *                    pill buttons below the phone. `fn` receives a
   *                    context object with `push`, `pop`, `popToRoot`,
   *                    `present`, `dismiss`, plus `top`, `stack`, `modal`
   *                    accessors.
   * @prop showState    Render a small one-line state read-out.
   * @prop showConsole  Render a 5-line call log.
   */
  let {
    coordName = 'Coordinator',
    root = { title: 'Root', body: '' },
    actions = [],
    showState = false,
    showConsole = false
  } = $props();

  let nextId = 0;
  const nid = (p) => `${p}-${++nextId}`;

  // Mirror Scaffolding's actual model: modals and pushes share a single
  // `destinations` array, distinguished only by `pushType`. That's why
  // `pop()` (which is just `removeLast()`) on the parent flow can
  // dismiss a sheet — the sheet is the topmost destination.
  let stack = $state([{ id: nid('s'), pushType: 'root', ...root }]);
  let log = $state([]);

  let pushedScreens = $derived(
    stack.filter((s) => s.pushType === 'root' || s.pushType === 'push')
  );
  let modalIndex = $derived(
    stack.findIndex((s) => s.pushType === 'sheet' || s.pushType === 'cover')
  );
  let modal = $derived(modalIndex >= 0 ? stack[modalIndex] : null);
  // The presented coordinator's own internal stack — modal root + any
  // screens it has pushed via `pushInModal`. Lets the sim show a true
  // nested flow (e.g. Login presents email → password) inside the sheet.
  let modalScreens = $derived(modalIndex >= 0 ? stack.slice(modalIndex) : []);

  function logCall(code, coord) {
    log = [...log, { id: nid('l'), code, coord }];
    if (log.length > 5) log = log.slice(-5);
  }

  // Mutators exposed to action `fn`s.
  const ctx = {
    push(screen) {
      stack = [...stack, { id: nid('s'), pushType: 'push', ...screen }];
    },
    pop() {
      if (stack.length <= 1) return false;
      stack = stack.slice(0, -1);
      return true;
    },
    popToRoot() {
      if (stack.length <= 1) return false;
      stack = stack.slice(0, 1);
      return true;
    },
    present(screen, kind = 'sheet') {
      if (modal) return false;
      stack = [...stack, { id: nid('m'), pushType: kind, ...screen }];
      return true;
    },
    pushInModal(screen) {
      if (modalIndex < 0) return false;
      stack = [...stack, { id: nid('mp'), pushType: 'modal-push', ...screen }];
      return true;
    },
    dismiss() {
      if (modalIndex < 0) return false;
      // Drop the modal AND every screen the presented coordinator
      // pushed on top of it — that's what dismissCoordinator() does.
      stack = stack.slice(0, modalIndex);
      return true;
    },
    get top() { return stack[stack.length - 1]; },
    get stack() { return stack; },
    get modal() { return modal; }
  };

  function run(action) {
    if (typeof action.fn === 'function') action.fn(ctx);
    logCall(action.code, action.coord);
  }

  // Per-action availability: an action can declare `disabled(ctx)` to
  // gate itself out when it isn't reachable in the simulated state
  // (e.g. a child-coordinator route while no parent modal is up).
  let resolvedActions = $derived(
    actions.map((a) => ({
      ...a,
      _disabled: typeof a.disabled === 'function' ? !!a.disabled(ctx) : false
    }))
  );

  function stackPretty() {
    return stack
      .map((s) => {
        if (s.pushType === 'sheet') return `sheet(.${(s.title ?? '').toLowerCase()})`;
        if (s.pushType === 'cover') return `cover(.${(s.title ?? '').toLowerCase()})`;
        return s.title;
      })
      .join(' → ');
  }
</script>

<div class="sim">
  <PhoneFrame size="compact">
    <div class="stack-region">
      {#each pushedScreens as item, i (item.id)}
        <div
          class="screen"
          style="z-index: {i + 1};"
          in:fly={{ x: 220, duration: 280, easing: cubicOut }}
          out:fly={{ x: 220, duration: 220, easing: cubicOut }}
        >
          <div class="screen-content">
            <h4>{item.title}</h4>
            {#if item.body}<p>{item.body}</p>{/if}
            {#if item.list}
              <ul class="list">
                {#each item.list as line}
                  <li>{line}</li>
                {/each}
              </ul>
            {/if}
          </div>
        </div>
      {/each}
    </div>

    {#if modal}
      <button
        class="backdrop"
        type="button"
        aria-label="Dismiss modal"
        onclick={() => { ctx.dismiss(); logCall('pop()'); }}
        in:fade={{ duration: 200 }}
        out:fade={{ duration: 180 }}
      ></button>
      <div
        class="modal"
        data-kind={modal.pushType}
        in:fly={{ y: 480, duration: 320, easing: cubicOut }}
        out:fly={{ y: 480, duration: 240, easing: cubicOut }}
      >
        {#if modal.pushType === 'sheet'}
          <span class="grabber" aria-hidden="true"></span>
        {/if}
        <div class="modal-stack">
          {#each modalScreens as item, i (item.id)}
            <div
              class="modal-screen"
              style="z-index: {i + 1};"
              in:fly|local={{ x: 220, duration: 280, easing: cubicOut }}
              out:fly|local={{ x: 220, duration: 220, easing: cubicOut }}
            >
              <div class="screen-content">
                <h4>{item.title}</h4>
                {#if item.body}<p>{item.body}</p>{/if}
                {#if item.list}
                  <ul class="list">
                    {#each item.list as line}
                      <li>{line}</li>
                    {/each}
                  </ul>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </PhoneFrame>

  <div class="action-strip">
    {#each resolvedActions.filter((a) => !a._disabled) as a (a.code)}
      <button
        class="action"
        class:accent={a.accent}
        type="button"
        onclick={() => run(a)}
      >
        <span class="action-coord">{a.coord ?? coordName}</span>
        <code>{a.code}</code>
        {#if a.hint}<span class="hint">{a.hint}</span>{/if}
      </button>
    {/each}
  </div>

  {#if showState}
    <div class="state">
      <span class="k">{coordName}.stack</span>
      <code>[{stackPretty()}]</code>
      {#if modal}
        <span class="k">modal</span>
        <code>.{modal.title} ({modal.pushType})</code>
      {/if}
    </div>
  {/if}

  {#if showConsole}
    <ol class="console" class:empty={log.length === 0}>
      {#if log.length === 0}
        <li class="muted"><code>// run an action</code></li>
      {/if}
      {#each log as entry (entry.id)}
        <li in:fly={{ y: 4, duration: 180 }}>
          <code><span class="prompt">›</span>{(entry.coord ?? coordName).toLowerCase()}.{entry.code}</code>
        </li>
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
    /* Lock the column to the phone's width so the actions sit flush
       under the bezel. */
    width: clamp(200px, 32vw, 260px);
    margin: 0;
  }

  /* Stack + modal positioning inside the phone. */
  .stack-region {
    position: absolute;
    inset: 0;
  }

  .screen {
    position: absolute;
    inset: 0;
    background: var(--bg);
    overflow: hidden;
    will-change: transform, opacity;
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

  .backdrop {
    position: absolute;
    inset: 0;
    background: color-mix(in srgb, #000 35%, transparent);
    z-index: 100;
    border: 0;
    padding: 0;
    cursor: pointer;
    will-change: opacity;
  }

  .modal {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 110;
    background: var(--bg);
    overflow: hidden;
    border-radius: 16px 16px 0 0;
    will-change: transform, opacity;
  }
  .modal[data-kind='sheet']  { top: 48px; }
  .modal[data-kind='cover']  { top: 0; border-radius: 0; }

  /* Internal stack of the presented coordinator — its root + any
     screens it has pushed (modal-pushes) sit on top of each other. */
  .modal-stack {
    position: absolute;
    inset: 0;
  }
  .modal[data-kind='sheet'] .modal-stack { top: 16px; }

  .modal-screen {
    position: absolute;
    inset: 0;
    background: var(--bg);
    overflow: hidden;
    will-change: transform, opacity;
  }

  .grabber {
    position: absolute;
    top: 7px;
    left: 50%;
    transform: translateX(-50%);
    width: 32px;
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--fg) 25%, transparent);
    z-index: 50;
  }

  /* Side controls. */
  .side {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    min-width: 0;
  }

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
  .action:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }
  .action.accent {
    border-color: color-mix(in srgb, var(--syn-kw) 60%, transparent);
  }
  .action.accent code { color: var(--syn-kw); }

  /* Owning-coordinator label — shows which type a given button calls
     into. Renders as a small caption above the code so the button
     reads like the actual call site (e.g. `LoginCoordinator` /
     `route(to: .password(email:))`). */
  .action-coord {
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: color-mix(in srgb, var(--fg) 45%, transparent);
    line-height: 1;
    margin-bottom: 0.15rem;
  }
  .action.accent .action-coord {
    color: color-mix(in srgb, var(--syn-kw) 65%, transparent);
  }
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
  .state .k {
    color: color-mix(in srgb, var(--code-fg) 55%, transparent);
  }
  .state code {
    color: var(--syn-ty);
    word-break: break-word;
  }

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
  .console code { color: var(--code-fg); word-break: break-word; }
  .console .prompt {
    color: color-mix(in srgb, var(--code-fg) 45%, transparent);
    margin-right: 0.4rem;
  }
</style>
