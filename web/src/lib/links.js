// Shared external link constants. Internal routes use `${base}/...` at the
// call site so SvelteKit's configured base path (e.g. when deployed under
// `/scaffolding/` on GitHub Pages) is respected.
export const GITHUB_URL = 'https://github.com/dotaeva/scaffolding';

// Hosted DocC archive — the static-hosting build emitted by the
// `Deploy DocC to GitHub Pages` workflow lives under `/scaffolding/docc/`
// so it sits beneath the Svelte site at `/scaffolding/`. Update this if
// you move DocC to a different sub-path.
export const DOCC_URL = 'https://dotaeva.github.io/scaffolding/docc/documentation/scaffolding/';
