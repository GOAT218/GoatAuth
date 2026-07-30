import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: {
          DEFAULT: "#0a0a0f",
          soft: "#111119",
          card: "#14141d",
          elevated: "#1a1a26",
        },
        border: {
          DEFAULT: "#232333",
          soft: "#1c1c29",
        },
        brand: {
          50: "#eefbf4",
          100: "#d6f5e3",
          200: "#b0eacb",
          300: "#7bd9ac",
          400: "#43c186",
          500: "#1fa96b",
          600: "#128756",
          700: "#0f6b47",
          800: "#10553a",
          900: "#0e4631",
          950: "#04271b",
        },
        accent: {
          DEFAULT: "#5b8cff",
          soft: "#2a3a66",
        },
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-mono)", "ui-monospace", "monospace"],
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(31,169,107,0.25), 0 8px 40px -12px rgba(31,169,107,0.35)",
        card: "0 1px 0 0 rgba(255,255,255,0.03) inset, 0 12px 40px -20px rgba(0,0,0,0.8)",
      },
      keyframes: {
        "fade-up": {
          "0%": { opacity: "0", transform: "translateY(12px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        shimmer: {
          "100%": { transform: "translateX(100%)" },
        },
      },
      animation: {
        "fade-up": "fade-up 0.5s ease-out both",
        shimmer: "shimmer 1.5s infinite",
      },
    },
  },
  plugins: [],
};

export default config;
