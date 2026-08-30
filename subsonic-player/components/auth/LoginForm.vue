<script setup lang="ts">
import { PhEye, PhEyeSlash, PhGlobe, PhLockKey, PhUser, PhWarningCircle } from '@phosphor-icons/vue';

defineProps<{
  error?: null | string;
  loading?: boolean;
}>();

const emit = defineEmits<{
  submit: [value: AuthData];
}>();

const config = useRuntimeConfig();
const { SERVER_URL } = config.public;

const showPassword = ref(false);
const showAdvancedServer = ref(!SERVER_URL);

const formInputs = {
  password: {
    validationRules: {
      required: true,
    },
  },
  server: {
    validationRules: SERVER_URL
      ? {}
      : {
          isUrl: true,
          required: true,
        },
    value: SERVER_URL || '',
  },
  username: {
    validationRules: {
      required: true,
    },
  },
};

const form = createForm(formInputs);

function toggleShowPassword() {
  showPassword.value = !showPassword.value;
}

function toggleServerSettings() {
  showAdvancedServer.value = !showAdvancedServer.value;
}

function onFormSubmit() {
  validateFormFields(form);

  if (!form.isValid.value) {
    return;
  }

  const { password, server, username } = form.fields;

  emit('submit', {
    password: password.value.value as string,
    server: (server.value.value as string) || SERVER_URL || '',
    username: username.value.value as string,
  });
}
</script>

<template>
  <form novalidate :class="$style.form" @submit.stop.prevent="onFormSubmit">
    <div :class="$style.fieldList">
      <!-- Server Address (Toggleable if predefined) -->
      <div v-if="!SERVER_URL || showAdvancedServer" :class="$style.fieldGroup">
        <label :class="$style.label" :for="form.fields.server.id">
          <span>Server Address</span>
          <span :class="$style.required">*</span>
        </label>
        <div
          :class="[
            $style.inputWrapper,
            {
              [$style.hasError]: form.fields.server.error.value,
            },
          ]"
        >
          <PhGlobe weight="duotone" :class="$style.fieldIcon" />
          <input
            :id="form.fields.server.id"
            ref="serverUrl"
            v-model="form.fields.server.value.value"
            :class="$style.input"
            autocomplete="url"
            placeholder="http://192.168.1.100:4533"
            required
            type="url"
          />
        </div>
        <p v-if="form.fields.server.error.value" :class="$style.fieldError">
          {{ form.fields.server.error.value }}
        </p>
      </div>

      <!-- Configured Server Indicator Pill -->
      <div v-else :class="$style.configuredServerRow">
        <div :class="$style.serverBadge">
          <PhGlobe weight="fill" :class="$style.serverIcon" />
          <span :class="$style.serverUrlText">{{ SERVER_URL }}</span>
        </div>
        <button
          type="button"
          :class="$style.changeServerBtn"
          @click="toggleServerSettings"
        >
          Change
        </button>
      </div>

      <!-- Username Field -->
      <div :class="$style.fieldGroup">
        <label :class="$style.label" :for="form.fields.username.id">
          <span>Username</span>
          <span :class="$style.required">*</span>
        </label>
        <div
          :class="[
            $style.inputWrapper,
            {
              [$style.hasError]: form.fields.username.error.value,
            },
          ]"
        >
          <PhUser weight="duotone" :class="$style.fieldIcon" />
          <input
            :id="form.fields.username.id"
            ref="username"
            v-model="form.fields.username.value.value"
            :class="$style.input"
            autocomplete="username"
            placeholder="Username"
            required
            type="text"
          />
        </div>
        <p v-if="form.fields.username.error.value" :class="$style.fieldError">
          {{ form.fields.username.error.value }}
        </p>
      </div>

      <!-- Password Field with Visibility Toggle -->
      <div :class="$style.fieldGroup">
        <label :class="$style.label" :for="form.fields.password.id">
          <span>Password</span>
          <span :class="$style.required">*</span>
        </label>
        <div
          :class="[
            $style.inputWrapper,
            {
              [$style.hasError]: form.fields.password.error.value,
            },
          ]"
        >
          <PhLockKey weight="duotone" :class="$style.fieldIcon" />
          <input
            :id="form.fields.password.id"
            ref="password"
            v-model="form.fields.password.value.value"
            :class="$style.input"
            autocomplete="current-password"
            placeholder="••••••••••••"
            required
            :type="showPassword ? 'text' : 'password'"
          />
          <button
            type="button"
            :class="[
              $style.togglePasswordBtn,
              {
                [$style.toggleActive]: showPassword,
              },
            ]"
            :title="showPassword ? 'Hide password' : 'Show password'"
            @click="toggleShowPassword"
          >
            <div :class="$style.eyeIconWrapper">
              <PhEye
                weight="bold"
                :class="[
                  $style.eyeIcon,
                  $style.eyeOpen,
                  {
                    [$style.eyeVisible]: !showPassword,
                    [$style.eyeHidden]: showPassword,
                  },
                ]"
              />
              <PhEyeSlash
                weight="bold"
                :class="[
                  $style.eyeIcon,
                  $style.eyeSlash,
                  {
                    [$style.eyeVisible]: showPassword,
                    [$style.eyeHidden]: !showPassword,
                  },
                ]"
              />
            </div>
          </button>
        </div>
        <p v-if="form.fields.password.error.value" :class="$style.fieldError">
          {{ form.fields.password.error.value }}
        </p>
      </div>
    </div>

    <!-- High-Contrast Error Alert -->
    <div v-if="form.isValid.value && error" :class="$style.errorBanner">
      <PhWarningCircle weight="fill" :class="$style.errorIcon" />
      <span :class="$style.errorText">{{ error }}</span>
    </div>

    <!-- Neo-Green Power Connect Button -->
    <button
      type="submit"
      :class="[
        $style.submitButton,
        {
          [$style.loadingState]: loading,
        },
      ]"
      :disabled="loading"
    >
      <span v-if="!loading" :class="$style.btnContent">
        <span>Sign In</span>
        <span :class="$style.btnArrow">→</span>
      </span>
      <span v-else :class="$style.btnLoading">
        <span :class="$style.loaderDot" />
        <span :class="$style.loaderDot" />
        <span :class="$style.loaderDot" />
        <span :class="$style.loadingText">Connecting...</span>
      </span>
    </button>
  </form>
