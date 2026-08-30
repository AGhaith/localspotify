<script setup lang="ts">
const props = defineProps<{
  type: SnackType;
}>();

const roleType = computed(() => (props.type === 'error' ? 'alert' : 'status'));
</script>

<template>
  <div
    :class="[
      'strong',
      'smallFont',
      'centerItems',
      'spaceBetween',
      type,
      $style.messageBar,
    ]"
    :role="roleType"
  >
    <slot />
  </div>
</template>

<style module>
.messageBar {
  gap: var(--default-space);
  width: var(--width-height-100);
  padding: var(--default-space) var(--default-space) var(--default-space)
    calc(var(--default-space) * 2);
  color: #000000;
  font-family: var(--font-family);
  font-weight: 700;
  word-break: normal;
  overflow-wrap: anywhere;
  border-radius: 10px;
  border: 2px solid #000000;
  box-shadow: 4px 4px 0px #000000;
}
</style>
