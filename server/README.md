# MobileStarter server

Next.js App Router service for the MobileStarter clients. It exposes the versioned API under
`/api/v1` and includes a small configuration control plane.

## Development

```bash
cp .env.example .env.local
npm ci
npm run dev
```

Run validation with:

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

## Docker / GHCR

The GitHub `Server Image` workflow publishes:

```text
ghcr.io/rwecho/mobilestarter-server:latest
```

Run it with the included Compose definition:

```bash
cp .env.example .env.local
docker compose up -d
```

The service uses the Node.js runtime and SQLite. Compose mounts the `mobilestarter-data` volume
at `/app/data`; keep that volume when upgrading the image.

Set all secret values from `.env.example` in the hosting platform rather than committing an
environment file. Use a public HTTPS origin for `MOBILEUI_PUBLIC_ORIGIN`.
