import { env } from '$env/dynamic/public';
import { version } from '../../package.json';

export const brand = {
  name: env.PUBLIC_APP_NAME || 'BrainSwap',
  tagline: env.PUBLIC_APP_TAGLINE || 'Hand off AI jobs when your model cannot finish them.',
  version: `v${version}`
} as const;
export const ACKNOWLEDGEMENT_VERSION = 'brainswap-data-boundary-v1';
