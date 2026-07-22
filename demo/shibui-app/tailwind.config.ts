import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        shibui: {
          ink: "#0b1221",
          paper: "#f7f8fb",
          accent: "#627eea",
          ok: "#00d4aa",
          warn: "#fbbf24",
          err: "#b91c1c",
        },
      },
      fontFamily: {
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
