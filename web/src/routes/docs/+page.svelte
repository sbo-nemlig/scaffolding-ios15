<script>
  import { base } from '$app/paths';
  import CodeBlock from '$lib/CodeBlock.svelte';
  import ScrollProgress from '$lib/ScrollProgress.svelte';
  import FlowSim from '$lib/FlowSim.svelte';
  import { GITHUB_URL, DOCC_URL } from '$lib/links.js';

  // Selected native-flavor for the comparison: 'view' (NavigationLink-driven)
  // or 'enum' (central typed-enum path).
  let nativeMode = $state('view');

  const SECTIONS = [
    { id: 'overview',   label: 'Overview' },
    { id: 'how',        label: 'How it works' },
    { id: 'mount',      label: 'Mounting' },
    { id: 'previews',   label: 'Previews' },
    { id: 'flow',       label: 'Flow' },
    { id: 'tab',        label: 'Tab' },
    { id: 'root',       label: 'Root' },
    { id: 'env',        label: 'Environment' },
    { id: 'composing',  label: 'Composing' },
    { id: 'deep-link',  label: 'Deep linking' },
    { id: 'dismiss',    label: 'Dismissing' },
    { id: 'customize',  label: 'Customize' },
    { id: 'vs-native',  label: 'vs NavigationStack' },
    { id: 'philosophy', label: 'When to use what' }
  ];

  // ── Code samples (mirror DocC's MeetScaffolding article + Scaffolding.md) ──

  // Mounting — how a coordinator becomes a SwiftUI scene/view.
  const CODE_MOUNT_APP = `import SwiftUI
import Scaffolding

@main
struct MyApp: App {
    // Hold the root coordinator in @State so SwiftUI keeps it alive
    // for the lifetime of the scene.
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            coordinator.view              // computed property — no parens
        }
    }
}`;

  const CODE_MOUNT_PREVIEW = `#Preview {
    HomeCoordinator().view
}`;

  const CODE_FLOW = `@Scaffoldable @Observable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)

    func home() -> some View { HomeView() }
    func detail(item: String) -> some View { DetailView(item: item) }
    func settings() -> any Coordinatable { SettingsCoordinator() }
}`;

  const CODE_FLOW_NAV = `coordinator.route(to: .detail(item: "Earth"))           // push
coordinator.present(.settings, as: .sheet)              // sheet
coordinator.present(.settings, as: .fullScreenCover)    // full-screen cover

coordinator.pop()
coordinator.popToRoot()
coordinator.popToFirst(.detail)
coordinator.popToLast(.detail)`;

  const CODE_TAB = `@Scaffoldable @Observable
final class MainTabCoordinator: @MainActor TabCoordinatable {
    var tabItems = TabItems<MainTabCoordinator>(tabs: [.feed, .profile])

    func feed() -> (any Coordinatable, some View) {
        (FeedCoordinator(), Label("Feed", systemImage: "list.bullet"))
    }

    func profile() -> (any Coordinatable, some View) {
        (ProfileCoordinator(), Label("Profile", systemImage: "person"))
    }
}`;

  const CODE_TAB_API = `coordinator.selectFirstTab(.feed)
coordinator.appendTab(.notifications)
coordinator.removeLastTab(.notifications)`;

  const CODE_ROOT = `@Scaffoldable @Observable
final class AppCoordinator: @MainActor RootCoordinatable {
    var root = Root<AppCoordinator>(root: .splash)

    func splash() -> some View { SplashView() }
    func authenticated()   -> any Coordinatable { MainTabCoordinator() }
    func unauthenticated() -> any Coordinatable { LoginCoordinator() }
}`;

  const CODE_ROOT_SET = `coordinator.setRoot(.authenticated)`;

  const CODE_ENV = `struct DetailView: View {
    @Environment(HomeCoordinator.self) private var coordinator

    var body: some View {
        Button("Next") {
            coordinator.route(to: .nextScreen)
        }
    }
}`;

  const CODE_ENV_DEST = `@Environment(\\.destination) private var destination

// destination.routeType        → .root, .push, .sheet, or .fullScreenCover
// destination.presentationType → how this view was presented globally
// destination.meta             → which case of Destinations this is`;

  // A reusable adaptive top bar. Reads the destination metadata from
  // the environment and swaps its leading control depending on how the
  // screen was reached — so the same bar renders correctly when the
  // view is a root, a pushed detail, or a presented sheet.
  const CODE_ADAPTIVE_BAR = `import SwiftUI
import Scaffolding

/// A top bar that adapts its leading control to how the screen was
/// reached. Drop it into any view managed by a Scaffolding coordinator
/// — \`\\.destination\` is injected automatically for every destination
/// the framework materialises.
struct AdaptiveTopBar: View {
    let title: String

    @Environment(\\.destination) private var destination
    // Scaffolding wraps NavigationStack, so SwiftUI's native dismiss
    // works for both pops (push) and modal dismissals.
    @Environment(\\.dismiss) private var dismiss

    var body: some View {
        HStack {
            switch destination.routeType {
            case .push:
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            case .sheet, .fullScreenCover:
                Button("Close") { dismiss() }
            case .root:
                // The root has no parent control — keep the layout
                // stable with a placeholder of the same width.
                Color.clear.frame(width: 24)
            }

            Spacer()
            Text(title).font(.headline)
            Spacer()

            // Mirror the leading control to keep the title centred.
            Color.clear.frame(width: 24, height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

// Use it from any screen — the same view shows a back chevron when
// pushed and a "Close" when presented as a sheet.
struct DetailView: View {
    let item: Planet
    var body: some View {
        VStack(spacing: 0) {
            AdaptiveTopBar(title: item.name)
            ...
        }
    }
}`;

  // Preview gotchas — keep snippets tight, the prose carries the rest.
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

  const CODE_COMPOSE = `@Scaffoldable @Observable
final class AppCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<AppCoordinator>(root: .home)

    var session: AuthToken?

    // A child Coordinatable as a route — the macro requires the return
    // type to be \`any Coordinatable\` (not the concrete type) to recognise
    // it as a coordinator destination. \`present(.login(...))\` then
    // resolves the LoginCoordinator and presents it as a sheet, with
    // the parent set automatically and the result delivered through
    // the \`onComplete\` callback the parent installs at construction time.
    func login(onComplete: @escaping @MainActor (AuthToken) -> Void) -> any Coordinatable {
        LoginCoordinator(onComplete: onComplete)
    }

    func startLoginFlow() {
        present(.login(onComplete: { [weak self] token in
            self?.session = token
        }), as: .sheet)
    }
}`;

  // Deep linking — chain the typed `<T: Coordinatable>` overloads to
  // walk the coordinator tree and seed each layer's state in one go.
  const CODE_DEEPLINK = `// AppCoordinator.swift
//
// Deep-link entry point. From a cold launch (URL, push notification,
// quick action), drive the coordinator tree to the exact target
// state by chaining the typed overloads — each \`<T: Coordinatable>\`
// variant gives you a typed handle on the resolved child once the
// route lands.
@Scaffoldable @Observable
final class AppCoordinator: @MainActor RootCoordinatable {
    var root = Root<AppCoordinator>(root: .unauthenticated)

    func unauthenticated() -> any Coordinatable { LoginCoordinator() }
    func authenticated()   -> any Coordinatable { MainTabCoordinator() }

    /// Open the user's profile from a cold launch.
    func openProfile(userId: Int) {
        // 1. Swap the root to authenticated → returns the new
        //    MainTabCoordinator typed correctly.
        setRoot(.authenticated) { (tab: MainTabCoordinator) in
            // 2. Select the profile tab → typed handle on its
            //    ProfileCoordinator (a FlowCoordinatable).
            tab.selectFirstTab(.profile) { (profile: ProfileCoordinator) in
                // 3. Push the user-detail screen on the profile flow.
                profile.route(to: .userDetail(id: userId))
            }
        }
    }
}`;

  const CODE_DEEPLINK_URL = `// MyApp.swift — wire the deep link from a URL.
@main
struct MyApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            coordinator.view
                .onOpenURL { url in
                    if let userId = parseUserURL(url) {
                        coordinator.openProfile(userId: userId)
                    }
                }
        }
    }
}`;

  const CODE_CUSTOMIZE = `@ScaffoldingIgnored
func customize(_ view: AnyView) -> some View {
    view
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { /* shared toolbar items */ }
}`;

  // Dismissing — nested coordinator flow.
  // Two coordinators: AppCoordinator hosts the main flow and presents
  // LoginCoordinator as a sheet. LoginCoordinator is itself a flow with
  // two steps (email → password). The submit button on the deepest
  // pushed screen calls dismissCoordinator() — closing the *entire*
  // sheet, not just the topmost step.

  const CODE_DISMISS_PARENT = `@Scaffoldable @Observable
final class AppCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<AppCoordinator>(root: .home)

    var session: AuthToken?

    func home() -> some View { HomeView() }

    // Child coordinator route — return type must be \`any Coordinatable\`
    // for the macro to recognise it as a coordinator destination.
    func login(onComplete: @escaping @MainActor (AuthToken) -> Void) -> any Coordinatable {
        LoginCoordinator(onComplete: onComplete)
    }

    func startLogin() {
        present(.login(onComplete: { [weak self] token in
            self?.session = token
        }), as: .sheet)
    }
}`;

  const CODE_DISMISS_CHILD = `@Scaffoldable @Observable
final class LoginCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<LoginCoordinator>(root: .email)

    let onComplete: @MainActor (AuthToken) -> Void

    init(onComplete: @escaping @MainActor (AuthToken) -> Void) {
        self.onComplete = onComplete
    }

    func email()                    -> some View { EmailStepView() }
    func password(email: String)    -> some View { PasswordStepView(email: email) }
}`;

  const CODE_DISMISS_VIEWS = `struct EmailStepView: View {
    @Environment(LoginCoordinator.self) private var coordinator
    @State private var email = ""

    var body: some View {
        Form {
            TextField("Email", text: $email)
            Button("Next") {
                coordinator.route(to: .password(email: email))   // push
            }
        }
    }
}

struct PasswordStepView: View {
    @Environment(LoginCoordinator.self) private var coordinator
    let email: String
    @State private var password = ""

    var body: some View {
        Form {
            SecureField("Password", text: $password)
            HStack {
                Button("Back")    { coordinator.pop() }                   // pop ONE screen
                Button("Sign in") {
                    let token = signIn(email: email, password: password)
                    coordinator.onComplete(token)
                    coordinator.dismissCoordinator()                       // close the whole sheet
                }
            }
        }
    }
}`;

  // Side-by-side comparison: same three-screen app, two ways.

  // Two flavors of the native NavigationStack(path:) approach. The
  // toggle in the comparison header switches between them so readers
  // can see how each shapes the call site.

  const CODE_NATIVE_VIEW = `// SwiftUI · NavigationStack(path:) · view-hosted

struct ContentView: View {
    @State private var path: [Planet] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List(planets) { planet in
                // The list row is itself the navigation link.
                NavigationLink(value: planet) {
                    Label(planet.name, systemImage: "globe")
                }
            }
            .navigationTitle("Planets")
            .navigationDestination(for: Planet.self) { planet in
                DetailView(item: planet, path: $path)
            }
            .toolbar {
                Button("Settings") { showSettings = true }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct DetailView: View {
    let item: Planet
    @Binding var path: [Planet]
    // Or, instead of holding the path binding, the view can lean on
    // SwiftUI's environment value for dismissal:
    // @Environment(\\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(item.name).font(.title)
            Button("Back") { path.removeLast() }
            // ...equivalently: Button("Back") { dismiss() }
        }
    }
}`;

  const CODE_NATIVE_ENUM = `// SwiftUI · NavigationStack(path:) · typed-enum

// Central destination type — the path holds heterogeneous routes
// type-safely, but you write the enum and switch yourself.
enum AppRoute: Hashable {
    case detail(Planet)
    // case settings, case profile(User), ... add cases as the app grows.
}

struct ContentView: View {
    @State private var path: [AppRoute] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List(planets) { planet in
                Button {
                    path.append(.detail(planet))
                } label: {
                    Label(planet.name, systemImage: "globe")
                }
            }
            .navigationTitle("Planets")
            // One destination handler per route type, with a switch
            // inside it. Every new case grows this method.
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .detail(let planet):
                    DetailView(item: planet, path: $path)
                }
            }
            .toolbar {
                Button("Settings") { showSettings = true }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct DetailView: View {
    let item: Planet
    @Binding var path: [AppRoute]
    // Or: @Environment(\\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(item.name).font(.title)
            Button("Back") { path.removeLast() }
        }
    }
}`;

  const CODE_SCAFFOLDING = `// Scaffolding · FlowCoordinatable

@Scaffoldable @Observable
final class HomeCoordinator: @MainActor FlowCoordinatable {
    var stack = FlowStack<HomeCoordinator>(root: .home)

    func home()               -> some View         { HomeView() }
    func detail(item: Planet) -> some View         { DetailView(item: item) }
    func settings()           -> any Coordinatable { SettingsCoordinator() }
}

struct HomeView: View {
    @Environment(HomeCoordinator.self) private var coordinator

    var body: some View {
        List(planets) { planet in
            Button {
                coordinator.route(to: .detail(item: planet))
            } label: {
                Label(planet.name, systemImage: "globe")
            }
        }
        .navigationTitle("Planets")
        .toolbar {
            Button("Settings") {
                coordinator.present(.settings, as: .sheet)
            }
        }
    }
}

struct DetailView: View {
    @Environment(HomeCoordinator.self) private var coordinator
    // Scaffolding uses NavigationStack underneath, so SwiftUI's native
    // environment dismiss still works alongside the coordinator API.
    @Environment(\\.dismiss) private var dismiss
    let item: Planet

    var body: some View {
        VStack {
            Text(item.name).font(.title)
            Button("Back") { coordinator.pop() }
            // ...or equivalently: Button("Back") { dismiss() }
        }
    }
}`;
</script>

