<script>
  import { fly, fade } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';

  const PLANETS = ['Mercury', 'Venus', 'Earth', 'Mars', 'Jupiter', 'Saturn'];

  // ── State ──────────────────────────────────────────────────────────
  // Mirrors a real coordinator hierarchy at the data level so each
  // Scaffolding function maps cleanly to a state mutation.

  let phase = $state('main');                // RootCoordinatable: 'main' | 'auth'
  let tab = $state('home');                  // TabCoordinatable: 'home' | 'profile'
  // Each item carries a pushType: 'root' | 'push' | 'sheet' | 'cover'.
  // Mirrors Scaffolding's FlowStack.destinations, where pushed screens
  // and modal-presented coordinators share the same array — that's why
  // `pop()` (which calls destinations.removeLast()) can dismiss a sheet
  // when the sheet is the topmost destination.
  let homeStack = $state([{ id: 'home-root', screen: 'home', pushType: 'root' }]);
  let profileStack = $state([{ id: 'profile-root', screen: 'profile', pushType: 'root' }]);
  let log = $state([]);

  let counter = 0;
  const nid = (prefix) => `${prefix}-${++counter}`;

  let currentStack = $derived(tab === 'home' ? homeStack : profileStack);

  // Pushed screens are only the root + push items. Modals are filtered
  // out so they're rendered as overlays, not as stack pages.
  let homePushed   = $derived(homeStack.filter((s) => s.pushType === 'root' || s.pushType === 'push'));
  let profilePushed = $derived(profileStack.filter((s) => s.pushType === 'root' || s.pushType === 'push'));

  // First (and in our demo, only) modal destination on the active stack.
  let modal = $derived(
    currentStack.find((s) => s.pushType === 'sheet' || s.pushType === 'cover') ?? null
  );

  /** The flow coordinator that owns the currently-visible non-modal screens. */
  function activeFlow() {
    if (phase === 'auth') return 'LoginCoordinator';
    return tab === 'home' ? 'HomeCoordinator' : 'ProfileCoordinator';
  }

  /**
   * The chain of coordinators injected into the SwiftUI environment at the
   * topmost visible screen — i.e. what `@Environment(...)` can resolve.
   * Order: leaf → root.
   */
  let injectedChain = $derived.by(() => {
    if (modal) {
      const modalCoord =
        modal.pushType === 'sheet' ? 'SettingsCoordinator' : 'LoginCoordinator';
      if (phase === 'auth') {
        return [modalCoord, 'LoginCoordinator', 'AppCoordinator'];
      }
      return [modalCoord, activeFlow(), 'MainTabCoordinator', 'AppCoordinator'];
    }
    if (phase === 'auth') {
      return ['LoginCoordinator', 'AppCoordinator'];
    }
    return [activeFlow(), 'MainTabCoordinator', 'AppCoordinator'];
  });

  function logCall(text, kind = 'call', caller = '') {
    log = [...log, { id: nid('log'), text, kind, caller }];
    if (log.length > 8) log = log.slice(-8);
  }

  // ── Mutations (called by phone UI AND action panel) ────────────────

  /** Push a new item onto the active flow's stack. */
  function pushItem(item) {
    if (tab === 'home') homeStack = [...homeStack, item];
    else profileStack = [...profileStack, item];
  }

  /** Replace the active flow's stack. */
  function setStack(items) {
    if (tab === 'home') homeStack = items;
    else profileStack = items;
  }

  function routeToDetail(planet) {
    if (phase !== 'main') return;
    const callerName = activeFlow();
    if (!planet) {
      const pushedSoFar = currentStack.filter(
        (s) => s.pushType === 'push' && s.screen === 'detail'
      ).length;
      planet = PLANETS[pushedSoFar % PLANETS.length];
    }
    pushItem({
      id: nid('detail'),
      screen: 'detail',
      pushType: 'push',
      payload: { title: planet }
    });
    logCall(`route(to: .detail(item: "${planet}"))`, 'call', callerName);
  }

  /**
   * Profile-tab equivalent of routeToDetail. The ProfileCoordinator
   * doesn't have a `.detail` route — it has `.editProfile`. This makes
   * the action labels honest about what's on each tab's coordinator.
   */
  function routeToEditProfile() {
    if (phase !== 'main' || tab !== 'profile') return;
    const callerName = activeFlow();
    pushItem({
      id: nid('edit'),
      screen: 'edit-profile',
      pushType: 'push'
    });
    logCall('route(to: .editProfile)', 'call', callerName);
  }

  /**
   * Mirrors FlowStack.pop() — removes the topmost destination regardless
   * of whether it's a pushed screen or a presented modal. Calling pop on
   * a flow whose top is a sheet dismisses the sheet.
   */
  function pop() {
    if (phase !== 'main') return;
    const callerName = activeFlow();
    if (currentStack.length <= 1) {
      logCall('pop()', 'note', callerName);
      return;
    }
    setStack(currentStack.slice(0, -1));
    logCall('pop()', 'call', callerName);
  }

  function popToRoot() {
    if (phase !== 'main' || currentStack.length <= 1) return;
    const callerName = activeFlow();
    setStack(currentStack.slice(0, 1));
    logCall('popToRoot()', 'call', callerName);
  }

  function presentSheet() {
    if (modal) return;
    const callerName = activeFlow();
    pushItem({
      id: nid('modal'),
      screen: 'settings',
      pushType: 'sheet'
    });
    logCall('present(.settings, as: .sheet)', 'call', callerName);
  }

  function presentCover() {
    if (modal) return;
    const callerName = activeFlow();
    pushItem({
      id: nid('modal'),
      screen: 'login-cover',
      pushType: 'cover'
    });
    logCall('present(.login, as: .fullScreenCover)', 'call', callerName);
  }

  /**
   * `dismissCoordinator()` is called on the *presented* coordinator and
   * removes itself from its parent's stack. In our demo it's only
   * meaningful when a modal is currently displayed.
   */
  function dismissCoordinator() {
    if (!modal) {
      logCall('dismissCoordinator()', 'note', activeFlow());
      return;
    }
    const callerName =
      modal.pushType === 'sheet' ? 'SettingsCoordinator' : 'LoginCoordinator';
    setStack(currentStack.filter((s) => s.id !== modal.id));
    logCall('dismissCoordinator()', 'call', callerName);
  }

  function selectTab(t) {
    if (phase !== 'main' || tab === t) return;
    tab = t;
    logCall(`select(first: .${t})`, 'call', 'MainTabCoordinator');
  }

  function setPhase(p) {
    if (phase === p) return;
    phase = p;
    // setRoot tears down the previous flow — clear its stacks, including
    // any modal destinations they hold.
    homeStack = [{ id: 'home-root', screen: 'home', pushType: 'root' }];
    profileStack = [{ id: 'profile-root', screen: 'profile', pushType: 'root' }];
    logCall(
      `setRoot(.${p === 'main' ? 'authenticated' : 'unauthenticated'})`,
      'call',
      'AppCoordinator'
    );
  }

  function reset() {
    phase = 'main';
    tab = 'home';
    homeStack = [{ id: 'home-root', screen: 'home', pushType: 'root' }];
    profileStack = [{ id: 'profile-root', screen: 'profile', pushType: 'root' }];
    log = [];
  }

  // ── Filtered action panel ──────────────────────────────────────────
  // Only show what's actually callable in the current coordinator
  // context. dismissCoordinator() is a coordinator-level pop and
  // therefore lives only on the presented-modal context.

  let actionGroups = $derived.by(() => {
    if (modal) {
      const groups = [
        {
          label:
            modal.pushType === 'sheet'
              ? 'Presented coordinator (sheet)'
              : 'Presented coordinator (full-screen cover)',
          items: [
            {
              code: 'dismissCoordinator()',
              fn: dismissCoordinator,
              accent: true,
              hint:
                'Pops the entire presented coordinator off its parent. ' +
                'It does not dismiss screens — pop() does that.'
            }
          ]
        }
      ];

      // The underlying flow coordinator is still alive and still in the
      // SwiftUI environment, AND its FlowStack.destinations array is
      // exactly the same array that holds the modal — that's why
      // `flow.pop()` removes the modal when the modal is the topmost
      // destination, the way Scaffolding actually behaves.
      if (phase === 'main') {
        const flowName = activeFlow();
        // What sits on top of the active flow's destinations right now?
        const top = currentStack[currentStack.length - 1];
        const topIsModal = top && (top.pushType === 'sheet' || top.pushType === 'cover');

        const popHint = topIsModal
          ? `${flowName}.stack.destinations.removeLast() — the topmost destination is the ${top.pushType}, so pop() dismisses it.`
          : `Pop the top of ${flowName}'s stack. The sheet stays put because it isn't topmost.`;

        // Each tab's coordinator exposes different routes — Home has
        // `.detail(item:)`, Profile has `.editProfile`. Show the one
        // that's actually callable on the active flow.
        const isHome = tab === 'home';
        const routeAction = isHome
          ? {
              code: 'route(to: .detail)',
              fn: () => routeToDetail(),
              hint: `Append a pushed detail onto home.stack — even with the ${modal.pushType} still open.`
            }
          : {
              code: 'route(to: .editProfile)',
              fn: () => routeToEditProfile(),
              hint: `Append the edit-profile screen onto profile.stack — even with the ${modal.pushType} still open.`
            };
        const stackItems = [routeAction];

        if (currentStack.length > 1) {
          stackItems.push({
            code: 'pop()',
            fn: pop,
            hint: popHint
          });
          stackItems.push({
            code: 'popToRoot()',
            fn: popToRoot,
            hint: `Drop everything above ${flowName}'s root — pushes and the ${modal.pushType} both go.`
          });
        }
        groups.push({
          label: `Underlying flow (${flowName})`,
          items: stackItems
        });
      }

      return groups;
    }

    if (phase === 'auth') {
      return [
        {
          label: 'Root coordinator',
          items: [
            {
              code: 'setRoot(.authenticated)',
              fn: () => setPhase('main'),
              hint:
                'Atomic root swap — replaces the unauthenticated flow with the main app.'
            }
          ]
        }
      ];
    }

    // phase === 'main', no modal — we are inside the active flow.
    const groups = [];

    // Tab-aware route action: Home has `.detail`, Profile has `.editProfile`.
    const isHome = tab === 'home';
    const routeAction = isHome
      ? {
          code: 'route(to: .detail)',
          fn: () => routeToDetail(),
          hint: 'Push a detail screen onto home.stack. Cycles through the planet list.'
        }
      : {
          code: 'route(to: .editProfile)',
          fn: () => routeToEditProfile(),
          hint: 'Push the edit-profile screen onto profile.stack.'
        };
    const stackItems = [routeAction];

    if (currentStack.length > 1) {
      stackItems.push({
        code: 'pop()',
        fn: pop,
        hint: 'Pop the top of the active stack. Fires its onDismiss.'
      });
      stackItems.push({
        code: 'popToRoot()',
        fn: popToRoot,
        hint: 'Pop everything except the root. Each removed screen resolves once.'
      });
    }
    groups.push({ label: 'Stack', items: stackItems });

    groups.push({
      label: 'Present',
      items: [
        {
          code: 'present(.settings, as: .sheet)',
          fn: presentSheet,
          hint: 'Present a SettingsCoordinator as a modal sheet over the current flow.'
        },
        {
          code: 'present(.login, as: .fullScreenCover)',
          fn: presentCover,
          hint: 'Present a LoginCoordinator as a full-screen cover. No backdrop tap-out.'
        }
      ]
    });

    const otherTab = tab === 'home' ? 'profile' : 'home';
    groups.push({
      label: 'Tabs & root',
      items: [
        {
          code: `select(first: .${otherTab})`,
          fn: () => selectTab(otherTab),
          hint: `Switch the tab coordinator to ${otherTab.charAt(0).toUpperCase() + otherTab.slice(1)}. Each tab keeps its own stack.`
        },
        {
          code: 'setRoot(.unauthenticated)',
          fn: () => setPhase('auth'),
          hint: 'Atomic root swap back to the auth flow. Tears down the main app.'
        }
      ]
    });

    return groups;
  });

  // ── Display helpers ────────────────────────────────────────────────

  function stackPretty(stack) {
    return stack
      .map((s) => {
        if (s.pushType === 'push' && s.screen === 'detail') {
          return `detail("${s.payload?.title ?? ''}")`;
        }
        if (s.pushType === 'push' && s.screen === 'edit-profile') {
          return 'editProfile';
        }
        if (s.pushType === 'sheet')  return `sheet(.${s.screen})`;
        if (s.pushType === 'cover')  return `cover(.${s.screen})`;
        return s.screen; // root
      })
      .join(', ');
  }
