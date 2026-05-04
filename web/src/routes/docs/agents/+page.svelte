<script>
  import { base } from '$app/paths';
  import CodeBlock from '$lib/CodeBlock.svelte';
  import ScrollProgress from '$lib/ScrollProgress.svelte';
  import { GITHUB_URL } from '$lib/links.js';

  // Copy-as-markdown action. The full AGENTS.md is mirrored at
  // /static/AGENTS.md so it's served untouched alongside the site —
  // agents can pull it directly via that URL too.
  let copyState = $state('idle'); // 'idle' | 'copied' | 'error'
  let copyTimer;

  async function copyMarkdown() {
    try {
      const res = await fetch(`${base}/AGENTS.md`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const text = await res.text();
      await navigator.clipboard.writeText(text);
      copyState = 'copied';
    } catch {
      copyState = 'error';
    }
    clearTimeout(copyTimer);
    copyTimer = setTimeout(() => { copyState = 'idle'; }, 2000);
  }

  const SECTIONS = [
    { id: 'why',          label: 'Why' },
    { id: 'hard-rule',    label: 'Hard rule' },
    { id: 'picking',      label: 'Picking a primitive' },
    { id: 'anatomy',      label: 'Coordinator anatomy' },
    { id: 'protocols',    label: 'Three protocols' },
    { id: 'discipline',   label: 'Separation' },
    { id: 'patterns',     label: 'Quick patterns' },
    { id: 'deep-link',    label: 'Deep linking' },
    { id: 'previews',     label: 'Previews' },
    { id: 'mistakes',     label: 'Common mistakes' },
    { id: 'compat',       label: 'Compatibility' },
    { id: 'tldr',         label: 'TL;DR' }
  ];

  // ── Code samples (mirror AGENTS.md verbatim where it shows code) ─────

  const CODE_NESTED_BAD = `// ❌ Wrong — nested NavigationStack breaks routing.
func detail(item: Item) -> some View {
    NavigationStack {       // ← don't.
        DetailRoot(item: item)
    }
}

// ✅ Right — child FlowCoordinator gets its own NavigationStack at the
//    coordinator boundary, where SwiftUI handles it correctly.
func detail(item: Item) -> any Coordinatable {
    DetailCoordinator(item: item)
}`;

  const CODE_DECISION_TREE = `Is it a push/pop on the current stack?
├─ Yes → coordinator.route(to: .someDestination)
│
└─ No, it's a modal.
   │
   Is the modal a single screen — confirmation, info dialog,
   simple form, picker?
   │
   ├─ Yes → SwiftUI native: .sheet(item:) / .fullScreenCover(item:)
   │
   └─ No, the modal contains its own navigation flow
      (multiple steps, push, dismiss-with-result, etc.).
      │
      → coordinator.present(.flow, as: .sheet)
        (returns a child coordinator from the route function)`;

  const CODE_ANATOMY = `@MainActor @Observable @Scaffoldable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    // Required: the observable container that owns the stack.
    var stack = FlowStack<HomeCoordinator>(root: .home)

    // Routes — each becomes a \`Destinations\` enum case.
    func home()             -> some View         { HomeView() }
    func detail(item: Item) -> some View         { DetailView(item: item) }
    func settings()         -> any Coordinatable { SettingsCoordinator() }

    // Optional helpers (regular methods, not auto-generated).
    func openDetail(_ item: Item) {
        route(to: .detail(item: item))
    }
}`;

  const CODE_CONCRETE_VS_EXISTENTIAL = `// ❌ Won't be picked up — concrete type.
func login() -> LoginCoordinator { LoginCoordinator() }

// ✅ Existential — macro generates a \`.login\` case.
func login() -> any Coordinatable { LoginCoordinator() }`;

  const CODE_IGNORED = `@ScaffoldingIgnored
func customize(_ view: AnyView) -> some View {
    view
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { /* shared toolbar */ }
}`;

  const CODE_HIERARCHY = `AppCoordinator (Root)
├── LoginCoordinator (Flow)              ← unauthenticated
└── MainTabCoordinator (Tab)             ← authenticated
    ├── HomeCoordinator (Flow)
    │   └── DetailView (push) + SettingsCoordinator (modal)
    └── ProfileCoordinator (Flow)
        └── EditProfileView (push)`;

  const CODE_RESULT_PRESENTER = `// AppCoordinator
func login(onComplete: @escaping @MainActor (AuthToken) -> Void) -> any Coordinatable {
    LoginCoordinator(onComplete: onComplete)
}

func startLogin() {
    present(.login(onComplete: { [weak self] token in
        self?.session = token
    }), as: .sheet)
}`;

  const CODE_RESULT_PRESENTED = `func submit() {
    onComplete(AuthToken(...))    // deliver result
    dismissCoordinator()          // dismiss self
}`;

  const CODE_PATTERN_SHEET_FLOW = `@MainActor @Observable @Scaffoldable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)

    func home() -> some View { HomeView() }
    func detail(item: Item) -> some View { DetailView(item: item) }
    func settings() -> any Coordinatable { SettingsCoordinator() }

    func openSettings() {
        present(.settings, as: .sheet)
    }
}`;

  const CODE_PATTERN_NATIVE_SHEET = `// Coordinator: no \`.confirmation\` route — that's an internal view detail.
@MainActor @Observable @Scaffoldable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)
    func home() -> some View { HomeView() }
}

// View: native sheet + local \`@State\`. The confirmation isn't a flow,
// it's a single screen — keep it native.
struct HomeView: View {
    @Environment(HomeCoordinator.self) private var coordinator
    @State private var pendingDelete: Item?

    var body: some View {
        List(items) { item in
            Button(item.name) { pendingDelete = item }
        }
        .sheet(item: $pendingDelete) { item in
            ConfirmDeleteSheet(item: item) {
                /* perform delete */
            }
        }
    }
}`;

  const CODE_PATTERN_AUTH = `@MainActor @Observable @Scaffoldable
final class AppCoordinator: @MainActor RootCoordinatable {
    var root = Root<AppCoordinator>(root: .unauthenticated)

    func unauthenticated() -> any Coordinatable { LoginCoordinator() }
    func authenticated()   -> any Coordinatable { MainTabCoordinator() }

    func signIn()  { setRoot(.authenticated) }
    func signOut() { setRoot(.unauthenticated) }
}`;

  const CODE_PATTERN_TAB = `@MainActor @Observable @Scaffoldable
final class MainTabCoordinator: @MainActor TabCoordinatable {
    var tabItems = TabItems<MainTabCoordinator>(tabs: [.home, .profile])

    func home() -> (any Coordinatable, some View) {
        (HomeCoordinator(), Label("Home", systemImage: "house"))
    }
    func profile() -> (any Coordinatable, some View) {
        (ProfileCoordinator(), Label("Profile", systemImage: "person"))
    }
}`;

  const CODE_DEEPLINK = `@Scaffoldable @Observable
final class AppCoordinator: @MainActor RootCoordinatable {
    var root = Root<AppCoordinator>(root: .unauthenticated)

    func unauthenticated() -> any Coordinatable { LoginCoordinator() }
    func authenticated()   -> any Coordinatable { MainTabCoordinator() }

    /// Land on the user's profile from a URL / push / quick action.
    /// Each \`<T: Coordinatable>\` overload hands the next step a typed
    /// reference to the freshly-resolved child.
    func openProfile(userId: Int) {
        setRoot(.authenticated) { (tab: MainTabCoordinator) in
            tab.selectFirstTab(.profile) { (profile: ProfileCoordinator) in
                profile.route(to: .userDetail(id: userId))
            }
        }
    }
}`;

  const CODE_DEEPLINK_URL = `WindowGroup {
    coordinator.view
        .onOpenURL { url in
            if let userId = parseUserURL(url) {
                coordinator.openProfile(userId: userId)
            }
        }
}`;

  const CODE_PREVIEW_BAD = `// ❌ The macro doesn't synthesise an initial-route initialiser.
//    There's no \`init(initialRoute:)\` to seed a non-default starting
//    case from a preview.
#Preview {
    HomeCoordinator(initialRoute: .detail(item: planet)).view
}`;

  const CODE_PREVIEW_OK = `// ✅ Preview the coordinator at its actual root...
#Preview("Coordinator · root") {
    HomeCoordinator().view
}

// ✅ ...or render the leaf view directly and inject what it reads
//    from the environment.
#Preview("DetailView · pushed") {
    DetailView(item: .earth)
        .environment(HomeCoordinator())   // satisfies @Environment(HomeCoordinator.self)
}`;

  const CODE_ADAPTIVE_BAR = `import SwiftUI
import Scaffolding

/// Reusable top bar that adapts to how the current screen was reached.
/// Reads the routing metadata Scaffolding injects automatically into
/// every materialised destination via \`\\.destination\`.
struct AdaptiveTopBar: View {
    let title: String

    @Environment(\\.destination) private var destination
    @Environment(\\.dismiss)     private var dismiss

    var body: some View {
        HStack {
            switch destination.routeType {
            case .push:
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
            case .sheet, .fullScreenCover:
                Button("Close") { dismiss() }
            case .root:
                Color.clear.frame(width: 24)
            }
            Spacer()
            Text(title).font(.headline)
            Spacer()
            Color.clear.frame(width: 24, height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}`;

  const CODE_MISTAKE_NESTED = `// ❌ Breaks \`route(to:)\` from the parent flow.
func detail(item: Item) -> some View {
    NavigationStack {
        DetailScreen(item: item)
    }
}`;

  const CODE_MISTAKE_CONCRETE = `// ❌ Macro skips this — it doesn't recognise concrete types as routes.
func login() -> LoginCoordinator { LoginCoordinator() }`;

  const CODE_MISTAKE_VIEW_STATE = `// ❌ Defeats the point of coordinators.
struct HomeView: View {
    @State private var pushedDetail: Item?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List(...)
                .navigationDestination(item: $pushedDetail) { ... }
                .sheet(isPresented: $showSettings) { ... }
        }
    }
}`;

  const CODE_MISTAKE_OLD_API = `// ❌ Old, no longer exists.
coordinator.route(to: .settings, as: .sheet)

// ✅ Correct.
coordinator.present(.settings, as: .sheet)`;

  const CODE_MISTAKE_NAVLINK = `// ❌ Couples the row to navigation; breaks under modular coordinators.
NavigationLink(value: planet) { Label(planet.name, ...) }

// ✅ Plain Button + coordinator call.
Button {
    coordinator.route(to: .detail(item: planet))
} label: {
    Label(planet.name, ...)
}`;

  const CODE_MISTAKE_DISMISS = `// ❌ Dismisses the entire coordinator, not just the current screen.
struct DetailView: View {
    @Environment(HomeCoordinator.self) private var coordinator
    var body: some View {
        Button("Back") { coordinator.dismissCoordinator() }
    }
}`;
</script>

<ScrollProgress sections={SECTIONS} />

<main class="docs">
  <article class="article">
    <header class="hero">
      <p class="eyebrow">Agent guide · Best practices</p>
      <h1>Scaffolding for agents.</h1>
      <p class="lede">
        A reference for LLM coding agents (and humans) writing SwiftUI
        code with the <strong>Scaffolding</strong> library. Read this
        before generating navigation code in any project that uses
        Scaffolding.
      </p>
      <aside class="thesis" role="note">
        <span class="thesis-tag">Thesis</span>
        <p>
          Scaffolding's value is <strong>modular navigation across
          coordinator boundaries</strong>. The win is separation of
          concerns — UI views never own navigation state. If you produce
          code that mixes navigation state into views, you've lost the
          reason to use the library.
        </p>
      </aside>
      <div class="actions">
        <button
          type="button"
          class="copy-btn"
          class:is-copied={copyState === 'copied'}
          class:is-error={copyState === 'error'}
          onclick={copyMarkdown}
          aria-live="polite"
        >
          <span class="copy-icon" aria-hidden="true">
            {#if copyState === 'copied'}✓{:else if copyState === 'error'}!{:else}⧉{/if}
          </span>
          <span class="copy-label">
            {#if copyState === 'copied'}Copied to clipboard{:else if copyState === 'error'}Copy failed — try again{:else}Copy as Markdown{/if}
          </span>
        </button>
        <a class="raw-link" href={`${base}/AGENTS.md`} target="_blank" rel="noopener">
          View raw <code>AGENTS.md</code> →
        </a>
      </div>
      <p class="meta">
        Source on <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>.
        See also the <a href={`${base}/docs`}>library overview</a> and
        the <a href={`${base}/docs/api`}>API reference</a>.
      </p>
    </header>

    <section id="why" class="sec">
      <h2>Why Scaffolding exists</h2>
      <p>
        SwiftUI's <code>NavigationStack(path:)</code> works for a single,
        self-contained screen graph. It breaks down once an app has:
      </p>
      <ul class="bullets">
        <li>multiple feature modules that need to push into each other,</li>
        <li>destination types defined in different modules,</li>
        <li>coordinator-driven flows (login, onboarding, settings sheets),</li>
        <li>programmatic navigation that has to compose across module boundaries.</li>
      </ul>
      <p>
        <code>NavigationStack</code> keeps navigation
        <strong>inside the view tree</strong>. That's the design
        constraint Scaffolding is built to escape. A
        <code>FlowCoordinatable</code> <em>is</em> a
        <code>NavigationStack</code> — but its destinations live on the
        coordinator (a plain Swift class), the macro generates the
        destination enum, and child coordinators slot in as routes
        without the view tree knowing.
      </p>
      <p>
        If you find yourself reaching for
        <code>NavigationStack(path:)</code> inside a Scaffolding project,
        <strong>stop</strong>. There is almost certainly a
        coordinator-side answer.
      </p>
    </section>

    <section id="hard-rule" class="sec">
      <h2>The hard rule: do not nest <code>NavigationStack</code></h2>
      <p>
        <code>FlowCoordinatable</code> already wraps a
        <code>NavigationStack</code> internally. SwiftUI does
        <strong>not</strong> compose <code>NavigationStack</code>s with
        each other — the inner stack swallows pushes that should belong
        to the outer one, and <code>route(to:)</code> stops doing what
        you expect.
      </p>
      <aside class="caveat" role="note">
        <span class="caveat-tag">Never</span>
        <div class="caveat-body">
          <p>
            <strong>Never put a <code>NavigationStack</code> inside any
            view returned by a <code>FlowCoordinatable</code> route
            function.</strong>
            Not in the root view, not in a pushed detail view, not in a
            customise wrapper.
          </p>
          <p>
            The same applies to anything that wraps SwiftUI's stack:
            <code>NavigationView</code>, <code>NavigationSplitView</code>,
            custom containers that hold a <code>NavigationPath</code>.
            They all conflict.
          </p>
        </div>
      </aside>
      <p>If a screen needs its own navigation hierarchy, give it a child coordinator:</p>
      <CodeBlock code={CODE_NESTED_BAD} label="Detail · child coordinator instead of nested stack" />
    </section>

    <section id="picking" class="sec">
      <h2>Picking a navigation primitive</h2>
      <p>When a user-facing transition needs to happen, use this decision tree:</p>
      <pre class="ascii"><code>{CODE_DECISION_TREE}</code></pre>

      <h3>Concretely</h3>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>You want…</th><th>Use</th></tr>
          </thead>
          <tbody>
            <tr><td>Push a screen onto the current flow</td><td><code>coordinator.route(to: .screen(args:))</code></td></tr>
            <tr><td>Pop the current screen</td><td><code>coordinator.pop()</code></td></tr>
            <tr><td>Pop everything above the root</td><td><code>coordinator.popToRoot()</code></td></tr>
            <tr><td>Show a confirmation dialog</td><td>SwiftUI's <code>.alert</code> / <code>.confirmationDialog</code></td></tr>
            <tr><td>Show a one-screen sheet (simple form, info)</td><td>SwiftUI's <code>.sheet(item:)</code></td></tr>
            <tr><td>Show a multi-step sub-flow</td><td><code>coordinator.present(.subflow, as: .sheet)</code></td></tr>
            <tr><td>Show a full-screen sub-flow</td><td><code>coordinator.present(.subflow, as: .fullScreenCover)</code></td></tr>
            <tr><td>Atomically replace the entire view hierarchy (auth, onboarding)</td><td><code>appCoordinator.setRoot(.authenticated)</code> (on a <code>RootCoordinatable</code>)</td></tr>
            <tr><td>Switch tabs programmatically</td><td><code>tabCoordinator.selectFirstTab(.home)</code></td></tr>
          </tbody>
        </table>
      </div>
      <p class="sub">
        Stay native for view-only modals. The native modifier is
        lighter, requires no coordinator boundary, and avoids the
        overhead of an extra <code>Destinations</code> case.
      </p>
    </section>

    <section id="anatomy" class="sec">
      <h2>Coordinator anatomy</h2>
      <CodeBlock code={CODE_ANATOMY} label="HomeCoordinator.swift" />

      <h3>Auto-tracked return types</h3>
      <p class="sub">
        The <code>@Scaffoldable</code> macro generates a
        <code>Destinations</code> enum with one case per function whose
        return type is one of:
      </p>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>Return type</th><th>What it generates</th></tr>
          </thead>
          <tbody>
            <tr><td><code>some View</code></td><td>A view destination</td></tr>
            <tr><td><code>any Coordinatable</code></td><td>A child-coordinator destination</td></tr>
            <tr><td><code>(any Coordinatable, some View)</code></td><td>Tab tuple (coordinator + label)</td></tr>
            <tr><td><code>(some View, some View)</code></td><td>Tab tuple (view-only + label)</td></tr>
            <tr><td><code>(any Coordinatable, some View, TabRole)</code></td><td>Tab tuple with role</td></tr>
            <tr><td><code>(some View, some View, TabRole)</code></td><td>Tab tuple with role + view-only</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        Anything else — including a <strong>concrete</strong>
        coordinator type like <code>-&gt; LoginCoordinator</code> — is
        <strong>not</strong> recognised. For a child coordinator the
        return type <strong>must</strong> be
        <code>any Coordinatable</code> (the existential).
      </p>
      <CodeBlock code={CODE_CONCRETE_VS_EXISTENTIAL} label="Concrete vs. existential" />

      <h3>Marking exclusions</h3>
      <p>
        Use <code>@ScaffoldingIgnored</code> whenever a method returns
        one of the auto-tracked types but <strong>isn't</strong> a
        destination — typically a <code>customize(_:)</code> override or
        a helper view builder shared between screens:
      </p>
      <CodeBlock code={CODE_IGNORED} label="@ScaffoldingIgnored on customize" />
      <p>
        Use <code>@ScaffoldingTracked</code> only when you want the
        <em>opposite</em> default — explicit opt-in. After applying it
        once, only methods carrying <code>@ScaffoldingTracked</code> are
        emitted as destinations.
      </p>
    </section>

    <section id="protocols" class="sec">
      <h2>Three coordinator protocols</h2>
      <p>Pick by user-facing structure, not by mood.</p>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>Protocol</th><th>Use when</th></tr>
          </thead>
          <tbody>
            <tr>
              <td><code>FlowCoordinatable</code></td>
              <td>Push/pop navigation. The workhorse. Wraps a <code>NavigationStack</code>.</td>
            </tr>
            <tr>
              <td><code>TabCoordinatable</code></td>
              <td>Tab bar where each tab is independent. Each tab's content is its own coordinator.</td>
            </tr>
            <tr>
              <td><code>RootCoordinatable</code></td>
              <td>Atomic root swap: auth flow ↔ main app, onboarding ↔ home. The whole tree is replaced when <code>setRoot(_:)</code> is called.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p>A typical app uses all three:</p>
      <pre class="ascii"><code>{CODE_HIERARCHY}</code></pre>
      <p>
        <code>setRoot</code> flips between the two <code>App</code>
        children. The tab coordinator owns the home/profile flows. Each
        flow handles its own pushes and modals.
      </p>
    </section>

    <section id="discipline" class="sec">
      <h2>Separation of concerns — the discipline</h2>
      <p>
        This is the part that makes Scaffolding worth using. If you
        violate it, you've reintroduced the problems Scaffolding was
        built to solve.
      </p>

      <h3>Views never own navigation state</h3>
      <ul class="rules">
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">A view holds <code>@State path: [SomeType]</code>.</span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">A view holds <code>@State isPresented = false</code> for a sheet that's part of the flow.</span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">A view receives <code>@Binding path: [SomeType]</code> to pop.</span>
        </li>
        <li>
          <span class="rule-tag good">Do</span>
          <span class="rule-body">A view reads its coordinator from <code>@Environment</code> and calls <code>coordinator.route(to:)</code>, <code>coordinator.pop()</code>, <code>coordinator.present(_:as:)</code> etc.</span>
        </li>
      </ul>

      <h3>Coordinators don't know how their views render</h3>
      <ul class="rules">
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">A coordinator imports SwiftUI just to construct a <code>NavigationStack</code>.</span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">A coordinator reads <code>@Environment</code> (it's not a View).</span>
        </li>
        <li>
          <span class="rule-tag good">Do</span>
          <span class="rule-body">A coordinator's job is route declaration + state mutation. The macro and the framework wire the views to the stack.</span>
        </li>
      </ul>

      <h3>Modules expose coordinators, not views</h3>
      <p>In a multi-module app, the right unit of import is the coordinator type:</p>
      <CodeBlock code={`import HomeFeature

let home = HomeCoordinator()
appRoot.setRoot(.home(home))`} label="Cross-module composition" />
      <p>
        Other modules don't need to know what views are inside, what
        destinations exist, or how the flow is structured. They hold a
        coordinator reference and route to its surface.
      </p>

      <h3>Result delivery between coordinators</h3>
      <p>When a presented coordinator needs to return a value, take the callback in the route function:</p>
      <CodeBlock code={CODE_RESULT_PRESENTER} label="AppCoordinator · presenter" />
      <p>Inside <code>LoginCoordinator</code>, when the user finishes:</p>
      <CodeBlock code={CODE_RESULT_PRESENTED} label="LoginCoordinator · presented" />
      <p>
        The presenter doesn't observe the presented coordinator's
        state. The presented coordinator hands a result back through
        the closure it was constructed with, then dismisses itself.
        Clean boundaries.
      </p>

      <h3><code>dismissCoordinator()</code> semantics</h3>
      <p>
        <code>dismissCoordinator()</code> is called on the coordinator
        being removed. It pops the <strong>whole coordinator</strong>
        off its parent — not a screen. For a sheet/cover, that closes
        the modal. For a pushed child coordinator, that removes the
        child and any of its own pushed destinations.
      </p>
      <p>
        To pop a single screen within the same flow, use
        <code>pop()</code>. The two are not interchangeable.
      </p>
    </section>

    <section id="patterns" class="sec">
      <h2>Quick patterns</h2>

      <h3>A flow with a sheet that's a sub-flow</h3>
      <CodeBlock code={CODE_PATTERN_SHEET_FLOW} label="HomeCoordinator with present(.settings, as: .sheet)" />

      <h3>A flow with a one-screen view-only sheet</h3>
      <CodeBlock code={CODE_PATTERN_NATIVE_SHEET} label="Coordinator + native .sheet" />

      <h3>Atomic auth swap</h3>
      <CodeBlock code={CODE_PATTERN_AUTH} label="AppCoordinator · RootCoordinatable" />

      <h3>Tab bar with independent flows</h3>
      <CodeBlock code={CODE_PATTERN_TAB} label="MainTabCoordinator" />
    </section>

    <section id="deep-link" class="sec">
      <h2>Deep linking</h2>
      <p>
        Every navigation method that resolves a child coordinator
        (<code>route</code>, <code>setRoot</code>,
        <code>appendTab</code>, <code>insertTab</code>,
        <code>popToFirst</code>, <code>popToLast</code>,
        <code>selectFirstTab</code>, <code>selectLastTab</code>,
        <code>select(index:)</code>, <code>select(id:)</code>) ships
        an overload constrained to <code>{'<T: Coordinatable>'}</code>
        with a trailing closure. (<code>present(_:as:)</code> itself
        has no typed overload — present a coordinator, then chain typed
        calls on the routes inside it.)
        The closure fires after the route lands, receiving a typed
        reference to the freshly-resolved child — chain them to walk
        the tree from a cold launch.
      </p>
      <CodeBlock code={CODE_DEEPLINK}     label="AppCoordinator · openProfile(userId:)" />
      <CodeBlock code={CODE_DEEPLINK_URL} label="MyApp · onOpenURL" />

      <ul class="rules">
        <li>
          <span class="rule-tag good">Do</span>
          <span class="rule-body">
            Pick the concrete coordinator type that matches the
            route's return signature for <code>T</code>. The closure
            only fires if the cast succeeds.
          </span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">
            Store handles to child coordinators outside the chain.
            The typed overloads exist so you don't have to — they
            hand you the right reference at the right time.
          </span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">
            Deep-link in pieces from a view. Deep-linking belongs on
            the coordinator (or on whatever orchestrator owns the
            URL/push entry point), and views call into it. A view
            that dispatches multiple <code>route(to:)</code> /
            <code>setRoot(_:)</code> calls in sequence is a smell.
          </span>
        </li>
      </ul>
    </section>

    <section id="previews" class="sec">
      <h2>Previews</h2>
      <p>
        SwiftUI's <code>#Preview</code> and Scaffolding's
        <code>@Scaffoldable</code> are both compile-time macros, but
        they don't compose at runtime the way you might expect. When
        generating preview code in a Scaffolding project, follow these
        rules — they save the user from chasing phantom bugs.
      </p>

      <ul class="rules">
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">
            Generate <code>HomeCoordinator(initialRoute: .detail)</code>.
            The macro doesn't emit an init that takes a starting
            destination — there's nothing to call.
          </span>
        </li>
        <li>
          <span class="rule-tag good">Do</span>
          <span class="rule-body">
            Preview the coordinator at its real root
            (<code>HomeCoordinator().view</code>), or render the leaf
            view directly and inject the coordinator it reads.
          </span>
        </li>
      </ul>

      <CodeBlock code={CODE_PREVIEW_BAD} label="Won't compile" />
      <CodeBlock code={CODE_PREVIEW_OK}  label="Two patterns that do work" />

      <ul class="rules">
        <li>
          <span class="rule-tag good">Do</span>
          <span class="rule-body">
            For any view that declares
            <code>@Environment(SomeCoordinator.self)</code>, attach
            <code>.environment(SomeCoordinator())</code> in the
            preview. Without it, the lookup falls back to a default
            (or crashes on Swift 6).
          </span>
        </li>
        <li>
          <span class="rule-tag bad">Don't</span>
          <span class="rule-body">
            Make rendering decisions that depend on
            <code>destination.routeType</code> /
            <code>destination.presentationType</code> /
            <code>destination.meta</code> showing the runtime value in
            previews. The destination env value is set when
            Scaffolding materialises a route — a preview that renders
            a leaf view gets the default
            (<code>.root</code>), regardless of how the screen would
            be reached at runtime.
          </span>
        </li>
      </ul>

      <h3>Adaptive bars from <code>\.destination</code></h3>
      <p>
        The flip side of caveat 3: at <em>runtime</em> the destination
        environment is reliable, and its public properties are exactly
        what you need to write a single reusable chrome that adapts to
        push / sheet / cover / root context. The pattern below is the
        canonical use of <code>destination.routeType</code>:
      </p>
      <CodeBlock code={CODE_ADAPTIVE_BAR} label="AdaptiveTopBar.swift" />
      <p class="sub">
        Switch on <code>destination.meta</code> when the same view
        renders different layouts depending on which generated case
        led to it. The <code>Meta</code> enum is emitted alongside
        <code>Destinations</code> by the macro.
      </p>
    </section>

    <section id="mistakes" class="sec">
      <h2>Common mistakes — what NOT to generate</h2>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">01</span>
          <h3>Wrapping a destination view in <code>NavigationStack</code></h3>
        </header>
        <CodeBlock code={CODE_MISTAKE_NESTED} label="Anti-pattern · nested NavigationStack" />
        <p class="sub">
          Drop the <code>NavigationStack</code>. The parent flow already
          provides one.
        </p>
      </div>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">02</span>
          <h3>Concrete coordinator return types</h3>
        </header>
        <CodeBlock code={CODE_MISTAKE_CONCRETE} label="Anti-pattern · concrete return type" />
        <p class="sub">Use <code>any Coordinatable</code>.</p>
      </div>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">03</span>
          <h3>Holding navigation state in a view</h3>
        </header>
        <CodeBlock code={CODE_MISTAKE_VIEW_STATE} label="Anti-pattern · view-owned state" />
        <p class="sub">
          Move pushes to the coordinator
          (<code>coordinator.route(to: .detail(item:))</code>). Keep the
          sheet only if it's a true single-screen view-only modal.
        </p>
      </div>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">04</span>
          <h3><code>route(to:as:)</code> (old API)</h3>
        </header>
        <p>
          That API was split. Push uses <code>route(to:)</code>. Modals
          use <code>present(_:as:)</code>. There is no <code>as:</code>
          parameter on <code>route</code> anymore.
        </p>
        <CodeBlock code={CODE_MISTAKE_OLD_API} label="Anti-pattern · old combined API" />
      </div>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">05</span>
          <h3>Reaching for <code>NavigationLink</code> to push</h3>
        </header>
        <CodeBlock code={CODE_MISTAKE_NAVLINK} label="Anti-pattern · NavigationLink coupling" />
      </div>

      <div class="mistake">
        <header class="mistake-head">
          <span class="mistake-num">06</span>
          <h3>Calling <code>dismissCoordinator()</code> to close a single screen</h3>
        </header>
        <CodeBlock code={CODE_MISTAKE_DISMISS} label="Anti-pattern · misusing dismissCoordinator" />
        <p class="sub">
          Use <code>coordinator.pop()</code> — or SwiftUI's
          <code>@Environment(\.dismiss)</code>, which works because
          Scaffolding wraps <code>NavigationStack</code>. Save
          <code>dismissCoordinator()</code> for "close the whole
          sub-flow" cases.
        </p>
      </div>
    </section>

    <section id="compat" class="sec">
      <h2>Compatibility notes</h2>
      <ul class="bullets">
        <li>Scaffolding requires Swift 6.2 (<code>@Observable</code>, the macro toolchain, strict concurrency). The package's <code>swift-tools-version</code> is <code>6.2</code>.</li>
        <li>Platform floor: iOS 18 / macOS 15 / tvOS 18 / watchOS 11 / macCatalyst 18. <code>TabRole</code> is available unconditionally on this floor.</li>
        <li><code>onDismiss</code> and the deep-link trailing closures are typed <code>@MainActor () -&gt; Void</code> / <code>@MainActor (T) -&gt; Void</code>. Annotate any closures you forward.</li>
        <li>Scaffolding plays well with SwiftUI's <code>@Environment(\.dismiss)</code>, <code>@Environment(\.scenePhase)</code>, <code>@Environment(\.openURL)</code>, etc. — those are native environment values that don't conflict with the coordinator injection.</li>
        <li>Scaffolding <strong>does</strong> conflict with anything that introduces another <code>NavigationStack</code> (or <code>NavigationView</code>, <code>NavigationSplitView</code>) inside a flow's view tree.</li>
      </ul>
    </section>

    <section id="tldr" class="sec">
      <h2>TL;DR for code generation</h2>
      <p>When asked to add navigation to a Scaffolding project:</p>
      <ol class="steps">
        <li>
          <strong>Don't generate <code>NavigationStack</code>,
          <code>NavigationView</code>, or
          <code>NavigationSplitView</code></strong> anywhere inside a
          <code>FlowCoordinatable</code>'s view hierarchy.
        </li>
        <li>
          Decide push vs. modal vs. root-swap, then pick
          <code>route(to:)</code> / <code>present(_:as:)</code> /
          <code>setRoot(_:)</code>.
        </li>
        <li>
          For modals, decide view-only vs. sub-flow:
          <ul class="bullets">
            <li>View-only → SwiftUI native <code>.sheet(item:)</code>.</li>
            <li>Sub-flow → <code>present(_:as:)</code> with a child coordinator.</li>
          </ul>
        </li>
        <li>
          New routes go on the coordinator as functions returning
          <code>some View</code>, <code>any Coordinatable</code>, or a
          tab tuple. Add the function — the macro generates the case.
        </li>
        <li>
          Views read the coordinator from
          <code>@Environment(MyCoordinator.self)</code> and call methods
          on it. Views never store path or sheet booleans for
          flow-driven navigation.
        </li>
        <li>
          Cross-coordinator results are delivered by the presenter
          installing an <code>onComplete</code> callback at construction
          time; the presented coordinator calls the callback then
          <code>dismissCoordinator()</code>.
        </li>
      </ol>
      <p class="sub">
        If you can't figure out which coordinator should own a
        destination, the answer is usually "the closest existing one" —
        don't invent new coordinator types just to host one route.
      </p>
    </section>

    <footer class="next">
      <h2>Keep reading</h2>
      <p>
        The same patterns documented here are demonstrated live in the
        landing page playground, and surfaced symbol-by-symbol in the
        API reference.
      </p>
      <p>
        <a href={`${base}/docs`}>Library overview →</a>
        &nbsp;·&nbsp;
        <a href={`${base}/docs/api`}>API reference →</a>
        &nbsp;·&nbsp;
        <a href={`${base}/docs/tutorial`}>Tutorial →</a>
      </p>
    </footer>
  </article>
</main>

<style>
  .docs {
    position: relative;
    z-index: 1;
    padding: clamp(3rem, 8vw, 5rem) 0 clamp(3rem, 6vw, 4rem);
  }

  .article {
    max-width: 960px;
    margin: 0 auto;
    padding: 0 clamp(1.25rem, 3.5vw, 2rem);
  }

  /* ── Hero ──────────────────────────────────────────────────────────── */

  .hero {
    border-bottom: 1px solid var(--line-soft);
    padding-bottom: clamp(2rem, 5vw, 3rem);
    margin-bottom: clamp(2rem, 5vw, 3rem);
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .eyebrow {
    margin: 0;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: var(--muted);
  }

  .hero h1 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: clamp(2rem, 5vw, 3rem);
    font-weight: 500;
    line-height: 1.05;
    letter-spacing: -0.025em;
    color: var(--fg);
  }

  .lede {
    margin: 0;
    font-size: 15px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 75%, transparent);
    max-width: 60ch;
  }
  .lede strong { color: var(--fg); font-weight: 500; }

  .meta {
    margin: 0.25rem 0 0;
    font-size: 12.5px;
    color: var(--muted);
  }
  .meta a,
  .next a {
    color: var(--fg);
    text-decoration: none;
    border-bottom: 1px solid color-mix(in srgb, var(--fg) 30%, transparent);
    transition: border-color 140ms ease;
  }
  .meta a:hover,
  .next a:hover {
    border-bottom-color: var(--fg);
  }

  /* Copy-as-Markdown action row. Sits between the thesis and the meta
     line so it's the second-most-prominent thing in the hero. */
  .actions {
    margin: 0.25rem 0 0;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.85rem 1rem;
  }

  .copy-btn {
    appearance: none;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    padding: 0.55rem 0.95rem;
    font-family: var(--font-mono);
    font-size: 12.5px;
    letter-spacing: 0.02em;
    color: var(--fg);
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 6px;
    line-height: 1;
    transition: background-color 140ms ease, border-color 140ms ease,
                color 140ms ease, transform 100ms ease;
  }
  .copy-btn:hover {
    border-color: color-mix(in srgb, var(--fg) 35%, transparent);
    background: color-mix(in srgb, var(--fg) 6%, var(--bg));
  }
  .copy-btn:active { transform: translateY(1px); }
  .copy-btn:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }
  .copy-btn.is-copied {
    color: var(--syn-ty);
    border-color: color-mix(in srgb, var(--syn-ty) 45%, transparent);
    background: color-mix(in srgb, var(--syn-ty) 8%, transparent);
  }
  .copy-btn.is-error {
    color: var(--syn-kw);
    border-color: color-mix(in srgb, var(--syn-kw) 45%, transparent);
    background: color-mix(in srgb, var(--syn-kw) 8%, transparent);
  }

  .copy-icon {
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1;
    width: 1ch;
    text-align: center;
  }
  .copy-label { line-height: 1; }

  .raw-link {
    font-family: var(--font-mono);
    font-size: 12.5px;
    color: var(--muted);
    text-decoration: none;
    border-bottom: 1px solid color-mix(in srgb, var(--fg) 18%, transparent);
    transition: color 140ms ease, border-color 140ms ease;
  }
  .raw-link:hover {
    color: var(--fg);
    border-bottom-color: var(--fg);
  }
  .raw-link code {
    font-family: var(--font-mono);
    font-size: inherit;
    color: inherit;
    background: transparent;
    border: 0;
    padding: 0;
  }

  /* Thesis — opening manifesto using the syn-ty accent so it reads as
     the central idea, distinct from the warning-flavored caveats. */
  .thesis {
    display: grid;
    grid-template-columns: 90px 1fr;
    gap: 1rem;
    padding: 0.95rem 1.05rem;
    margin: 0.25rem 0 0;
    border: 1px solid color-mix(in srgb, var(--syn-ty) 35%, transparent);
    border-radius: 6px;
    background: color-mix(in srgb, var(--syn-ty) 5%, transparent);
  }
  @media (max-width: 540px) {
    .thesis { grid-template-columns: 1fr; gap: 0.4rem; }
  }
  .thesis-tag {
    align-self: start;
    justify-self: start;
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--syn-ty);
    padding: 0.2rem 0.55rem;
    border-radius: 999px;
    border: 1px solid currentColor;
    background: color-mix(in srgb, var(--syn-ty) 8%, transparent);
    line-height: 1;
    margin-top: 0.1rem;
  }
  .thesis p {
    margin: 0;
    font-size: 13.5px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 80%, transparent);
  }
  .thesis p strong { color: var(--fg); font-weight: 500; }

  /* ── Sections ──────────────────────────────────────────────────────── */

  .sec {
    margin: 0 0 clamp(4rem, 8vw, 6rem);
    padding-top: clamp(2.5rem, 5vw, 4rem);
    border-top: 1px solid var(--line-soft);
    scroll-margin-top: 5rem;
  }
  .sec:first-of-type {
    margin-top: 0;
    padding-top: 0;
    border-top: 0;
  }

  .sec h2 {
    margin: 0 0 1rem;
    font-family: var(--font-mono);
    font-size: clamp(1.2rem, 2.4vw, 1.55rem);
    font-weight: 500;
    letter-spacing: -0.015em;
    color: var(--fg);
  }
  .sec h2 code {
    font-family: var(--font-mono);
    font-size: 0.9em;
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.4em;
    border-radius: 3px;
  }

  .sec h3 {
    margin: 1.5rem 0 0.5rem;
    font-family: var(--font-mono);
    font-size: clamp(0.95rem, 1.6vw, 1.05rem);
    font-weight: 500;
    color: var(--fg);
    letter-spacing: -0.005em;
  }
  .sec h3 code {
    font-family: var(--font-mono);
    font-size: 0.95em;
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.4em;
    border-radius: 3px;
  }

  .sec p {
    margin: 0 0 1rem;
    font-size: 14px;
    line-height: 1.7;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
  .sec p.sub {
    color: color-mix(in srgb, var(--fg) 60%, transparent);
    font-size: 13.5px;
  }
  .sec p strong {
    color: var(--fg);
    font-weight: 500;
  }
  .sec p em {
    color: var(--fg);
    font-style: italic;
  }

  /* Inline code (everywhere in prose). */
  .sec code,
  .lede code,
  .meta code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.4em;
    border-radius: 3px;
  }

  .sec :global(.block) {
    margin: 1rem 0 1.25rem;
  }

  /* ── Plain bullet list ─────────────────────────────────────────────── */

  .bullets {
    margin: 0 0 1rem;
    padding: 0 0 0 1.1rem;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }
  .bullets li {
    position: relative;
    font-size: 13.5px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
  .bullets li::before {
    content: '·';
    position: absolute;
    left: -1.1rem;
    top: 0;
    color: var(--muted);
    font-family: var(--font-mono);
  }
  .bullets li strong { color: var(--fg); font-weight: 500; }

  /* ── Rules list (do/don't) ─────────────────────────────────────────── */

  .rules {
    margin: 0.5rem 0 1.25rem;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.55rem;
  }

  .rules li {
    display: grid;
    grid-template-columns: 70px 1fr;
    gap: 0.85rem;
    align-items: center;
    padding: 0.6rem 0.85rem;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
  }

  @media (max-width: 540px) {
    .rules li {
      grid-template-columns: 1fr;
      gap: 0.4rem;
    }
  }

  .rule-tag {
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    padding: 0.18rem 0.5rem;
    border-radius: 999px;
    line-height: 1;
    justify-self: start;
    align-self: center;
    border: 1px solid currentColor;
    background: color-mix(in srgb, currentColor 8%, transparent);
  }
  .rule-tag.bad  { color: var(--syn-kw); }
  .rule-tag.good { color: var(--syn-ty); }

  .rule-body {
    font-size: 13.5px;
    line-height: 1.6;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
  .rule-body code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.35em;
    border-radius: 3px;
  }

  /* ── Caveat callout ────────────────────────────────────────────────── */

  .caveat {
    display: grid;
    grid-template-columns: 90px 1fr;
    gap: 1rem;
    padding: 0.95rem 1.05rem;
    margin: 1rem 0 0.5rem;
    border: 1px solid color-mix(in srgb, var(--syn-kw) 35%, transparent);
    border-radius: 6px;
    background: color-mix(in srgb, var(--syn-kw) 5%, transparent);
  }
  @media (max-width: 540px) {
    .caveat { grid-template-columns: 1fr; gap: 0.4rem; }
  }
  .caveat-tag {
    align-self: start;
    justify-self: start;
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--syn-kw);
    padding: 0.2rem 0.55rem;
    border-radius: 999px;
    border: 1px solid currentColor;
    background: color-mix(in srgb, var(--syn-kw) 8%, transparent);
    line-height: 1;
    margin-top: 0.1rem;
  }
  .caveat-body p {
    margin: 0 0 0.55rem;
    font-size: 13.5px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 80%, transparent);
  }
  .caveat-body p:last-child { margin-bottom: 0; }
  .caveat-body p strong { color: var(--fg); font-weight: 500; }
  .caveat-body code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: color-mix(in srgb, var(--syn-kw) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--syn-kw) 25%, transparent);
    padding: 0.05em 0.35em;
    border-radius: 3px;
  }

  /* ── Mistakes — numbered cards ─────────────────────────────────────── */

  .mistake {
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
    padding: 1rem 1.1rem 1.1rem;
    margin: 0.6rem 0 1rem;
  }
  .mistake-head {
    display: flex;
    align-items: baseline;
    gap: 0.85rem;
    margin: 0 0 0.5rem;
  }
  .mistake-num {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.16em;
    color: var(--syn-kw);
    flex-shrink: 0;
  }
  .mistake-head h3 {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 13.5px;
    font-weight: 500;
    color: var(--fg);
    line-height: 1.45;
    text-transform: none;
    letter-spacing: -0.005em;
  }
  .mistake-head h3 code {
    font-family: var(--font-mono);
    font-size: 0.95em;
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.4em;
    border-radius: 3px;
  }
  .mistake p.sub {
    margin: 0.5rem 0 0;
    color: color-mix(in srgb, var(--fg) 60%, transparent);
    font-size: 13px;
    line-height: 1.6;
    border-left: 2px solid var(--line);
    padding-left: 0.85rem;
  }
  .mistake p {
    font-size: 13.5px;
  }

  /* ── How-it-works numbered steps ───────────────────────────────────── */

  .steps {
    margin: 0 0 1.25rem;
    padding: 0;
    list-style: none;
    counter-reset: step;
    display: flex;
    flex-direction: column;
    gap: 0.7rem;
  }
  .steps > li {
    counter-increment: step;
    position: relative;
    padding-left: 2.5rem;
    font-size: 14px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
  .steps > li::before {
    content: counter(step, decimal-leading-zero);
    position: absolute;
    left: 0;
    top: 1px;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.08em;
    color: var(--dim);
  }
  .steps > li strong { color: var(--fg); font-weight: 500; }
  .steps .bullets { margin: 0.4rem 0 0; }

  /* ── Table ─────────────────────────────────────────────────────────── */

  .table-wrap {
    margin: 0.75rem 0 1rem;
    overflow-x: auto;
    border: 1px solid var(--line);
    border-radius: 6px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12.5px;
    font-family: var(--font-mono);
  }
  thead th {
    font-size: 10.5px;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--dim);
    text-align: left;
    padding: 0.65rem 0.85rem;
    background: color-mix(in srgb, var(--fg) 4%, transparent);
    border-bottom: 1px solid var(--line);
    font-weight: 500;
  }
  tbody td {
    padding: 0.65rem 0.85rem;
    border-bottom: 1px solid var(--line-soft);
    color: color-mix(in srgb, var(--fg) 80%, transparent);
    vertical-align: top;
  }
  tbody tr:last-child td { border-bottom: 0; }
  tbody td em { color: var(--muted); font-style: normal; font-size: 0.9em; }

  /* ── ASCII tree ────────────────────────────────────────────────────── */

  .ascii {
    margin: 0.5rem 0 1.25rem;
    padding: 1rem 1.25rem;
    font-family: var(--font-mono);
    font-size: 12.5px;
    line-height: 1.7;
    color: color-mix(in srgb, var(--fg) 80%, transparent);
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 6px;
    overflow-x: auto;
    white-space: pre;
  }

  /* ── Next-steps footer ─────────────────────────────────────────────── */

  .next {
    margin-top: clamp(2rem, 5vw, 3rem);
    padding-top: clamp(2rem, 5vw, 3rem);
    border-top: 1px solid var(--line-soft);
  }
  .next h2 {
    margin: 0 0 0.75rem;
    font-family: var(--font-mono);
    font-size: clamp(1.05rem, 1.8vw, 1.25rem);
    font-weight: 500;
    color: var(--fg);
  }
  .next p {
    margin: 0 0 0.75rem;
    font-size: 14px;
    line-height: 1.7;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
</style>
