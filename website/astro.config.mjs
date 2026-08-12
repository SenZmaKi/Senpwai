// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig(({ command }) => ({
  site: 'https://senzmaki.github.io',
  base: command === 'dev' ? '/' : '/Senpwai',
  trailingSlash: 'never',
}));
