import { reactive } from 'vue';

export function useDialogs() {
  const connectDialog = reactive({
    visible: false,
    label: 'Connecting...',
    message: '',
  });

  const toast = reactive({
    visible: false,
    message: '',
    color: 'warning',
    timeout: 4000,
  });

  return {
    connectDialog,
    toast,
  };
}
