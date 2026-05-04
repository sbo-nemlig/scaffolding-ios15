<script>
  import '../app.css';
  import DotGrid from '$lib/DotGrid.svelte';
  import SiteHeader from '$lib/SiteHeader.svelte';
  import SiteFooter from '$lib/SiteFooter.svelte';

  let { children } = $props();
</script>

<DotGrid />
<SiteHeader />
{@render children()}
<SiteFooter />
