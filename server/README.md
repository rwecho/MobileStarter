# Zhongbei Auth

Authentication and account service for 苏州终北科技有限公司 and `zhongbei.tech`. It exposes
the versioned API under `/api/v1` and includes a configuration control plane.

## Development

```bash
cp .env.example .env.local
docker compose up -d postgres
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
ghcr.io/rwecho/zhongbei-auth:latest
```

Run it with the included Compose definition:

```bash
cp .env.example .env.local
docker compose up -d
```

The service uses the Node.js runtime and PostgreSQL 17. Compose starts both services and mounts
the `mobilestarter-postgres` volume at PostgreSQL's data directory; keep that volume when
upgrading the image. Set `MOBILEUI_POSTGRES_PASSWORD` before production deployment.

Set all secret values from `.env.example` in the hosting platform rather than committing an
environment file. Configure `AUTH_DATABASE_URL` (or `DATABASE_URL`) for external PostgreSQL,
and use a public HTTPS origin for `AUTH_PUBLIC_ORIGIN`.
