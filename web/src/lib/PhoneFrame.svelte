<script>
  /**
   * Reusable iPhone-style chrome. Children render inside the screen area,
   * an optional `tabBar` snippet renders in the bottom slot, and the
   * surrounding bezel + Dynamic Island stay consistent across simulators.
   */
  let {
    children,
    tabBar = null,
    statusText = '9:41',
    size = 'compact' // 'compact' (docs) | 'large' (landing playground)
  } = $props();
</script>

<div class="phone" data-size={size}>
  <div class="phone-frame">
    <span class="notch" aria-hidden="true"></span>
    <div class="screen-area">
      <div class="status-bar">
        <span>{statusText}</span>
        <span class="bars" aria-hidden="true">●●●</span>
      </div>
      <div class="content">
        {@render children?.()}
      </div>
      {#if tabBar}
        {@render tabBar()}
      {/if}
      <div class="home-indicator" aria-hidden="true"></div>
    </div>
  </div>
</div>

<style>
  .phone {
    aspect-ratio: 9 / 18.5;
    flex-shrink: 0;
  }
  .phone[data-size='compact'] {
    width: clamp(200px, 32vw, 260px);
  }
  .phone[data-size='large'] {
    width: min(clamp(240px, 26vw, 360px), calc(75svh * 9 / 18.5));
  }

  .phone-frame {
    position: relative;
    width: 100%;
    height: 100%;
    padding: 7px;
    border-radius: 32px;
    border: 1px solid color-mix(in srgb, var(--fg) 28%, transparent);
    background: color-mix(in srgb, var(--fg) 12%, var(--bg));
    box-shadow:
      0 0 0 1px color-mix(in srgb, var(--fg) 6%, transparent) inset,
      0 18px 38px -16px color-mix(in srgb, var(--fg) 35%, transparent);
  }

  .notch {
    position: absolute;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    width: 78px;
    height: 22px;
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
    border-radius: 26px;
    background: var(--bg);
    color: var(--fg);
    isolation: isolate;
    display: flex;
    flex-direction: column;
  }

  .status-bar {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 18px 6px;
    font-size: 10px;
    letter-spacing: 0.04em;
    color: color-mix(in srgb, var(--fg) 75%, transparent);
  }

  .bars {
    font-size: 7px;
    letter-spacing: 0.15em;
    opacity: 0.7;
  }

  .content {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .home-indicator {
    position: absolute;
    bottom: 5px;
    left: 50%;
    transform: translateX(-50%);
    width: 90px;
    height: 3px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--fg) 30%, transparent);
    z-index: 60;
    pointer-events: none;
  }
</style>
