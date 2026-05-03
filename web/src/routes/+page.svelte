<script>
  import { base } from '$app/paths';
  import CodeBlock from '$lib/CodeBlock.svelte';
  import Architecture from '$lib/Architecture.svelte';
  import Playground from '$lib/Playground.svelte';
  import ScrollProgress from '$lib/ScrollProgress.svelte';
  import { GITHUB_URL } from '$lib/links.js';

  const DOCS_HREF = `${base}/docs`;

  const CODE_DEFINE = `@Scaffoldable @Observable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)

    func home() -> some View { HomeView() }
    func detail(item: Item) -> some View { DetailView(item: item) }
    func settings() -> any Coordinatable { SettingsCoordinator() }
}`;

  const CODE_NAVIGATE = `// Push onto the stack — type-safe destination.
coordinator.route(to: .detail(item: planet))

// Present a modal — sheet or full-screen cover.
coordinator.present(.settings, as: .sheet)
coordinator.present(.login, as: .fullScreenCover)

// Go back.
coordinator.pop()`;

  const FEATURES = [
    'Type-safe destinations from a Swift macro',
    'Push, sheet, and full-screen cover, separated',
    'Nested coordinator flows across modules',
    'Atomic root switches for auth and onboarding',
    'Environment-injected coordinators',
    'iOS 18 / macOS 15 / watchOS 11 / tvOS 18'
  ];
</script>

<ScrollProgress />

