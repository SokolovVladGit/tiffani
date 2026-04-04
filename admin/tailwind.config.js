/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#fdf6f0",
          100: "#f9e8d8",
          200: "#f2d0b0",
          500: "#c98b5e",
          600: "#b07445",
          700: "#8f5d36",
          800: "#6e4729",
        },
      },
    },
  },
  plugins: [],
};
