/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        paper: 'var(--paper)',
        'paper-line': 'var(--paper-line)',
        ink: 'var(--ink)',
        'ink-soft': 'var(--ink-soft)',
        brand: {
          100: 'var(--brand-100)',
          300: 'var(--brand-300)',
          500: 'var(--brand-500)',
          700: 'var(--brand-700)',
          900: 'var(--brand-900)',
        },
      },
      fontFamily: {
        display: ['var(--font-display)'],
        body: ['var(--font-body)'],
        mono: ['var(--font-mono)'],
      },
      borderRadius: {
        DEFAULT: 'var(--radius)',
      },
    },
  },
  plugins: [],
}
