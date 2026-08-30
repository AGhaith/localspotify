<script setup lang="ts">
import DropdownDivider from '@/components/dropdown/DropdownDivider.vue';
import DropdownItem from '@/components/dropdown/DropdownItem.vue';
import DropdownMenu from '@/components/dropdown/DropdownMenu.vue';
import DropdownTitle from '@/components/dropdown/DropdownTitle.vue';

const { user } = useUser();
const { logoutAndRedirect } = useAuth();
const { startScan } = useMediaLibrary();

async function onLogout() {
  setLocalStorage(LOCAL_STORAGE_KEYS.logout, Date.now().toString());

  await logoutAndRedirect();
}

const username = computed(() => user.value?.username);
</script>

<template>
  <DropdownMenu title="View user profile and menu">
    <template #icon>
      <div :class="$style.avatarButton">
        <!-- Minimalist Black & White Silhouette Avatar -->
        <svg
          viewBox="0 0 100 100"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          :class="$style.genericAvatarSvg"
          aria-hidden="true"
        >
          <rect width="100" height="100" fill="#000000" />
          <circle cx="50" cy="44" r="18.5" fill="#ffffff" />
          <path d="M16 100C16 77 31 66 50 66C69 66 84 77 84 100H16Z" fill="#ffffff" />
        </svg>
      </div>
    </template>

    <DropdownTitle>
      {{ username || 'User' }}
    </DropdownTitle>

    <DropdownItem
      is="nuxt-link"
      :to="{
        name: ROUTE_NAMES.files,
      }"
    >
      Files
    </DropdownItem>
    <DropdownItem ref="scanDropdownItem" @click="startScan">
      Scan files
    </DropdownItem>
    <DropdownItem
      is="nuxt-link"
      :to="{
        name: ROUTE_NAMES.downloads,
      }"
    >
      Offline Downloads
    </DropdownItem>
    <DropdownItem
      is="nuxt-link"
      :to="{
        name: ROUTE_NAMES.settings,
      }"
    >
      Settings
    </DropdownItem>
    <DropdownDivider />
    <DropdownItem
      ref="logoutDropdownItem"
      :icon="ICONS.logOut"
      @click="onLogout"
    >
      Log out
    </DropdownItem>
  </DropdownMenu>
</template>

<style module>
.avatarButton {
  position: relative;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  background-color: #000000;
  border: 2px solid rgba(255, 255, 255, 0.16);
  box-shadow: 2px 2px 0px #000000;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform, border-color, box-shadow;
  transition: transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    border-color 0.1s ease,
    box-shadow 0.1s ease;
  user-select: none;

  &:hover {
    border-color: #22c55e;
    transform: scale(1.06);
    box-shadow: 0 0 12px rgba(34, 197, 94, 0.4);
  }

  &:active {
    transform: scale(0.92) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.genericAvatarSvg {
  width: 100%;
  height: 100%;
  display: block;
  border-radius: 50%;
}
</style>
