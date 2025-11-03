<template>
  <div class="spiffs-tab">
    <v-card class="tools-card" variant="tonal">
      <v-card-title class="tools-card__title">
        <v-icon size="18" class="me-2">mdi-folder-wrench</v-icon>
        SPIFFS Agent (ESP32-S3)
      </v-card-title>
      <v-card-text class="tools-card__body">
        <v-alert
          v-if="!isAvailable"
          type="warning"
          variant="tonal"
          border="start"
          density="comfortable"
          class="spiffs-agent__availability"
        >
          No SPIFFS partition detected for the connected device. Connect to a device with a SPIFFS partition to use these
          tools.
        </v-alert>

        <div class="spiffs-agent__status">
          <span>{{ spiffsAgentSummary }}</span>
          <span v-if="spiffsAgentStatusMessage">{{ spiffsAgentStatusMessage }}</span>
        </div>

        <v-alert
          v-if="spiffsAgentError"
          type="error"
          variant="tonal"
          border="start"
          density="comfortable"
          class="mt-2"
        >
          {{ spiffsAgentError }}
        </v-alert>

        <div class="tools-card__actions spiffs-agent__actions">
          <v-btn
            color="primary"
            variant="tonal"
            :loading="spiffsAgentLoading"
            :disabled="baseDisabled || spiffsAgentLoading || spiffsAgentBusy"
            @click="emit('load-spiffs-agent')"
          >
            <v-icon start>mdi-download</v-icon>
            Load Stub
          </v-btn>
          <v-btn
            color="primary"
            variant="elevated"
            :loading="spiffsAgentUploading"
            :disabled="
              baseDisabled ||
              spiffsAgentLoading ||
              !spiffsAgentLoaded ||
              spiffsAgentBusy ||
              spiffsAgentRunning
            "
            @click="emit('deploy-spiffs-agent')"
          >
            <v-icon start>mdi-send</v-icon>
            Upload &amp; Start
          </v-btn>
          <v-btn
            v-if="spiffsAgentRunning"
            color="primary"
            variant="text"
            :disabled="baseDisabled || spiffsAgentBusy"
            @click="emit('spiffs-list')"
          >
            <v-icon start>mdi-refresh</v-icon>
            Refresh Files
          </v-btn>
          <v-btn
            v-if="spiffsAgentRunning"
            color="warning"
            variant="text"
            :disabled="baseDisabled || spiffsAgentBusy"
            @click="emit('spiffs-format')"
          >
            <v-icon start>mdi-broom</v-icon>
            Format SPIFFS
          </v-btn>
          <v-btn
            v-if="spiffsAgentRunning"
            color="secondary"
            variant="text"
            :disabled="baseDisabled || spiffsAgentBusy"
            @click="emit('spiffs-reset')"
          >
            <v-icon start>mdi-restart</v-icon>
            Reset Device
          </v-btn>
        </div>

        <v-alert
          v-if="spiffsAgentLoaded && !spiffsAgentRunning"
          type="info"
          variant="tonal"
          border="start"
          density="comfortable"
          class="mt-3"
        >
          Stub binary is cached in the browser. Upload it to the connected device when ready.
        </v-alert>

        <v-divider v-if="spiffsAgentRunning" class="my-4" />

        <div v-if="spiffsAgentRunning" class="spiffs-agent__body">
          <div class="spiffs-agent__upload">
            <v-file-input
              :model-value="spiffsUploadFile"
              label="Local file"
              density="comfortable"
              clearable
              prepend-icon="mdi-file-upload"
              accept="*/*"
              :disabled="baseDisabled || spiffsAgentBusy"
              @update:model-value="handleSpiffsFileInput"
            />
            <v-text-field
              v-model="spiffsUploadName"
              label="Store as"
              density="comfortable"
              placeholder="example.txt"
              :disabled="baseDisabled || spiffsAgentBusy"
            />
            <v-btn
              color="primary"
              variant="elevated"
              :disabled="!canUploadToSpiffs || baseDisabled"
              @click="handleSpiffsUpload"
            >
              <v-icon start>mdi-upload</v-icon>
              Upload File
            </v-btn>
          </div>

          <v-table v-if="spiffsAgentFiles.length" class="spiffs-agent__table" density="comfortable">
            <thead>
              <tr>
                <th class="text-start">Name</th>
                <th class="text-start">Size</th>
                <th class="text-start spiffs-agent__actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="file in spiffsAgentFiles" :key="file.name">
                <td><code>{{ file.name }}</code></td>
                <td>{{ formatSpiffsFileSize(file.size) }}</td>
                <td class="spiffs-agent__row-actions">
                  <v-btn
                    size="small"
                    variant="text"
                    color="primary"
                    :disabled="spiffsAgentBusy || baseDisabled"
                    @click="emit('spiffs-download', file.name)"
                  >
                    <v-icon start size="16">mdi-download</v-icon>
                    Download
                  </v-btn>
                  <v-btn
                    size="small"
                    variant="text"
                    color="error"
                    :disabled="spiffsAgentBusy || baseDisabled"
                    @click="emit('spiffs-delete', file.name)"
                  >
                    <v-icon start size="16">mdi-delete</v-icon>
                    Delete
                  </v-btn>
                </td>
              </tr>
            </tbody>
          </v-table>

          <div v-else class="spiffs-agent__empty">
            No files on SPIFFS yet. Use the upload control above to add one.
          </div>
        </div>
      </v-card-text>
    </v-card>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';