</template>

<style module>
.form {
  display: flex;
  flex-direction: column;
  gap: 18px;
  width: 100%;
}

.fieldList {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.fieldGroup {
  display: flex;
  flex-direction: column;
  gap: 6px;
  width: 100%;
}

.label {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #a1a1aa;
}

.required {
  color: #22c55e;
}

.inputWrapper {
  position: relative;
  display: flex;
  align-items: center;
  width: 100%;
  background-color: #12131a;
  border: 2px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  box-shadow: 3px 3px 0px #000000;
  padding: 0 12px;
  transition: all 0.15s ease;

  &:hover {
    border-color: rgba(255, 255, 255, 0.25);
  }

  &:focus-within {
    border-color: #22c55e;
    box-shadow: 4px 4px 0px #000000, 0 0 16px rgba(34, 197, 94, 0.25);
    transform: translate(-1px, -1px);
  }
}

.hasError {
  border-color: #ff477e !important;
  box-shadow: 3px 3px 0px #ff477e !important;
}

.fieldIcon {
  width: 20px;
  height: 20px;
  color: #71717a;
  flex-shrink: 0;
  transition: color 0.15s ease;

  .inputWrapper:focus-within & {
    color: #22c55e;
  }
}

.input {
  width: 100%;
  padding: 12px 10px;
  background: transparent;
  border: none;
  color: #ffffff;
  font-size: 0.92rem;
  font-weight: 600;
  outline: none;
  font-family: inherit;

  &::placeholder {
    color: #52525b;
    font-weight: 400;
  }
}

.togglePasswordBtn {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  padding: 0;
  color: #71717a;
  background: transparent;
  border: 1px solid transparent;
  cursor: pointer;
  border-radius: 8px;
  transition: all 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
  user-select: none;

  &:hover {
    color: #22c55e;
    background: rgba(34, 197, 94, 0.1);
    border-color: rgba(34, 197, 94, 0.25);
    transform: scale(1.08);
  }

  &:active {
    transform: scale(0.85);
    background: rgba(34, 197, 94, 0.2);
  }
}

.toggleActive {
  color: #22c55e;
  background: rgba(34, 197, 94, 0.08);
  border-color: rgba(34, 197, 94, 0.2);
}

.eyeIconWrapper {
  position: relative;
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.eyeIcon {
  position: absolute;
  width: 18px;
  height: 18px;
  transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1),
    opacity 0.2s ease,
    color 0.2s ease;
  will-change: transform, opacity;
}

.eyeVisible {
  opacity: 1;
  transform: scale(1) rotate(0deg);
}

.eyeOpen.eyeHidden {
  opacity: 0;
  transform: scale(0.3) rotate(-45deg);
  pointer-events: none;
}

.eyeSlash.eyeHidden {
  opacity: 0;
  transform: scale(0.3) rotate(45deg);
  pointer-events: none;
}

.fieldError {
  font-size: 0.75rem;
  color: #ff477e;
  font-weight: 600;
  margin-top: 2px;
  padding-left: 2px;
}

.configuredServerRow {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  background-color: #12131a;
  border: 2px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  box-shadow: 2px 2px 0px #000000;
}

.serverBadge {
  display: flex;
  align-items: center;
  gap: 8px;
  overflow: hidden;
}

.serverIcon {
  width: 16px;
  height: 16px;
  color: #22c55e;
  flex-shrink: 0;
}

.serverUrlText {
  font-size: 0.8rem;
  font-weight: 600;
  color: #d1d5db;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.changeServerBtn {
  font-size: 0.74rem;
  font-weight: 700;
  color: #22c55e;
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px 6px;

  &:hover {
    color: #4ade80;
    text-decoration: underline;
  }
}

/* Error Banner */
.errorBanner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background-color: rgba(255, 71, 126, 0.1);
  border: 2px solid #ff477e;
  border-radius: 10px;
  box-shadow: 3px 3px 0px #000000;
  color: #ffb4c8;
  animation: errorShake 0.4s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
}

