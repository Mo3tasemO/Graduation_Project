import { Platform } from 'react-native';
import * as LocalAuthentication from 'expo-local-authentication';

/** Is fingerprint / Face ID usable on this device, and what should we call it? */
export async function biometricInfo(): Promise<{ available: boolean; label: string }> {
  if (Platform.OS === 'web') return { available: false, label: 'Biometrics' };
  try {
    const [hw, enrolled, types] = await Promise.all([
      LocalAuthentication.hasHardwareAsync(),
      LocalAuthentication.isEnrolledAsync(),
      LocalAuthentication.supportedAuthenticationTypesAsync(),
    ]);
    const face = types.includes(LocalAuthentication.AuthenticationType.FACIAL_RECOGNITION);
    return { available: hw && enrolled, label: face ? 'Face ID' : 'Fingerprint' };
  } catch {
    return { available: false, label: 'Biometrics' };
  }
}

export async function biometricPrompt(message: string): Promise<boolean> {
  try {
    const r = await LocalAuthentication.authenticateAsync({ promptMessage: message, cancelLabel: 'Cancel', disableDeviceFallback: false });
    return r.success;
  } catch {
    return false;
  }
}
