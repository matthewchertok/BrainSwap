<script lang="ts">
  import '../app.css';
  import { brand } from '$lib/config';
</script>

<svelte:head><title>{brand.name}</title><meta name="description" content={brand.tagline} /></svelte:head><slot />
