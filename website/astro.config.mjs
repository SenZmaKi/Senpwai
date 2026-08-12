// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig(({ command }) => ({
  site: 'https://senzmaki.github.io',
  base: command === 'dev' ? '/' : '/Senpwai',
  trailingSlash: 'never',
  vite: {
    plugins: [tailwindcss()]
  }
}));
