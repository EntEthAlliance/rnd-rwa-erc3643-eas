/** @type {import('next').NextConfig} */
const isPagesExport = process.env.NEXT_PUBLIC_BASE_PATH !== undefined
  || process.env.GITHUB_PAGES === "true";

const nextConfig = {
  reactStrictMode: true,
  ...(isPagesExport && {
    output: "export",
    basePath: "/rnd-rwa-erc3643-eas",
    images: { unoptimized: true },
  }),
  webpack: (config) => {
    config.resolve.fallback = { ...config.resolve.fallback, fs: false, net: false, tls: false };
    // Optional RN-only peer of @metamask/sdk — never resolved in a browser build.
    config.resolve.alias = {
      ...(config.resolve.alias || {}),
      "@react-native-async-storage/async-storage": false,
    };
    config.externals.push("pino-pretty", "lokijs", "encoding");
    return config;
  },
};

module.exports = nextConfig;
