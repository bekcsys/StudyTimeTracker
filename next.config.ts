import type { NextConfig } from "next";

const djangoOrigin = process.env.DJANGO_ORIGIN ?? "http://127.0.0.1:8000";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${djangoOrigin}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
