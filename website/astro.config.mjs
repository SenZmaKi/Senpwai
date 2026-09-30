// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://senpwai.com',
  trailingSlash: 'never',
  vite: {
    plugins: [tailwindcss()]
  }
});
