# Jyotara

Tamil-first traditional Vedic guidance app. This repository contains the Flutter mobile client and its API/web pilot source. It is under development and is not a production launch package.

- `apps/mobile`: Flutter Android app, widgets, encrypted local profile storage and regression tests.
- `services/api`: TypeScript API, web interface, Cloudflare D1 schema/migrations and regression tests.
- `docs/compatibility.md`: identifiers intentionally retained to protect existing installations and data.
- `docs/verification.md`: reproducible local checks and private historical QA instructions.

## Local development

Use Flutter 3.47.2 / Dart 3.13.2, Java 17, an Android SDK, and Node.js 24. Dependencies are pinned in the app lockfiles. Use pnpm 11.19.0 for the API.

```sh
cd services/api
pnpm install --frozen-lockfile
pnpm dev
```

The optional historical web location widget needs `NEXT_PUBLIC_PROKERALA_CLIENT_ID` at build time. This public identifier is separate from server secrets. The mobile client uses the server location route instead.

The API binds to loopback and uses local emulated Cloudflare bindings. Configure provider credentials and a 32-byte chart encryption key in an ignored local environment file, following `.env.example`. Never commit credentials. Keep the chart encryption key unchanged when migrating existing records.

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define=JYOTARA_API_BASE_URL=https://YOUR_CONFIGURED_API_HOST
```

The default API URL uses the reserved `.invalid` domain. A real HTTPS API must be explicitly configured; the app does not silently call the historical pilot. For Android local debug only, forward port 5173 with `adb reverse tcp:5173 tcp:5173` and use both `--dart-define=JYOTARA_API_BASE_URL=http://127.0.0.1:5173` and `--dart-define=JYOTARA_LOCAL_QA=true`. Local HTTP is rejected outside debug mode.

## Release status

The canonical repository is `innovfix123/JYOTARA`. The user-designated deployment target is DigitalOcean, but this backend currently depends on Cloudflare Workers/D1. A production runtime/database migration, HTTPS endpoint, operational monitoring, recovery plan, load testing and production signing remain required. Copying this repository onto a server does not deploy a working production service.

Relationship guidance includes prepared practical responses and bounded same-guide user context. Passing routing tests does not demonstrate broad answer quality. The historical 300-answer evaluation and private provider records are excluded from Git; its reported failures must not be reclassified by synthetic tests. No expert certification or predictive accuracy is implied.

The old website has not been deployed or modified by this repository import. Historical source and private QA are preserved outside this checkout.
