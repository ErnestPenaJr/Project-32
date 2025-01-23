module.exports = {
  content: [
    './pages/**/*.{html,js,cfm}',
    './components/**/*.{html,js,cfm}',
    './layouts/**/*.{html,js,cfm}',
    './views/**/*.{html,js,cfm}',
    './*.{html,js,cfm}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1a365d',
        secondary: '#718096',
        accent: '#4299e1',
      },
    },
  },
  plugins: [],
}
