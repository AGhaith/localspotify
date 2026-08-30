<script setup lang="ts">
import MobileNavigation from '@/components/navigation/MobileNavigation.vue';
import SidebarNavigation from '@/components/navigation/SidebarNavigation.vue';
import TopBarFilterPills from '@/components/navigation/TopBarFilterPills.vue';
import UserMenu from '@/components/navigation/UserMenu.vue';
import MusicPlayerAndQueue from '@/components/player/MusicPlayerAndQueue.vue';
import KeyboardShortcuts from '@/components/ui/KeyboardShortcuts.vue';

const {
  mobileNavigation,
  sidebarNavigation,
} = useNavigation();
</script>

<template>
  <div :class="$style.mainLayout">
    <header :class="['centerItems', $style.header]">
      <div :class="['inner', $style.headerInner]">
        <!-- User Avatar & Spotify-Style Filter Pills -->
        <div :class="$style.leftNavSection">
          <UserMenu />
          <TopBarFilterPills />
        </div>
      </div>
    </header>

    <aside aria-label="Sidebar">
      <SidebarNavigation class="desktopOnly" :navigation="sidebarNavigation" />

      <MobileNavigation class="mobileOnly" :navigation="mobileNavigation" />
    </aside>

    <main :class="['main', $style.mainContent]" tabindex="-1">
      <div :class="['column', $style.mainContentInner]">
        <div class="column inner mBAllL">
          <slot />
        </div>
      </div>
    </main>

    <div>
      <ClientOnly>
        <MusicPlayerAndQueue />
      </ClientOnly>
      <KeyboardShortcuts />
    </div>
  </div>
</template>

<style module>
.mainLayout {
  display: flex;
}

.header {
  position: fixed;
  inset: 0 0 auto;
  z-index: 15;
  min-height: var(--header-height);
  background-color: #000000;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.9);

  @media (--tablet-up) {
    margin-left: var(--sidebar-width);
  }
}

.headerInner {
  display: flex;
  align-items: center;
  width: 100%;
}

.leftNavSection {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
  flex: 1;
}

.mainContent {
  position: relative;
  display: flex;
  flex: 1;
  min-height: 100svh;
  overflow: hidden;

  @media (--tablet-up) {
    margin-left: var(--sidebar-width);
  }
}

.mainContentInner {
  --main-width: 100vw;
  --main-padding-top: calc(var(--header-height) + var(--space-40));
  --main-padding-bottom: calc(
    var(--sidebar-bottom) + var(--space-40) + var(--header-height)
  );

  width: var(--main-width);
  padding: var(--main-padding-top) 0 var(--main-padding-bottom);

  @media (--tablet-up) {
    --main-width: calc(100vw - var(--sidebar-width));
    --main-padding-bottom: calc(var(--sidebar-bottom) + var(--space-40));
  }
}
</style>