<ScrollProgress sections={SECTIONS} />

<main class="docs">
  <article class="article">
    <header class="hero">
      <p class="eyebrow">Documentation</p>
      <h1>Meet Scaffolding.</h1>
      <p class="lede">
        Learn how Scaffolding turns plain Swift functions into type-safe
        navigation routes — and why you might never write a destination
        enum again.
      </p>
      <p class="meta">
        Companion to the hosted <a href={DOCC_URL} target="_blank" rel="noopener noreferrer">DocC archive</a>.
        Source on <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">GitHub</a>.
      </p>
    </header>

    <section id="overview" class="sec">
      <h2>Overview</h2>
      <p>
        Navigation in SwiftUI is powerful, but as apps grow it creates a
        familiar set of problems: navigation logic is scattered across views,
        destination enums must be maintained by hand, and deep linking
        requires plumbing that touches every layer of the app.
      </p>
      <p>
        Scaffolding solves this by moving navigation into <strong>coordinators</strong> —
        observable classes whose functions <em>are</em> the routes.
        The <code>@Scaffoldable</code> macro reads those functions at compile
        time and generates a <code>Destinations</code> enum automatically.
        You navigate by calling <code>route(to:)</code> to push or
        <code>present(_:as:)</code> to show a modal, and Scaffolding handles
        the rest using SwiftUI's native navigation stack, sheets, and
        full-screen covers under the hood.
      </p>
    </section>

    <section id="how" class="sec">
      <h2>How it works</h2>
      <ol class="steps">
        <li>Create a class and mark it <code>@Scaffoldable @Observable</code>.</li>
        <li>Conform to one of three coordinator protocols.</li>
        <li>Write functions — each one becomes a route.</li>
        <li>The macro generates a <code>Destinations</code> enum from those functions.</li>
        <li>
          Push with <code>coordinator.route(to: .someDestination)</code> or
          present a modal with <code>coordinator.present(.someDestination, as: .sheet)</code>.
        </li>
      </ol>

      <h3>Return types that become routes</h3>
      <p class="sub">
        The macro decides what kind of destination to generate based on the
        function's return type:
      </p>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>Return type</th><th>What it creates</th><th>Typical use</th></tr>
          </thead>
          <tbody>
            <tr><td><code>some View</code></td><td>A view destination</td><td>Simple screens</td></tr>
            <tr><td><code>any Coordinatable</code></td><td>A child coordinator</td><td>Nested navigation flows</td></tr>
            <tr><td><code>(any Coordinatable, some View)</code></td><td>Coordinator + tab label</td><td>Tab bar tabs</td></tr>
            <tr><td><code>(some View, some View)</code></td><td>View + tab label</td><td>View-only tabs</td></tr>
          </tbody>
        </table>
      </div>
      <p class="sub">
        Functions marked with <code>@ScaffoldingIgnored</code> or returning
        other types are skipped.
      </p>
    </section>

    <section id="mount" class="sec">
      <h2>Mounting the coordinator</h2>
      <p>
        A coordinator is a plain Swift class — it doesn't render
        anything until you ask it to. Hold the root coordinator in
        SwiftUI <code>@State</code> at the app entry point, then read
        its <code>view</code> property to mount its full navigation
        hierarchy as a SwiftUI view:
      </p>
      <CodeBlock code={CODE_MOUNT_APP} label="MyApp.swift" />
      <p>
        <code>view</code> is a <strong>computed property</strong>, not
        a function — there are no parentheses. SwiftUI re-renders
        whenever the coordinator's <code>@Observable</code> state
        changes, so the navigation stack, presented modals, and
        injected child coordinators all stay in sync without any
        further wiring.
      </p>
      <p class="sub">
        The same property works in <code>#Preview</code> — instantiate
        the coordinator and read <code>.view</code> directly:
      </p>
      <CodeBlock code={CODE_MOUNT_PREVIEW} label="HomeCoordinator preview" />
      <p class="sub">
        Only the <strong>root</strong> coordinator needs an explicit
        <code>@State</code> mount. Child coordinators returned from
        route functions (<code>any Coordinatable</code>) are
        instantiated by the parent and their views are rendered
        automatically when the parent routes to them.
      </p>
    </section>

    <section id="previews" class="sec">
      <h2>Previewing coordinator code</h2>
      <p>
        SwiftUI's <code>#Preview</code> macro and Scaffolding's
        <code>@Scaffoldable</code> macro both run at compile time, but
        they don't see each other the way the runtime does. A handful
        of preview-only papercuts are easy to chase as bugs if you're
        not expecting them.
      </p>

      <aside class="caveat" role="note">
        <span class="caveat-tag">Caveat 1</span>
        <div class="caveat-body">
          <p>
            <strong>The macro-generated routes can't seed a custom
            initial state in <code>#Preview</code>.</strong>
          </p>
          <p>
            The <code>Destinations</code> enum is emitted as a member
            of the coordinator type, and the stack is constructed from
            a literal root case
            (<code>FlowStack&lt;Home&gt;(root: .home)</code>). There's
            no synthesised <code>init(initialRoute:)</code> you can
            call — passing
            <code>HomeCoordinator(initialRoute: .detail)</code> doesn't
            compile. Preview the coordinator at its real root, or
            render the deeper screen directly (next caveat).
          </p>
        </div>
      </aside>

      <CodeBlock code={CODE_PREVIEW_BAD} label="Won't compile" />
      <CodeBlock code={CODE_PREVIEW_OK}  label="Two patterns that do work" />

      <aside class="caveat" role="note">
        <span class="caveat-tag">Caveat 2</span>
        <div class="caveat-body">
          <p>
            <strong>Views that use
            <code>@Environment(SomeCoordinator.self)</code> need an
            explicit injection.</strong>
          </p>
          <p>
            At runtime Scaffolding installs each coordinator into the
            environment of every view it manages. In
            <code>#Preview</code> you usually render a view by itself,
            outside the coordinator's view chain — so the environment
            is missing and the lookup falls back (or crashes,
            depending on Swift version). Pass the coordinator
            yourself: <code>SomeScreen().environment(HomeCoordinator())</code>.
          </p>
        </div>
      </aside>

      <aside class="caveat" role="note">
        <span class="caveat-tag">Caveat 3</span>
        <div class="caveat-body">
          <p>
            <strong>The <code>\.destination</code> environment value
            doesn't fully reflect runtime in previews.</strong>
          </p>
          <p>
            Scaffolding sets <code>\.destination</code> when it
            materialises a destination through a route or modal
            presentation. A view rendered alone in
            <code>#Preview</code> isn't materialised through that
            path, so <code>destination.routeType</code>,
            <code>destination.presentationType</code>, and
            <code>destination.meta</code> read as their default
            (<code>.root</code>) — not the value you'd see when the
            screen is actually pushed or presented.
          </p>
          <p>
            Don't gate critical preview rendering behind
            <code>destination.routeType</code> alone. The adaptive
            top-bar pattern <a href="#env">below</a> is preview-safe
            because it falls through to a benign placeholder when the
            value is <code>.root</code>.
          </p>
        </div>
      </aside>
    </section>

    <section id="flow" class="sec sim-side">
      <div class="prose">
        <h2>FlowCoordinatable — Navigation stacks</h2>
        <p>
          <code>FlowCoordinatable</code> manages a push/pop navigation stack
          with support for sheet and full-screen-cover modals. This is the
          coordinator you'll use most often.
        </p>
        <CodeBlock code={CODE_FLOW} label="HomeCoordinator.swift" />
        <p>
          Push with <code>route(to:)</code>, present a modal with
          <code>present(_:as:)</code>:
        </p>
        <CodeBlock code={CODE_FLOW_NAV} label="Navigation" />
        <p>
          <code>present(_:as:)</code> is available on every coordinator type, so
          a <code>TabCoordinatable</code> or <code>RootCoordinatable</code> can
          host a modal directly without delegating to a child flow.
        </p>
        <p>
          Go back with <code>pop()</code>, <code>popToRoot()</code>, or pop to
          a specific destination with <code>popToFirst(_:)</code> and
          <code>popToLast(_:)</code>.
        </p>
      </div>
      <aside class="sim-col" aria-label="Live FlowCoordinator simulation">
        <FlowSim
          coordName="HomeCoordinator"
          root={{ title: 'Planets', list: ['Mercury', 'Venus', 'Earth', 'Mars'] }}
          actions={[
            { code: 'route(to: .detail(item: "Earth"))',
              fn: (c) => c.push({ title: 'Earth', body: 'Detail screen.' }) },
            { code: 'present(.settings, as: .sheet)',
              fn: (c) => c.present({ title: 'Settings', list: ['Notifications', 'Privacy'] }, 'sheet') },
            { code: 'pop()',          fn: (c) => c.pop() },
            { code: 'popToRoot()',    fn: (c) => c.popToRoot() }
          ]}
          showState
        />
      </aside>
    </section>

    <section id="tab" class="sec">
      <h2>TabCoordinatable — Tab bars</h2>
      <p>
        <code>TabCoordinatable</code> manages a tab bar where each tab can
        contain its own coordinator with an independent navigation stack.
        Each function returns a tuple of the tab's content and its label.
      </p>
      <CodeBlock code={CODE_TAB} label="MainTabCoordinator.swift" />
      <p>Select tabs programmatically, add or remove them at runtime:</p>
      <CodeBlock code={CODE_TAB_API} label="Tab API" />
      <p class="sub">
        On iOS&nbsp;18+ you can also include a <code>TabRole</code> as a third
        tuple element to use the new tab bar API.
      </p>
    </section>

    <section id="root" class="sec">
      <h2>RootCoordinatable — State switches</h2>
      <p>
        <code>RootCoordinatable</code> holds a single root destination that
        can be swapped atomically. This is ideal for authentication flows,
        onboarding gates, or any state where the entire view hierarchy
        needs to change.
      </p>
      <CodeBlock code={CODE_ROOT} label="AppCoordinator.swift" />
      <p>One call flips the app state:</p>
      <CodeBlock code={CODE_ROOT_SET} label="Root swap" />
    </section>

    <section id="env" class="sec">
      <h2>Environment access</h2>
      <p>
        Scaffolding injects every coordinator in the hierarchy into the
        SwiftUI environment. Views access their nearest coordinator with
        <code>@Environment</code>:
      </p>
      <CodeBlock code={CODE_ENV} label="DetailView.swift" />
      <p>
        If multiple coordinators of the same type exist in the view tree,
        the one closest to the current view is used.
      </p>
      <p>
        You can also inspect how the current view was presented by reading
        the <code>destination</code> environment value:
      </p>
      <CodeBlock code={CODE_ENV_DEST} label="Destination metadata" />

      <h3>A reusable, route-aware top bar</h3>
      <p>
        Because every destination Scaffolding materialises sets
        <code>\.destination</code>, a single SwiftUI view can read the
        routing metadata and adapt itself to context. The same bar
        renders a back chevron when the screen is pushed, a
        <strong>Close</strong> when it's presented as a sheet or
        full-screen cover, and nothing leading when it's the root —
        without the bar knowing anything about the surrounding flow.
      </p>
      <CodeBlock code={CODE_ADAPTIVE_BAR} label="AdaptiveTopBar.swift · reusable" />
      <p class="sub">
        The same trick generalises to any chrome that should react to
        routing context — toolbar items, breadcrumb labels, swipe
        affordances. <code>destination.meta</code> lets you switch on
        the specific destination case (the macro generates a
        <code>Meta</code> enum alongside <code>Destinations</code>),
        which is useful when a screen renders different layouts
        depending on which route reached it.
      </p>
    </section>

    <section id="composing" class="sec">
      <h2>Composing coordinators</h2>
      <p>
        Coordinators nest naturally. A <code>FlowCoordinatable</code> can
        route to a child coordinator (returned as <code>any Coordinatable</code>),
        which can itself be any coordinator type. A typical app hierarchy
        looks like this:
      </p>
      <pre class="ascii"><code>{`AppCoordinator (Root)
├── LoginCoordinator (Flow)
└── MainTabCoordinator (Tab)
    ├── HomeCoordinator (Flow)
    │   └── DetailCoordinator (Flow)
    └── ProfileCoordinator (Flow)`}</code></pre>
      <p>
        A child coordinator destination can take parameters — useful for
        delivering a result back via a callback, the way the demo's
        <code>LoginCoordinator</code> works:
      </p>
      <CodeBlock code={CODE_COMPOSE} label="Composition with onComplete" />
    </section>

    <section id="deep-link" class="sec">
      <h2>Deep linking</h2>
      <p>
        Deep linking — landing the user on a specific screen straight
        from a cold launch — is where the coordinator model
        especially shines. Every navigation method that resolves a
        child coordinator
        (<code>route</code>, <code>setRoot</code>,
        <code>appendTab</code>, <code>insertTab</code>,
        <code>popToFirst</code>, <code>popToLast</code>,
        <code>selectFirstTab</code>, <code>selectLastTab</code>,
        <code>select(index:)</code>, <code>select(id:)</code>) ships
        an overload constrained to <code>{'<T: Coordinatable>'}</code>
        with a trailing closure. (<code>present(_:as:)</code> itself
        has no typed overload — present a coordinator, then chain typed
        calls on the routes inside it.) The closure fires after the
        route lands, receiving a typed reference to the freshly
        resolved child:
      </p>
      <CodeBlock code={CODE_DEEPLINK} label="AppCoordinator · openProfile(userId:)" />
      <p>
        Each step of the chain hands the next step a typed
        coordinator, so you can walk the tree
        — root → tab → flow → pushed screen — without storing handles
        anywhere or doing any runtime casting at the call site. The
        same pattern composes for any depth, and the typed overload
        is opt-in: when you don't need the child handle, the regular
        <code>route(to:)</code> / <code>setRoot(_:)</code> still works
        without a trailing closure.
      </p>
      <p>Hook the entry point to a URL, push notification, or quick action:</p>
      <CodeBlock code={CODE_DEEPLINK_URL} label="MyApp · onOpenURL" />
      <p class="sub">
        The typed closure only fires if the resolved child can be
        cast to <code>T</code>. Pick a concrete coordinator type that
        matches the destination's return signature — for an
        <code>any Coordinatable</code> route returning a
        <code>ProfileCoordinator</code>, the closure parameter must
        be <code>ProfileCoordinator</code>.
      </p>
    </section>

    <section id="dismiss" class="sec sim-side">
      <div class="prose">
        <h2>Dismissing a flow</h2>
        <p>
          <code>pop()</code> and <code>dismissCoordinator()</code> are
          not the same call. <code>pop()</code> removes a single pushed
          screen from the current flow's stack.
          <code>dismissCoordinator()</code> removes the
          <strong>entire coordinator</strong> from its parent —
          collapsing whatever sub-tree it owns (its root, every screen
          it has pushed, every modal it has presented) in one move.
        </p>
        <p>
          The difference shows up clearly in a nested flow. Below, an
          <code>AppCoordinator</code> presents a
          <code>LoginCoordinator</code> as a sheet. The login flow is
          itself two screens (<code>email</code> → <code>password</code>).
          When the user signs in on the password step, calling
          <code>dismissCoordinator()</code> closes the whole sheet at
          once — not just the password screen.
        </p>

        <CodeBlock code={CODE_DISMISS_PARENT} label="AppCoordinator.swift · presents the login flow" />
        <CodeBlock code={CODE_DISMISS_CHILD}  label="LoginCoordinator.swift · the nested flow" />
        <CodeBlock code={CODE_DISMISS_VIEWS}  label="Step views · pop() vs dismissCoordinator()" />

        <p class="sub">
          Drive the simulator on the right to see it: present the
          login sheet, push to the password step inside it, then
          compare <code>pop()</code> (one step back) to
          <code>dismissCoordinator()</code> (whole sheet closes,
          regardless of how deep you've pushed).
        </p>

        <aside class="caveat" role="note">
          <span class="caveat-tag">Watch out</span>
          <div class="caveat-body">
            <p>
              <strong>Calling <code>dismissCoordinator()</code> on the
              root coordinator is a no-op</strong> — there's no parent
              to remove it from. Save it for child coordinators that
              were pushed or presented.
            </p>
            <p>
              For a single-screen back button inside a flow, prefer
              <code>pop()</code> or SwiftUI's
              <code>@Environment(\.dismiss)</code>. Reach for
              <code>dismissCoordinator()</code> when the intent is
              "I'm done with this whole sub-flow," typically right
              after handing a result back through an
              <code>onComplete</code> callback.
            </p>
          </div>
        </aside>
      </div>

      <aside class="sim-col" aria-label="Nested coordinator dismiss simulation">
        <FlowSim
          coordName="coordinator"
          root={{ title: 'Home' }}
          actions={[
            { code: 'present(.login(onComplete:), as: .sheet)',
              coord: 'AppCoordinator',
              hint: 'opens the login sheet',
              fn: (c) => c.present({ title: 'Email', body: 'Enter email' }, 'sheet'),
              disabled: (c) => c.modal !== null },
            { code: 'route(to: .password(email:))',
              coord: 'LoginCoordinator',
              hint: 'pushes the next step inside the sheet',
              fn: (c) => c.pushInModal({ title: 'Password', body: 'Enter password' }),
              disabled: (c) => c.modal === null || c.top?.pushType === 'modal-push' },
            { code: 'pop()',
              coord: 'LoginCoordinator',
              hint: 'one screen up — stays inside the sheet',
              fn: (c) => c.pop(),
              disabled: (c) => c.modal === null },
            { code: 'dismissCoordinator()',
              coord: 'LoginCoordinator',
              accent: true,
              hint: 'whole sheet closes, even from password',
              fn: (c) => c.dismiss(),
              disabled: (c) => c.modal === null }
          ]}
          showState
        />
      </aside>
    </section>

    <section id="customize" class="sec">
      <h2>Customizing views</h2>
      <p>
        Override <code>customize(_:)</code> on a coordinator to apply shared
        modifiers to every view it manages. Mark it with
        <code>@ScaffoldingIgnored</code> so the macro doesn't treat it as a
        route:
      </p>
      <CodeBlock code={CODE_CUSTOMIZE} label="Coordinator+customize" />
    </section>

    <section id="vs-native" class="sec">
      <h2>Compared to <code>NavigationStack(path:)</code></h2>
      <p>
        The same three-screen app — list, detail, settings sheet —
        written once with SwiftUI's <code>NavigationStack(path:)</code>
        and once with Scaffolding. The shape of the difference is the
        shape of the library's value.
      </p>

      <div class="compare-block">
        <header class="compare-head" data-flavor="native">
          <span class="compare-tag">SwiftUI</span>
          <span class="compare-title"><code>NavigationStack(path:)</code></span>
          <div class="compare-toggle" role="tablist" aria-label="Native variant">
            <button
              type="button"
              role="tab"
              aria-selected={nativeMode === 'view'}
              class:active={nativeMode === 'view'}
              onclick={() => (nativeMode = 'view')}
            >
              View-hosted
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={nativeMode === 'enum'}
              class:active={nativeMode === 'enum'}
              onclick={() => (nativeMode = 'enum')}
            >
              Typed enum
            </button>
          </div>
        </header>
        <CodeBlock
          code={nativeMode === 'view' ? CODE_NATIVE_VIEW : CODE_NATIVE_ENUM}
          label={nativeMode === 'view' ? 'ContentView · view-hosted' : 'ContentView · typed-enum path'}
        />
      </div>

      <p class="compare-vs" aria-hidden="true">↓ same thing, with Scaffolding</p>

      <div class="compare-block">
        <header class="compare-head" data-flavor="scaffolding">
          <span class="compare-tag">Scaffolding</span>
          <span class="compare-title"><code>FlowCoordinatable</code></span>
        </header>
        <CodeBlock code={CODE_SCAFFOLDING} label="HomeCoordinator.swift" />
      </div>

      <h3>What changes</h3>
      <ul class="diffs">
        <li>
          <strong>Path state moves out of the view.</strong>
          Native carries <code>@State path</code> and
          <code>@State showSettings</code> in <code>ContentView</code>;
          Scaffolding's coordinator owns the
          <code>FlowStack</code>, so views never store navigation state
          themselves.
        </li>
        <li>
          <strong>Pushes are explicit calls, not <code>NavigationLink</code>s.</strong>
          The native list couples the row to navigation through
          <code>NavigationLink(value:)</code>. With Scaffolding the row
          is a plain <code>Button</code> that calls
          <code>coordinator.route(to: .detail(item:))</code> — the view
          stays decoupled from how navigation happens.
        </li>
        <li>
          <strong>Modals don't need a binding.</strong>
          Native modals require a <code>@State Bool</code> and a
          <code>.sheet(isPresented:)</code> modifier on the view tree.
          Scaffolding presents from a method call —
          <code>coordinator.present(.settings, as: .sheet)</code> — and
          dismisses with <code>pop()</code>.
        </li>
        <li>
          <strong>Pop doesn't need a <code>@Binding</code>.</strong>
          The native <code>DetailView</code> takes
          <code>@Binding var path</code> so it can call
          <code>removeLast()</code>. Scaffolding's <code>DetailView</code>
          reads the coordinator from <code>@Environment</code> and just
          calls <code>pop()</code>.
        </li>
        <li>
          <strong>Type-safe destinations across modules.</strong>
          A heterogeneous <code>NavigationStack</code> path needs a
          custom enum and a <code>navigationDestination</code> per
          case, in <em>the view tree</em>. Scaffolding's macro
          generates the destination enum from your coordinator's
          functions, so a coordinator from another module slots in
          without touching any views.
        </li>
        <li>
          <strong>Coordinators compose.</strong>
          The native version is glued to
          <code>NavigationStack(path:)</code> — embedding it as a tab,
          presenting it modally, or driving it from another flow means
          re-plumbing the path bindings. A Scaffolding coordinator is a
          first-class value that any other coordinator can
          <code>route(to:)</code>, <code>present(_:as:)</code>, or hold
          as a tab.
        </li>
      </ul>
    </section>

    <section id="philosophy" class="sec">
      <h2>When to use what</h2>
      <p>
        Scaffolding exists to give <code>NavigationStack</code> the
        <strong>modularity</strong> it lacks — coordinators, child
        coordinators, and <code>route(to:)</code> that compose across
        module boundaries. That's the core value the library delivers.
      </p>
      <p>
        Modal presentations sit one level above that, and they have two
        flavors. The right tool depends on what's <em>inside</em> the
        modal:
      </p>

      <ul class="rules">
        <li>
          <span class="rule-tag">View-only</span>
          <span class="rule-body">
            Reach for SwiftUI's native <code>.sheet(item:)</code> /
            <code>.fullScreenCover(item:)</code> when the modal is a
            <em>single screen</em> — a confirmation, an info dialog, a
            simple form. Keep it native; the view-side modifier is
            lighter and avoids any coordinator overhead.
          </span>
        </li>
        <li>
          <span class="rule-tag">Sub-flow</span>
          <span class="rule-body">
            Use <code>present(_:as:)</code> when the modal is itself a
            <em>flow</em> — a Login coordinator with email → password →
            done, a Settings hierarchy, anything with its own
            navigation. The presented coordinator gets a parent
            reference, can call <code>dismissCoordinator()</code> on
            itself, and delivers results back through
            <code>onComplete</code> callbacks the parent installs at
            construction time.
          </span>
        </li>
      </ul>

      <p class="sub">
        Rule of thumb: <strong>if the modal contains navigation, make it
        a coordinator and <code>present</code>; if it's a single-page
        view, use SwiftUI's native modifier.</strong>
      </p>

      <aside class="caveat" role="note">
        <span class="caveat-tag">Caveat</span>
        <div class="caveat-body">
          <p>
            <strong>Don't nest <code>NavigationStack</code> inside a
            flow.</strong>
          </p>
          <p>
            <code>FlowCoordinatable</code> <em>is</em> the
            <code>NavigationStack</code>, so putting another one inside
            any of its destination views breaks navigation — SwiftUI
            doesn't compose <code>NavigationStack</code>s with each
            other. The nested stack swallows the pushes that should
            belong to the parent flow, and the coordinator's
            <code>route(to:)</code> stops doing what you expect.
          </p>
          <p>
            If a screen genuinely needs its own navigation hierarchy,
            give it a child <code>FlowCoordinatable</code> instead —
            <code>route(to:)</code> a coordinator-typed destination, or
            <code>present(_:as:)</code> a sub-flow modally. Each
            coordinator boundary creates a fresh
            <code>NavigationStack</code>, which is the only configuration
            SwiftUI handles correctly.
          </p>
        </div>
      </aside>
    </section>

    <footer class="next">
      <h2>Topics</h2>
      <p>
        More places to dig in — the symbol-by-symbol DocC archive, an
        in-site reference, the hands-on tutorial, and an opinionated
        guide for LLM coding agents working in this codebase:
      </p>
      <div class="topic-cards">
        <a
          class="topic"
          href={DOCC_URL}
          target="_blank"
          rel="noopener noreferrer"
        >
          <span class="topic-eyebrow">DocC · Generated</span>
          <span class="topic-title">DocC archive ↗</span>
          <span class="topic-desc">
            The full DocC website built from the in-source documentation —
            every public symbol with its declaration, parameters, and
            cross-links, served on GitHub Pages.
          </span>
        </a>
        <a class="topic" href={`${base}/docs/api`}>
          <span class="topic-eyebrow">Reference</span>
          <span class="topic-title">API Reference →</span>
          <span class="topic-desc">
            Every public protocol, type, and macro — grouped by purpose.
            Coordinator protocols, state containers, destinations, macros.
          </span>
        </a>
        <a class="topic" href={`${base}/docs/tutorial`}>
          <span class="topic-eyebrow">Tutorial · 25 min</span>
          <span class="topic-title">Your first project →</span>
          <span class="topic-desc">
            Build a three-screen iOS app — list, detail, settings sheet —
            from a blank Xcode project to a working coordinator.
          </span>
        </a>
        <a class="topic" href={`${base}/docs/agents`}>
          <span class="topic-eyebrow">Agent guide</span>
          <span class="topic-title">For LLM coding agents →</span>
          <span class="topic-desc">
            Best-practice reference for LLM coding agents.
            The no-nested-<code>NavigationStack</code> rule, the
            push/present/setRoot decision tree, separation-of-concerns
            patterns, and the mistakes to never generate.
          </span>
        </a>
      </div>

      <p class="footnote">
        The <a href={`${base}/`}>landing page</a> also includes an
        interactive playground where you can drive a simulated coordinator
        hierarchy with the actual Scaffolding API.
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
    /* Wider than the original 760 so prose-adjacent code blocks
       (especially the NavigationStack-vs-Scaffolding comparison) have
       enough horizontal room to read at the actual font size, and a
       slimmer max-padding so the page doesn't feel inset on laptop
       screens. */
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

  /* ── Sections ──────────────────────────────────────────────────────── */

  .sec {
    margin: 0 0 clamp(4rem, 8vw, 6rem);
    padding-top: clamp(2.5rem, 5vw, 4rem);
    border-top: 1px solid var(--line-soft);
    /* Match the home page's scroll-padding offset for the sticky header. */
    scroll-margin-top: 5rem;
  }
  .sec:first-of-type {
    margin-top: 0;
    padding-top: 0;
    border-top: 0;
  }

  /* Sim-side sections break out of the article column on viewports that
     have room — but the threshold leaves space for the ScrollProgress
     rail (~210 px when labels show at ≥ 1340 viewport) so the sim and
     the rail don't overlap. The breakout caps at -180 so the sim stays
     well clear of the right-side rail even on huge displays. */
  .sec.sim-side {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    column-gap: clamp(1.5rem, 3vw, 2.5rem);
    align-items: start;
    margin-right: clamp(-180px, calc((1380px - 100vw) / 2), 0px);
  }
  .sim-side .prose { min-width: 0; }
  .sim-side .sim-col {
    position: sticky;
    top: 6rem;
    align-self: start;
  }
  @media (max-width: 880px) {
    .sec.sim-side {
      grid-template-columns: 1fr;
      margin-right: 0;
    }
    .sim-side .sim-col {
      position: static;
      justify-self: center;
      margin-top: 0.75rem;
    }
  }

  .sec h2 {
    margin: 0 0 1rem;
    font-family: var(--font-mono);
    font-size: clamp(1.2rem, 2.4vw, 1.55rem);
    font-weight: 500;
    letter-spacing: -0.015em;
    color: var(--fg);
  }

  .sec h3 {
    margin: 1.5rem 0 0.5rem;
    font-family: var(--font-mono);
    font-size: clamp(1rem, 1.8vw, 1.15rem);
    font-weight: 500;
    color: var(--fg);
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

  /* Block code wrapper (figure produced by CodeBlock) sits outside the
     prose's max-width — full-bleed within the article. */
  .sec :global(.block) {
    margin: 1rem 0 1.25rem;
  }

  /* ── "Compared to NavigationStack(path:)" stacked code blocks ──── */

  /* Each block runs the full article width so the code never gets
     squeezed into a half-column. The pairing is communicated by the
     "↓ same thing, with Scaffolding" hinge between them and the
     colored tag at the top of each block. */

  .compare-block {
    margin: 0.75rem 0 0.5rem;
  }

  .compare-head {
    display: inline-flex;
    align-items: center;
    gap: 0.65rem;
    margin: 0 0 0.5rem;
    padding: 0.3rem 0.7rem 0.3rem 0.55rem;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: var(--surface);
    flex-wrap: wrap;
    max-width: 100%;
  }

  .compare-tag {
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    line-height: 1;
    padding: 0.2rem 0.55rem;
    border-radius: 999px;
    color: var(--bg);
  }
  .compare-head[data-flavor='native']      .compare-tag { background: var(--syn-att); }
  .compare-head[data-flavor='scaffolding'] .compare-tag { background: var(--syn-ty); }

  .compare-title {
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg);
  }
  .compare-title code {
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg);
    background: transparent;
    border: 0;
    padding: 0;
  }

  .compare-vs {
    margin: 0.5rem 0 1.25rem;
    text-align: center;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--dim);
  }

  /* Native-variant toggle (View-hosted / Typed enum). Sits in the
     comparison header on the right of the title pill. */
  .compare-toggle {
    display: inline-flex;
    margin-left: auto;
    border: 1px solid var(--line);
    border-radius: 999px;
    overflow: hidden;
    background: var(--bg);
  }

  .compare-toggle button {
    font: inherit;
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.06em;
    padding: 0.3rem 0.7rem;
    background: transparent;
    border: 0;
    color: var(--muted);
    cursor: pointer;
    transition: color 140ms ease, background-color 140ms ease;
  }

  .compare-toggle button:hover {
    color: var(--fg);
  }

  .compare-toggle button.active {
    background: color-mix(in srgb, var(--fg) 12%, var(--bg));
    color: var(--fg);
  }

  .compare-toggle button:focus-visible {
    outline: none;
    box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--fg) 50%, transparent);
  }

  /* Differences bullet list. */
  .sec h3 {
    margin: 1.75rem 0 0.75rem;
    font-family: var(--font-mono);
    font-size: 12px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--dim);
    font-weight: 500;
  }

  .diffs {
    margin: 0 0 1rem;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }
  .diffs li {
    position: relative;
    padding: 0.7rem 0.95rem 0.7rem 2.2rem;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
    font-size: 13.5px;
    line-height: 1.6;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }
  .diffs li::before {
    content: '→';
    position: absolute;
    left: 0.95rem;
    top: 0.7rem;
    color: var(--muted);
    font-family: var(--font-mono);
    font-size: 13px;
  }
  .diffs li strong {
    color: var(--fg);
    font-weight: 500;
  }
  .diffs li em { color: var(--fg); font-style: italic; }
  .diffs li code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: var(--surface-2);
    border: 1px solid var(--line-soft);
    padding: 0.05em 0.35em;
    border-radius: 3px;
  }

  /* ── "When to use what" rule list ─────────────────────────────────── */

  .rules {
    margin: 0.5rem 0 1.25rem;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
  }

  .rules li {
    display: grid;
    grid-template-columns: 110px 1fr;
    gap: 1rem;
    align-items: start;
    padding: 0.85rem 1rem;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
  }

  @media (max-width: 540px) {
    .rules li {
      grid-template-columns: 1fr;
      gap: 0.45rem;
    }
  }

  .rule-tag {
    font-family: var(--font-mono);
    font-size: 10.5px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--fg);
    padding: 0.18rem 0.5rem;
    border-radius: 999px;
    border: 1px solid color-mix(in srgb, var(--fg) 25%, transparent);
    background: color-mix(in srgb, var(--fg) 4%, transparent);
    justify-self: start;
    align-self: center;
    line-height: 1;
  }

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

  /* Caveat callout — uses the syntax-keyword (warning) accent so it
     reads as something to actively avoid, distinct from the neutral
     rule cards above. */
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
    .caveat {
      grid-template-columns: 1fr;
      gap: 0.4rem;
    }
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
  .caveat-body p em { color: var(--fg); font-style: italic; }
  .caveat-body code {
    font-family: var(--font-mono);
    font-size: 0.92em;
    color: var(--fg);
    background: color-mix(in srgb, var(--syn-kw) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--syn-kw) 25%, transparent);
    padding: 0.05em 0.35em;
    border-radius: 3px;
  }

  /* ── How-it-works numbered steps ───────────────────────────────────── */

  .steps {
    margin: 0 0 1.25rem;
    padding: 0;
    list-style: none;
    counter-reset: step;
    display: flex;
    flex-direction: column;
    gap: 0.65rem;
  }

  .steps li {
    counter-increment: step;
    position: relative;
    padding-left: 2.5rem;
    font-size: 14px;
    line-height: 1.65;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }

  .steps li::before {
    content: counter(step, decimal-leading-zero);
    position: absolute;
    left: 0;
    top: 1px;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.08em;
    color: var(--dim);
  }

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

  tbody tr:last-child td {
    border-bottom: 0;
  }

  /* ── ASCII tree (composition diagram) ──────────────────────────────── */

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
    margin: 0 0 1.25rem;
    font-size: 14px;
    line-height: 1.7;
    color: color-mix(in srgb, var(--fg) 78%, transparent);
  }

  /* Topics cards */
  .topic-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 0.85rem;
    margin: 0.5rem 0 1.5rem;
  }

  .topic {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1.1rem 1.2rem;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
    text-decoration: none;
    transition: border-color 140ms ease, background-color 140ms ease, transform 100ms ease;
  }
  .topic:hover {
    border-color: color-mix(in srgb, var(--fg) 35%, transparent);
    background: color-mix(in srgb, var(--fg) 4%, var(--bg));
  }
  .topic:active {
    transform: translateY(1px);
  }
  .topic-eyebrow {
    font-size: 10.5px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--dim);
  }
  .topic-title {
    font-family: var(--font-mono);
    font-size: 15px;
    font-weight: 500;
    color: var(--fg);
    letter-spacing: -0.01em;
  }
  .topic-desc {
    font-size: 12.5px;
    line-height: 1.55;
    color: color-mix(in srgb, var(--fg) 65%, transparent);
  }

  .footnote {
    margin: 1rem 0 0;
    font-size: 13px;
    color: var(--muted);
  }
  .footnote a {
    color: var(--fg);
    text-decoration: none;
    border-bottom: 1px solid color-mix(in srgb, var(--fg) 30%, transparent);
  }
  .footnote a:hover {
    border-bottom-color: var(--fg);
  }
</style>
