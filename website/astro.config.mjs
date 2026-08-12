// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://senzmaki.github.io',
  base: '/Senpwai',
  trailingSlash: 'never',
  vite: {
    plugins: [tailwindcss()]
  }
});
