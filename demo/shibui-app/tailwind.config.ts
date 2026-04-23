import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        shibui: {
          ink: "#0b1221",
          paper: "#f7f8fb",
          accent: "#2f6fed",
          ok: "#15803d",
          warn: "#b45309",
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
