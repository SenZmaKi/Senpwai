// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
const isDevServer = process.argv.includes('dev');

export default defineConfig({
  site: 'https://senzmaki.github.io',
  base: isDevServer ? '/' : '/Senpwai',
  trailingSlash: 'never',
});