@keyframes errorShake {
  10%, 90% { transform: translate3d(-1px, 0, 0); }
  20%, 80% { transform: translate3d(2px, 0, 0); }
  30%, 50%, 70% { transform: translate3d(-3px, 0, 0); }
  40%, 60% { transform: translate3d(3px, 0, 0); }
}

.errorIcon {
  width: 20px;
  height: 20px;
  color: #ff477e;
  flex-shrink: 0;
}

.errorText {
  font-size: 0.84rem;
  font-weight: 600;
  line-height: 1.3;
}

/* Neo-Green Solid Power Button */
.submitButton {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 13px 20px;
  margin-top: 6px;
  background-color: #22c55e;
  color: #000000;
  border: 2px solid #000000;
  border-radius: 12px;
  font-size: 0.96rem;
  font-weight: 800;
  letter-spacing: 0.02em;
  cursor: pointer;
  box-shadow: 4px 4px 0px #000000, 0 0 20px rgba(34, 197, 94, 0.3);
  transition: transform 0.12s cubic-bezier(0.4, 0, 0.2, 1),
    box-shadow 0.12s cubic-bezier(0.4, 0, 0.2, 1),
    background-color 0.15s ease;

  &:hover:not(:disabled) {
    background-color: #1ed760;
    transform: translate(-2px, -2px);
    box-shadow: 6px 6px 0px #000000, 0 0 28px rgba(34, 197, 94, 0.5);
  }

  &:active:not(:disabled) {
    transform: translate(2px, 2px);
    box-shadow: 1px 1px 0px #000000;
  }

  &:disabled {
    opacity: 0.75;
    cursor: wait;
  }
}

.btnContent {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.btnArrow {
  font-size: 1.15rem;
  font-weight: 900;
  transition: transform 0.15s ease;

  .submitButton:hover & {
    transform: translateX(4px);
  }
}

.btnLoading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.loaderDot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background-color: #000000;
  animation: dotPulse 1s infinite alternate ease-in-out;

  &:nth-child(2) {
    animation-delay: 0.2s;
  }
  &:nth-child(3) {
    animation-delay: 0.4s;
  }
}

@keyframes dotPulse {
  0% { transform: scale(0.6); opacity: 0.3; }
  100% { transform: scale(1.2); opacity: 1; }
}

.loadingText {
  margin-left: 4px;
  font-weight: 800;
}
</style>
