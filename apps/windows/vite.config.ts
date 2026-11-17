import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

// Tauri: sabit port, ekran temizleme yok.
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  resolve: {
    alias: {
      '@shared': path.resolve(__dirname, '../../shared'),
      '@': path.resolve(__dirname, 'src'),
    },
  },
  server: { port: 1420, strictPort: true, fs: { allow: ['..', '../..'] } },
  envPrefix: ['VITE_'],
  build: { target: 'es2020', outDir: 'dist', sourcemap: false },
});