<main class="main">
  <div class="narrow">
    <section class="hero hold" id="hero">
      <p class="eyebrow">SwiftUI · Swift 6.2 · Macro-powered</p>
      <h1 class="headline">
        Coordinator pattern.<br />
        <span class="dim">Compile time.</span>
      </h1>
      <p class="lede">
        Define routes as functions on an <code>@Observable</code> class. The
        <code>@Scaffoldable</code> macro generates a type-safe
        <code>Destinations</code> enum from your methods — no manual cases,
        no switch statements, no boilerplate.
      </p>
      <div class="cta">
        <a class="btn primary" href={DOCS_HREF}>
          Read the docs <span aria-hidden="true">→</span>
        </a>
        <a class="btn ghost" href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
          View on GitHub
        </a>
      </div>

      <a class="scroll-cue" href="#examples" aria-label="Scroll to next section">
        <span class="scroll-cue-label">Scroll</span>
        <svg
          class="scroll-cue-arrow"
          width="14" height="14" viewBox="0 0 14 14"
          aria-hidden="true"
        >
          <path d="M3 5 L7 9 L11 5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </a>
    </section>

    <section class="examples hold" aria-label="Code examples" id="examples">
      <article class="example">
        <header class="ex-head">
          <span class="ex-num">01</span>
          <h2>Define routes as functions.</h2>
        </header>
        <CodeBlock code={CODE_DEFINE} label="HomeCoordinator.swift" />
      </article>

      <article class="example">
        <header class="ex-head">
          <span class="ex-num">02</span>
          <h2>Push and present, separately.</h2>
        </header>
        <p class="ex-note">
          <code>route(to:)</code> only pushes. <code>present(_:as:)</code> handles
          sheets and full-screen covers — and is available on every coordinator type.
        </p>
        <CodeBlock code={CODE_NAVIGATE} label="Navigation" />
      </article>
    </section>
  </div>

  <Architecture />

  <Playground />

  <div class="narrow">
    <section class="features hold" aria-label="Features" id="features">
      <ul>
        {#each FEATURES as feature}
          <li><span class="bullet" aria-hidden="true">→</span>{feature}</li>
        {/each}
      </ul>
    </section>
  </div>
</main>

<style>
  .main {
    position: relative;
    z-index: 1;
    padding: clamp(3rem, 9vw, 6rem) 0 4rem;
  }

  .narrow {
    max-width: 920px;
    margin: 0 auto;
    padding: 0 clamp(1.25rem, 4vw, 3rem);
  }

  /* Each major section "holds" at least one viewport tall. Content flows
     from the top so it doesn't shift vertically when inner content (e.g.
     the architecture's hover-driven code panel) changes height. */
  :global(.hold) {
    min-height: 100vh;
    min-height: 100svh;
    padding-top: clamp(3rem, 6vh, 5rem);
    padding-bottom: clamp(3rem, 6vh, 5rem);
  }

  .hero {
    padding: clamp(2rem, 6vw, 4rem) 0 clamp(3rem, 8vw, 5rem);
    border-bottom: 1px solid var(--line-soft);
  }

  .eyebrow {
    margin: 0 0 1.5rem;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--muted);
  }

  .headline {
    margin: 0 0 1.75rem;
    font-family: var(--font-mono);
    font-size: clamp(2.25rem, 6.4vw, 4.25rem);
    line-height: 1.05;
    letter-spacing: -0.03em;
    font-weight: 500;
    color: var(--fg);
  }

  .dim {
    color: var(--muted);
  }

  .lede {
    max-width: 60ch;
    margin: 0 0 2rem;
    font-size: 15px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 75%, transparent);
  }

  .lede code,
  .ex-note code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.4em;
    border-radius: 3px;
  }

  .cta {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.7rem 1.1rem;
    font-size: 13px;
    font-family: var(--font-mono);
    border: 1px solid var(--line);
    border-radius: 3px;
    text-decoration: none;
    transition: background 140ms ease, color 140ms ease, border-color 140ms ease;
  }

  .btn.primary {
    background: var(--primary-bg);
    color: var(--primary-fg);
    border-color: var(--primary-bg);
  }
  .btn.primary:hover {
    background: var(--primary-bg-hover);
    border-color: var(--primary-bg-hover);
  }

  .btn.ghost {
    color: color-mix(in srgb, var(--fg) 85%, transparent);
  }
  .btn.ghost:hover {
    background: var(--surface);
    border-color: color-mix(in srgb, var(--fg) 25%, transparent);
    color: var(--fg);
  }

  /* Scroll cue beneath the headline — gentle bob animation, becomes
     fully opaque on hover. Hidden when the user prefers reduced motion. */
  .scroll-cue {
    margin-top: clamp(2rem, 4vw, 3rem);
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--muted);
    text-decoration: none;
    align-self: flex-start;
    opacity: 0.85;
    animation: scroll-bob 2.4s ease-in-out infinite;
    transition: color 140ms ease, opacity 140ms ease;
  }
  .scroll-cue:hover,
  .scroll-cue:focus-visible {
    color: var(--fg);
    opacity: 1;
    outline: none;
  }
  .scroll-cue-arrow {
    color: inherit;
    flex-shrink: 0;
  }

  @keyframes scroll-bob {
    0%, 100% { transform: translateY(0); }
    50%      { transform: translateY(5px); }
  }

  @media (prefers-reduced-motion: reduce) {
    .scroll-cue { animation: none; }
  }

  .examples {
    display: grid;
    gap: clamp(2.25rem, 5vw, 3.5rem);
    padding: clamp(3rem, 8vw, 5rem) 0;
  }

  .example {
    display: grid;
    gap: 1rem;
  }

  .ex-head {
    display: flex;
    align-items: baseline;
    gap: 1rem;
  }

  .ex-num {
    font-size: 11px;
    letter-spacing: 0.16em;
    color: var(--dim);
  }

  .ex-head h2 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: clamp(1.05rem, 1.8vw, 1.25rem);
    font-weight: 500;
    letter-spacing: -0.01em;
    color: var(--fg);
  }

  .ex-note {
    margin: 0;
    font-size: 13.5px;
    line-height: 1.6;
    color: color-mix(in srgb, var(--fg) 68%, transparent);
  }

  .features {
    border-top: 1px solid var(--line-soft);
    padding: clamp(3rem, 7vw, 4.5rem) 0 0;
  }

  .features ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 0.85rem 2rem;
    font-size: 13.5px;
    color: color-mix(in srgb, var(--fg) 80%, transparent);
  }

  .features li {
    display: flex;
    gap: 0.75rem;
    align-items: baseline;
  }

  .bullet {
    color: var(--muted);
  }

  @media (max-width: 540px) {
    .ex-head {
      flex-direction: column;
      gap: 0.25rem;
      align-items: flex-start;
    }
  }
</style>
