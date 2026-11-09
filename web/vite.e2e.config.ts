import path from 'node:path'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// E2E-only dev server: serves the app on :8090 and proxies /api to the
// backend so the browser never makes a cross-origin request (avoids the
// CORS allowlist when ports 3000/5173 are occupied by other projects).
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  server: {
    port: 8090,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
      },
    },
  },
})
