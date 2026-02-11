# danielfoojunwei.com-old-portfolio-website-

Production-ready snapshot and deployment setup for `https://danielfoojunwei.com/`.

## Goal

This repo is set up so you can preserve a full static copy before cancelling Squarespace and deploy it on Vercel.

## What was added

- `scripts/clone-site.sh`
  - Mirrors the site with `wget --mirror`.
  - Includes page requisites and converts links for static hosting.
  - Spans known Squarespace/CDN hosts to capture required assets.
  - Fails fast when the output is incomplete (for safer production usage).
- `vercel.json`
  - Prefer deploying committed snapshot from `site/`.
  - Falls back to mirroring at build-time only if `site/index.html` is missing.
- `.github/workflows/mirror-site.yml`
  - Manual trigger + daily snapshot refresh.
  - Auto-commits updates to `site/` when the live site changes.

## Clone now (recommended)

Run this once from any machine/runner with outbound internet access:

```bash
bash scripts/clone-site.sh
```

Then commit the generated `site/` folder so Vercel can serve a stable snapshot even after Squarespace is cancelled.

## Deploy to Vercel

1. Import this repository into Vercel.
2. Deploy.
3. Vercel serves the static output from `site/`.

## Optional environment variables

- `TARGET_URL` (default: `https://danielfoojunwei.com/`)
- `OUTPUT_DIR` (default: `site`)
- `TMP_DIR` (default: `.mirror-tmp`)
- `MIRROR_DOMAINS` (comma-separated allow-list for `wget --domains`)
