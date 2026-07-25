import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // API is proxied by src/app/api/[...path]/route.ts so Django always
  // sees Host 127.0.0.1 — works for localhost and LAN/Tailscale URLs.
};

export default nextConfig;
