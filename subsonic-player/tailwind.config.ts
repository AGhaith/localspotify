import type { Config } from 'tailwindcss';

export default <Partial<Config>>{
  darkMode: 'class',
  content: [
    './components/**/*.{vue,js,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './composables/**/*.{js,ts}',
    './plugins/**/*.{js,ts}',
    './app.vue',
    './error.vue',
  ],
  theme: {
    extend: {
      colors: {
        'neo-green': '#22c55e',
        'neo-yellow': '#facc15',
        'neo-purple': '#8b5cf6',
        'neo-pink': '#ff477e',
        'neo-cyan': '#06b6d4',
        'neo-dark': '#0c0d14',
        'neo-card': '#131420',
        'neo-secondary': '#1d1e2e',
      },
      boxShadow: {
        'neo-sm': '2px 2px 0px #000000',
        neo: '4px 4px 0px #000000',
        'neo-lg': '6px 6px 0px #000000',
        'neo-accent': '4px 4px 0px #22c55e',
        'neo-yellow': '4px 4px 0px #facc15',
        'neo-purple': '4px 4px 0px #8b5cf6',
        'neo-pink': '4px 4px 0px #ff477e',
      },
      fontFamily: {
        display: ['CircularSp', 'CircularStd', 'Circular', 'Plus Jakarta Sans', 'Outfit', 'sans-serif'],
        sans: [
          'CircularSp',
          'CircularStd',
          'Circular',
          'Plus Jakarta Sans',
          'Outfit',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ],
      },
      borderWidth: {
        3: '3px',
      },
    },
  },
  plugins: [],
};
