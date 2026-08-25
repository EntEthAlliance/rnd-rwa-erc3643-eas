import type { Config } from "tailwindcss";

// EEA editorial family (https://intelligence.entethalliance.org/):
// light-only warm paper, Inter / Kode Mono, program-green accent, hard edges.
// Stock palettes used in markup (slate/emerald/amber/blue/red) are remapped
// to editorial-warm equivalents so every utility class resolves on-language.
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        shibui: {
          ink: "#16181A",
          paper: "#EDEAE3",
          accent: "#1F5C4A",
          accentDeep: "#123A2E",
          ok: "#1F5C4A",
          warn: "#765A00",
          err: "#9B413C",
          errDeep: "#7C332E",
        },
        slate: {
          50: "#F7F5F0",
          100: "#E3DFD7",
          200: "#DAD6CD",
          300: "#C9C4BB",
          400: "#8A9088",
          500: "#5A645E",
          600: "#49524C",
          700: "#3A423D",
          800: "#23282A",
          900: "#10231E",
        },
        emerald: {
          50: "#E4EAE4",
          200: "#B9CDC0",
          800: "#1F5C4A",
        },
        amber: {
          50: "#F4EDDA",
          200: "#E2D3A1",
          700: "#765A00",
          800: "#765A00",
        },
        blue: {
          50: "#E2E8EC",
          200: "#BFCBD4",
          800: "#2A5A74",
        },
        red: {
          50: "#F2E3DF",
          200: "#DFBBB2",
          800: "#9B413C",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "Segoe UI", "sans-serif"],
        mono: ["Kode Mono", "ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