const props = defineProps({
  busy: {
    type: Boolean,
    default: false,
  },
  maintenanceBusy: {
    type: Boolean,
    default: false,
  },
  spiffsAgentStatus: {
    type: Object,
    default: () => ({
      loading: false,
      loaded: false,
      size: 0,
      error: null,
      uploading: false,
      busy: false,
      commandActive: false,
      running: false,
      status: '',
      files: [],
    }),
  },
  available: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits([
  'load-spiffs-agent',
  'deploy-spiffs-agent',
  'spiffs-list',
  'spiffs-delete',
  'spiffs-upload',
  'spiffs-download',
  'spiffs-format',
  'spiffs-reset',
]);

const isAvailable = computed(() => Boolean(props.available));
const baseDisabled = computed(() => !isAvailable.value || props.busy || props.maintenanceBusy);
const spiffsAgentLoading = computed(() => Boolean(props.spiffsAgentStatus?.loading));
const spiffsAgentLoaded = computed(() => Boolean(props.spiffsAgentStatus?.loaded));
const spiffsAgentUploading = computed(() => Boolean(props.spiffsAgentStatus?.uploading));
const spiffsAgentBusy = computed(() =>
  Boolean(
    props.spiffsAgentStatus?.busy ||
      props.spiffsAgentStatus?.uploading ||
      props.spiffsAgentStatus?.commandActive,
  ),
);
const spiffsAgentRunning = computed(
  () => isAvailable.value && Boolean(props.spiffsAgentStatus?.running),
);
const spiffsAgentFiles = computed(() =>
  Array.isArray(props.spiffsAgentStatus?.files) ? props.spiffsAgentStatus.files : [],
);
const spiffsAgentSummary = computed(() => {
  if (!isAvailable.value) {
    return 'SPIFFS partition not detected.';
  }
  const status = props.spiffsAgentStatus || {};
  if (status.loading) return 'Loading stub...';
  if (status.uploading) return 'Uploading stub to device...';
  if ((status.commandActive || status.busy) && status.running)
    return 'Agent is busy processing a command...';
  if (status.error) return `Error: ${status.error}`;
  if (status.running) return 'Agent running on device.';
  if (status.loaded) {
    const size = status.size ? status.size.toLocaleString() : 'unknown';
    return `Stub cached (${size} bytes). Ready to upload.`;
  }
  return 'Stub not loaded yet.';
});
const spiffsAgentStatusMessage = computed(() => {
  if (!isAvailable.value) {
    return 'Connect to a device with a SPIFFS partition to use these tools.';
  }
  const message = props.spiffsAgentStatus?.status || '';
  if (!message) {
    return '';
  }
  return message === spiffsAgentSummary.value ? '' : message;
});
const spiffsAgentError = computed(() =>
  isAvailable.value ? props.spiffsAgentStatus?.error || '' : '',
);

const spiffsUploadFile = ref(null);
const spiffsUploadName = ref('');

const canUploadToSpiffs = computed(
  () =>
    isAvailable.value &&
    spiffsAgentRunning.value &&
    !spiffsAgentBusy.value &&
    Boolean(spiffsUploadFile.value),
);

watch(isAvailable, available => {
  if (!available) {
    spiffsUploadFile.value = null;
    spiffsUploadName.value = '';
  }
});

watch(
  () => (isAvailable.value ? Boolean(props.spiffsAgentStatus?.running) : false),
  (running, previous) => {
    if (running && !previous) {
      emit('spiffs-list');
    }
    if (!running) {
      spiffsUploadFile.value = null;
      spiffsUploadName.value = '';
    }
  },
);

function handleSpiffsFileInput(value) {
  const file = Array.isArray(value) ? value[0] : value;
  spiffsUploadFile.value = file || null;
  spiffsUploadName.value = file?.name || '';
}

function handleSpiffsUpload() {
  const file = spiffsUploadFile.value;
  if (!file) {
    return;
  }
  const desiredName = spiffsUploadName.value?.trim() || file.name;
  emit('spiffs-upload', {
    file,
    name: desiredName,
  });
}

function formatSpiffsFileSize(size) {
  if (!Number.isFinite(size) || size < 0) {
    return 'n/a';
  }
  if (size < 1024) {
    return `${size} B`;
  }
  const units = ['KB', 'MB', 'GB'];
  let value = size / 1024;
  let unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  const precision = value >= 10 ? 1 : 2;
  return `${value.toFixed(precision)} ${units[unitIndex]}`;
}
</script>

<style scoped>
.spiffs-tab {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.tools-card {
  border-radius: 18px;
  border: 1px solid color-mix(in srgb, var(--v-theme-primary) 16%, transparent);
  background: color-mix(in srgb, var(--v-theme-surface) 94%, transparent);
}

.tools-card__title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  font-size: 0.95rem;
}

.tools-card__body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.tools-card__actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.spiffs-agent__status {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 0.9rem;
  color: color-mix(in srgb, var(--v-theme-on-surface) 80%, transparent);
}

.spiffs-agent__availability {
  font-size: 0.9rem;
}

.spiffs-agent__actions {
  gap: 10px;
}

.spiffs-agent__body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.spiffs-agent__upload {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: flex-end;
}

.spiffs-agent__table code {
  font-size: 0.85rem;
}

.spiffs-agent__actions-col {
  width: 180px;
}

.spiffs-agent__row-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.spiffs-agent__empty {
  font-size: 0.9rem;
  color: color-mix(in srgb, var(--v-theme-on-surface) 65%, transparent);
}
</style>
