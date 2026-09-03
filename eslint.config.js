import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import svelte from 'eslint-plugin-svelte';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs['flat/recommended'],
  prettier,
  { ignores: ['.svelte-kit/**', 'build/**', 'src/lib/types/database.generated.ts'] },
  {
    languageOptions: { globals: { ...globals.browser, ...globals.node, App: 'readonly' } },
    rules: { 'svelte/no-navigation-without-resolve': 'off', 'svelte/require-each-key': 'off' }
  }
);