</script>

<section class="play hold" id="play" aria-label="Scaffolding playground">
  <div class="play-inner">
    <header class="head">
      <span class="num">04 / Playground</span>
      <h2>See it in motion.</h2>
      <p class="note">
        The phone is a working prototype — tap rows, tabs, the gear, the back
        chevron. The action panel mirrors what's callable from the
        <em>current</em> coordinator: <strong>only valid Scaffolding functions
        appear at any given moment</strong>.
      </p>
    </header>

    <div class="grid">
      <!-- ── Phone ────────────────────────────────────────────────── -->
      <div class="phone-col">
        <div class="phone">
          <div class="phone-frame">
            <span class="notch"></span>
            <div class="screen-area">
              {#if phase === 'auth'}
                <div
                  class="layer auth"
                  in:fade={{ duration: 220, easing: cubicOut }}
                  out:fade={{ duration: 180 }}
                >
                  <div class="status-bar"><span>9:41</span></div>
                  <div class="screen-content auth-content">
                    <h4>Welcome back</h4>
                    <p class="muted">Sign in to continue</p>
                    <div class="field"></div>
                    <div class="field"></div>
                    <button
                      type="button"
                      class="primary"
                      onclick={() => setPhase('main')}
                    >
                      Sign in
                    </button>
                  </div>
                </div>
              {:else}
                <div
                  class="layer main"
                  in:fade={{ duration: 220, easing: cubicOut }}
                  out:fade={{ duration: 180 }}
                >
                  <div class="status-bar">
                    <span>9:41</span>
                    <span class="bars">●●●</span>
                  </div>
                  <div class="content">
                    {#if tab === 'home'}
                      <div
                        class="tab-pane"
                        in:fade={{ duration: 200, easing: cubicOut }}
                        out:fade={{ duration: 160 }}
                      >
                        <div class="stack-region">
                          {#each homePushed as item, i (item.id)}
                            <div
                              class="screen"
                              style="z-index: {i + 1};"
                              in:fly={{ x: 320, duration: 340, easing: cubicOut }}
                              out:fly={{ x: 320, duration: 260, easing: cubicOut }}
                            >
                              {#if item.screen === 'home'}
                                <div class="screen-content">
                                  <header class="screen-top">
                                    <h4>Planets</h4>
                                    <button
                                      type="button"
                                      class="icon-btn"
                                      onclick={presentSheet}
                                      aria-label="Open settings"
                                    >⚙</button>
                                  </header>
                                  <ul class="list">
                                    {#each PLANETS as p}
                                      <li>
                                        <button
                                          type="button"
                                          class="row"
                                          onclick={() => routeToDetail(p)}
                                        >
                                          <span>{p}</span>
                                          <span class="chev" aria-hidden="true">›</span>
                                        </button>
                                      </li>
                                    {/each}
                                  </ul>
                                </div>
                              {:else if item.screen === 'detail'}
                                <div class="screen-content detail">
                                  <button
                                    type="button"
                                    class="back"
                                    onclick={pop}
                                  >‹ Planets</button>
                                  <h4>{item.payload.title}</h4>
                                  <p class="lorem"></p>
                                  <p class="lorem short"></p>
                                  <p class="lorem"></p>
                                </div>
                              {/if}
                            </div>
                          {/each}
                        </div>
                      </div>
                    {:else}
                      <div
                        class="tab-pane"
                        in:fade={{ duration: 200, easing: cubicOut }}
                        out:fade={{ duration: 160 }}
                      >
                        <div class="stack-region">
                          {#each profilePushed as item, i (item.id)}
                            <div
                              class="screen"
                              style="z-index: {i + 1};"
                              in:fly={{ x: 320, duration: 340, easing: cubicOut }}
                              out:fly={{ x: 320, duration: 260, easing: cubicOut }}
                            >
                              {#if item.screen === 'profile'}
                                <div class="screen-content">
                                  <div class="avatar"></div>
                                  <h4>Alex</h4>
                                  <p class="muted">@alex</p>
                                  <ul class="list">
                                    <li>
                                      <button
                                        type="button"
                                        class="row"
                                        onclick={routeToEditProfile}
                                      >
                                        <span>Edit profile</span>
                                        <span class="chev" aria-hidden="true">›</span>
                                      </button>
                                    </li>
                                    <li>
                                      <button
                                        type="button"
                                        class="row"
                                        onclick={presentCover}
                                      >
                                        <span>Re-authenticate</span>
                                        <span class="chev" aria-hidden="true">›</span>
                                      </button>
                                    </li>
                                    <li>
                                      <button
                                        type="button"
                                        class="row"
                                        onclick={() => setPhase('auth')}
                                      >
                                        <span>Sign out</span>
                                        <span class="chev" aria-hidden="true">›</span>
                                      </button>
                                    </li>
                                  </ul>
                                </div>
                              {:else if item.screen === 'detail'}
                                <div class="screen-content detail">
                                  <button
                                    type="button"
                                    class="back"
                                    onclick={pop}
                                  >‹ Profile</button>
                                  <h4>{item.payload.title}</h4>
                                  <p class="lorem"></p>
                                </div>
                              {:else if item.screen === 'edit-profile'}
                                <div class="screen-content detail">
                                  <button
                                    type="button"
                                    class="back"
                                    onclick={pop}
                                  >‹ Profile</button>
                                  <h4>Edit profile</h4>
                                  <div class="field"></div>
                                  <div class="field"></div>
                                  <button
                                    type="button"
                                    class="primary"
                                    onclick={pop}
                                  >Save</button>
                                </div>
                              {/if}
                            </div>
                          {/each}
                        </div>
                      </div>
                    {/if}
                  </div>
                  <div class="tabbar">
                    <button
                      type="button"
                      class="tab-btn"
                      class:active={tab === 'home'}
                      onclick={() => selectTab('home')}
                    >
                      <span class="tab-icon" aria-hidden="true">⌂</span>
                      <span>Home</span>
                    </button>
                    <button
                      type="button"
                      class="tab-btn"
                      class:active={tab === 'profile'}
                      onclick={() => selectTab('profile')}
                    >
                      <span class="tab-icon" aria-hidden="true">●</span>
                      <span>Profile</span>
                    </button>
                  </div>
                </div>
              {/if}

              {#if modal}
                {#if modal.pushType === 'sheet'}
                  <button
                    type="button"
                    class="backdrop"
                    aria-label="Dismiss sheet"
                    onclick={dismissCoordinator}
                    in:fade={{ duration: 240 }}
                    out:fade={{ duration: 200 }}
                  ></button>
                {/if}
                <div
                  class="modal {modal.pushType}"
                  in:fly={{ y: 700, duration: 380, easing: cubicOut }}
                  out:fly={{ y: 700, duration: 280, easing: cubicOut }}
                >
                  {#if modal.pushType === 'sheet'}
                    <span class="grabber" aria-hidden="true"></span>
                  {/if}
                  {#if modal.screen === 'settings'}
                    <div class="screen-content">
                      <header class="screen-top">
                        <h4>Settings</h4>
                        <button
                          type="button"
                          class="text-btn"
                          onclick={dismissCoordinator}
                        >Done</button>
                      </header>
                      <ul class="list">
                        <li>Notifications</li>
                        <li>Privacy</li>
                        <li>Account</li>
                        <li>About</li>
                      </ul>
                    </div>
                  {:else if modal.screen === 'login-cover'}
                    <div class="screen-content auth-content">
                      <header class="screen-top">
                        <button
                          type="button"
                          class="text-btn cancel"
                          onclick={dismissCoordinator}
                        >Cancel</button>
                      </header>
                      <h4>Sign in</h4>
                      <p class="muted">Enter your credentials</p>
                      <div class="field"></div>
                      <div class="field"></div>
                      <button
                        type="button"
                        class="primary"
                        onclick={dismissCoordinator}
                      >Continue</button>
                    </div>
                  {/if}
                </div>
              {/if}

              <div class="home-indicator" aria-hidden="true"></div>
            </div>
          </div>
        </div>

        <p class="caption">
          Tap rows, tabs, gear, or back arrow to drive the simulation.
        </p>
      </div>

      <!-- ── Right column ────────────────────────────────────────── -->
      <div class="info-col">
        <section class="state" aria-label="Coordinator state">
          <h3>State</h3>
          <div class="state-grid">
            <span class="k">root</span>
            <span class="v"><code>.{phase === 'main' ? 'authenticated' : 'unauthenticated'}</code></span>

            {#if phase === 'main'}
              <span class="k">tab.selected</span>
              <span class="v"><code>.{tab}</code></span>

              <span class="k">{tab}.stack</span>
              <span class="v"><code>[{stackPretty(currentStack)}]</code></span>
            {/if}

            <span class="k">modal</span>
            <span class="v">
              <code>{modal ? `.${modal.screen} (${modal.pushType === 'cover' ? 'fullScreenCover' : 'sheet'})` : 'nil'}</code>
            </span>

            <span class="k">@Environment</span>
            <span class="v env">
              {#each injectedChain as coord, i (coord)}
                <code class="env-line">
                  {#if i > 0}
                    <span class="env-arrow" aria-hidden="true">↑</span>
                  {/if}
                  {coord}
                </code>
              {/each}
            </span>
          </div>
        </section>

        <section class="actions" aria-label="Available actions">
          <div class="actions-head">
            <h3>Available actions</h3>
            <button type="button" class="reset" onclick={reset}>↻ Reset</button>
          </div>

          <div class="action-groups">
            {#each actionGroups as group (group.label)}
              <div
                class="group"
                in:fade={{ duration: 180, easing: cubicOut }}
                out:fade={{ duration: 120 }}
              >
                <span class="group-label">{group.label}</span>
                {#each group.items as item (item.code)}
                  <button
                    type="button"
                    class="action"
                    class:accent={item.accent}
                    onclick={item.fn}
                  >
                    <code>{item.code}</code>
                    {#if item.hint}
                      <span class="action-hint">{item.hint}</span>
                    {/if}
                  </button>
                {/each}
              </div>
            {/each}
          </div>
        </section>

        <section class="console" aria-label="Console">
          <h3>Console</h3>
          <ol class="log">
            {#if log.length === 0}
              <li class="empty"><code>// Tap something on the phone or press an action.</code></li>
            {/if}
            {#each log as entry (entry.id)}
              <li
                class="entry"
                class:note={entry.kind === 'note'}
                in:fly={{ y: 6, duration: 200, easing: cubicOut }}
              >
                <span class="prompt" aria-hidden="true">›</span>
                <code class="call-text">coordinator.{entry.text}</code>
                {#if entry.caller}
                  <code class="caller">// {entry.caller}</code>
                {/if}
              </li>
            {/each}
          </ol>
        </section>
      </div>
    </div>
  </div>
</section>

<style>
  .play {
    width: 100%;
    padding: clamp(3.5rem, 8vw, 6rem) 0;
  }

  .play-inner {
    max-width: 1280px;
    margin: 0 auto;
    padding: 0 clamp(1.25rem, 4vw, 3rem);
  }

  /* Cap the inner container so its right edge clears the
     ScrollProgress rail (~210 px) when the rail shows its full
     labels at ≥ 1340 viewport. */
  @media (min-width: 1340px) {
    .play-inner {
      max-width: min(1280px, calc(100vw - 440px));
    }
  }

  .head {
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
    margin-bottom: clamp(2rem, 3.5vw, 3rem);
    max-width: 64ch;
  }

  .num {
    font-size: 11px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--dim);
  }

  .head h2 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: clamp(1.5rem, 2.6vw, 2rem);
    font-weight: 500;
    letter-spacing: -0.015em;
    color: var(--fg);
  }

  .note {
    margin: 0;
    font-size: 14px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 70%, transparent);
  }

  .note em {
    font-style: italic;
    color: var(--fg);
  }
  .note strong {
    color: var(--fg);
    font-weight: 500;
  }

  .grid {
    display: grid;
    /* Phone column auto-sizes to whatever the phone needs (capped by both
       viewport width and viewport height — see .phone below). */
    grid-template-columns: minmax(0, auto) minmax(360px, 1fr);
    gap: clamp(2rem, 4vw, 3rem);
    align-items: start;
  }

  @media (max-width: 1024px) {
    .grid {
      grid-template-columns: 1fr;
      justify-items: center;
    }
    .info-col {
      width: 100%;
    }
  }

  /* ── Phone ────────────────────────────────────────────────────────── */

  .phone-col {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    align-items: center;
    position: sticky;
    top: 5.5rem;
  }

  @media (max-width: 980px) {
    .phone-col { position: static; }
  }

  .phone {
    /* Whichever is smaller: the width clamp, or what fits in 75vh of
       viewport height while preserving aspect ratio. This keeps the phone
       on-screen on short displays without overflowing on tall ones. */
    width: min(clamp(240px, 26vw, 360px), calc(75svh * 9 / 18.5));
    aspect-ratio: 9 / 18.5;
  }

  @supports not (height: 1svh) {
    .phone {
      width: min(clamp(240px, 26vw, 360px), calc(75vh * 9 / 18.5));
    }
  }

  .phone-frame {
    position: relative;
    width: 100%;
    height: 100%;
    padding: 8px;
    border-radius: 38px;
    border: 1px solid color-mix(in srgb, var(--fg) 28%, transparent);
    background: color-mix(in srgb, var(--fg) 12%, var(--bg));
    box-shadow:
      0 0 0 1px color-mix(in srgb, var(--fg) 6%, transparent) inset,
      0 24px 50px -22px color-mix(in srgb, var(--fg) 35%, transparent);
  }

  .notch {
    position: absolute;
    top: 18px;
    left: 50%;
    transform: translateX(-50%);
    width: 96px;
    height: 26px;
    background: #000;
    border-radius: 999px;
    z-index: 50;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.04);
  }

  .screen-area {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    border-radius: 30px;
    background: var(--bg);
    color: var(--fg);
    isolation: isolate;
  }

  .layer {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
  }

  .status-bar {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    /* Push the time / signal indicators down so they line up with the
       vertical center of the Dynamic Island. */
    padding: 18px 22px 8px;
    font-size: 11px;
    letter-spacing: 0.04em;
    color: color-mix(in srgb, var(--fg) 75%, transparent);
  }

  .bars {
    font-size: 8px;
    letter-spacing: 0.15em;
    opacity: 0.7;
  }

  .content {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .tab-pane {
    position: absolute;
    inset: 0;
  }

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
    padding: 16px 18px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    height: 100%;
  }

  .screen-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
  }

  .screen-content h4 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 17px;
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.01em;
  }

  .muted {
    margin: 0;
    font-size: 12px;
    color: color-mix(in srgb, var(--fg) 55%, transparent);
  }

  /* ── In-phone interactive elements ──────────────────────────────── */

  .icon-btn {
    width: 28px;
    height: 28px;
    border-radius: 8px;
    border: 1px solid color-mix(in srgb, var(--fg) 14%, transparent);
    background: color-mix(in srgb, var(--fg) 5%, transparent);
    color: var(--fg);
    font-size: 13px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background-color 140ms ease, border-color 140ms ease;
  }
  .icon-btn:hover {
    background: color-mix(in srgb, var(--fg) 12%, transparent);
    border-color: color-mix(in srgb, var(--fg) 30%, transparent);
  }
  .icon-btn:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }

  .text-btn {
    font: inherit;
    font-size: 13px;
    color: var(--fg);
    background: transparent;
    border: 0;
    padding: 0.2rem 0.4rem;
    cursor: pointer;
    border-radius: 4px;
    transition: background-color 140ms ease;
  }
  .text-btn:hover {
    background: color-mix(in srgb, var(--fg) 8%, transparent);
  }
  .text-btn.cancel {
    color: color-mix(in srgb, var(--fg) 70%, transparent);
  }

  .list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .list li {
    padding: 0;
    font-size: 12.5px;
    color: color-mix(in srgb, var(--fg) 85%, transparent);
  }

  /* Plain (non-interactive) list rows used inside the settings sheet. */
  .list > li:not(:has(.row)) {
    padding: 9px 11px;
    border-radius: 6px;
    background: color-mix(in srgb, var(--fg) 6%, transparent);
    border: 1px solid color-mix(in srgb, var(--fg) 8%, transparent);
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 9px 11px;
    border-radius: 6px;
    background: color-mix(in srgb, var(--fg) 5%, transparent);
    border: 1px solid color-mix(in srgb, var(--fg) 8%, transparent);
    color: inherit;
    font: inherit;
    font-size: 12.5px;
    cursor: pointer;
    transition: background-color 140ms ease, border-color 140ms ease, transform 80ms ease;
  }
  .row:hover {
    background: color-mix(in srgb, var(--fg) 10%, transparent);
    border-color: color-mix(in srgb, var(--fg) 22%, transparent);
  }
  .row:active {
    transform: translateY(0.5px);
  }
  .row:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }

  .chev {
    color: color-mix(in srgb, var(--fg) 45%, transparent);
    font-size: 13px;
  }

  .back {
    align-self: flex-start;
    font: inherit;
    font-size: 12.5px;
    color: color-mix(in srgb, var(--fg) 75%, transparent);
    background: transparent;
    border: 0;
    padding: 0.2rem 0.4rem 0.2rem 0;
    cursor: pointer;
    border-radius: 4px;
  }
  .back:hover {
    color: var(--fg);
  }
  .back:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
    color: var(--fg);
  }

  .lorem {
    height: 8px;
    margin: 0;
    border-radius: 999px;
    background: color-mix(in srgb, var(--fg) 12%, transparent);
  }
  .lorem.short { width: 60%; }

  .avatar {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: color-mix(in srgb, var(--fg) 18%, transparent);
    align-self: center;
    margin-top: 8px;
  }

  .field {
    height: 32px;
    border-radius: 7px;
    background: color-mix(in srgb, var(--fg) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--fg) 12%, transparent);
  }

  .primary {
    margin-top: 4px;
    padding: 9px 14px;
    font: inherit;
    font-size: 13px;
    border-radius: 8px;
    border: 0;
    background: var(--fg);
    color: var(--bg);
    cursor: pointer;
    transition: opacity 140ms ease;
  }
  .primary:hover { opacity: 0.85; }
  .primary:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }

  .auth-content {
    justify-content: center;
    gap: 12px;
  }

  /* ── Tab bar ──────────────────────────────────────────────────────── */

  .tabbar {
    flex-shrink: 0;
    display: grid;
    grid-template-columns: 1fr 1fr;
    border-top: 1px solid color-mix(in srgb, var(--fg) 12%, transparent);
    background: color-mix(in srgb, var(--fg) 4%, var(--bg));
    padding-bottom: 8px;
  }

  .tab-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    padding: 9px 0 6px;
    font: inherit;
    font-family: var(--font-mono);
    font-size: 10.5px;
    color: color-mix(in srgb, var(--fg) 50%, transparent);
    background: transparent;
    border: 0;
    cursor: pointer;
    transition: color 180ms ease, background-color 140ms ease;
  }

  .tab-btn:hover {
    color: var(--fg);
    background: color-mix(in srgb, var(--fg) 5%, transparent);
  }
  .tab-btn.active {
    color: var(--fg);
  }
  .tab-btn:focus-visible {
    outline: none;
    box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }

  .tab-icon {
    font-size: 16px;
    line-height: 1;
  }

  .home-indicator {
    position: absolute;
    bottom: 6px;
    left: 50%;
    transform: translateX(-50%);
    width: 110px;
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--fg) 30%, transparent);
    z-index: 60;
    pointer-events: none;
  }

  /* ── Modal & backdrop ─────────────────────────────────────────────── */

  .backdrop {
    position: absolute;
    inset: 0;
    background: color-mix(in srgb, #000 35%, transparent);
    z-index: 100;
    will-change: opacity;
    border: 0;
    padding: 0;
    cursor: pointer;
  }

  .modal {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 110;
    background: var(--bg);
    will-change: transform, opacity;
    border-radius: 18px 18px 0 0;
    overflow: hidden;
  }

  .modal.sheet {
    /* Leave room above the sheet so the Dynamic Island stays visible. */
    top: 56px;
  }

  .modal.cover {
    top: 0;
    border-radius: 0;
  }

  .grabber {
    position: absolute;
    top: 8px;
    left: 50%;
    transform: translateX(-50%);
    width: 36px;
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--fg) 25%, transparent);
  }

  .caption {
    margin: 0;
    font-size: 11px;
    letter-spacing: 0.04em;
    color: var(--dim);
    text-align: center;
    max-width: 30ch;
  }

  /* ── Right column ─────────────────────────────────────────────────── */

  .info-col {
    display: flex;
    flex-direction: column;
    gap: 1.4rem;
  }

  .info-col h3 {
    margin: 0 0 0.7rem;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--dim);
  }

  /* State pane */

  .state {
    border: 1px solid var(--code-line);
    border-radius: 8px;
    background: var(--code-bg);
    padding: 1rem 1.1rem;
  }

  .state h3 {
    color: color-mix(in srgb, var(--code-fg) 50%, transparent);
  }

  .state-grid {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.45rem 1rem;
    /* `start` (not baseline) so multi-line @Environment values don't
       drag the key label off the first line. */
    align-items: start;
    font-family: var(--font-mono);
    font-size: 12.5px;
    color: var(--code-fg);
  }

  .state-grid .k {
    color: color-mix(in srgb, var(--code-fg) 55%, transparent);
    line-height: 1.45;
  }

  .state-grid .v {
    line-height: 1.45;
  }

  .state-grid .v code {
    color: var(--syn-ty);
  }

  /* @Environment chain: one coordinator per line with a leading ↑. */
  .v.env {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .env-line {
    display: inline-flex;
    align-items: baseline;
    gap: 0.4rem;
  }

  .env-arrow {
    color: color-mix(in srgb, var(--code-fg) 40%, transparent);
    font-family: var(--font-mono);
  }

  /* Actions */

  .actions {
    border: 1px solid var(--line);
    border-radius: 8px;
    background: var(--surface);
    padding: 1.1rem 1.1rem 1.2rem;
  }

  .actions-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .reset {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.04em;
    color: var(--muted);
    background: transparent;
    border: 1px solid var(--line);
    border-radius: 999px;
    padding: 0.25rem 0.65rem;
    cursor: pointer;
    transition: color 140ms ease, border-color 140ms ease, background-color 140ms ease;
  }
  .reset:hover {
    color: var(--fg);
    border-color: color-mix(in srgb, var(--fg) 30%, transparent);
    background: color-mix(in srgb, var(--fg) 5%, transparent);
  }

  .action-groups {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 1rem;
  }

  .group {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .group-label {
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--dim);
    padding-bottom: 0.1rem;
  }

  .action {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    text-align: left;
    border: 1px solid var(--line);
    background: var(--bg);
    color: var(--fg);
    padding: 0.55rem 0.7rem;
    border-radius: 6px;
    cursor: pointer;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.3;
    transition:
      border-color 140ms ease,
      background-color 140ms ease,
      transform 100ms ease;
  }

  .action code { color: var(--fg); }

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
  .action.accent code {
    color: var(--syn-kw);
  }
  .action.accent:hover {
    background: color-mix(in srgb, var(--syn-kw) 7%, var(--bg));
  }

  .action-hint {
    margin-top: 0.15rem;
    padding-top: 0.4rem;
    border-top: 1px dashed color-mix(in srgb, var(--fg) 14%, transparent);
    font-family: var(--font-sans);
    font-size: 11px;
    line-height: 1.5;
    color: color-mix(in srgb, var(--fg) 62%, transparent);
  }

  /* Console */

  .console {
    border: 1px solid var(--code-line);
    border-radius: 8px;
    background: var(--code-bg);
    padding: 1rem 1.1rem 1.1rem;
  }

  .console h3 {
    color: color-mix(in srgb, var(--code-fg) 50%, transparent);
  }

  .log {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    font-family: var(--font-mono);
    font-size: 12.5px;
    color: var(--code-fg);
    max-height: 220px;
    overflow-y: auto;
  }

  .log .empty {
    color: color-mix(in srgb, var(--code-fg) 38%, transparent);
    font-style: italic;
  }

  .entry {
    display: flex;
    align-items: baseline;
    gap: 0.55rem;
    flex-wrap: wrap;
  }

  .entry.note .call-text {
    color: color-mix(in srgb, var(--code-fg) 55%, transparent);
  }

  .prompt {
    color: color-mix(in srgb, var(--code-fg) 45%, transparent);
    flex-shrink: 0;
  }

  .entry .call-text {
    color: var(--code-fg);
    word-break: break-word;
  }

  /* Trailing `// CoordinatorName` comment on each entry — the Swift
     side calls `pop()` etc. on a specific coordinator instance, and
     this comment makes that explicit in the console. */
  .caller {
    color: color-mix(in srgb, var(--code-fg) 50%, transparent);
    font-style: italic;
  }

  .entry.note .caller {
    color: color-mix(in srgb, var(--code-fg) 38%, transparent);
  }
</style>
