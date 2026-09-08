# Invited tester API deployment

The Android API is hosted at https://168.144.64.47. Nginx terminates TLS and forwards to a Node process bound to 127.0.0.1:3000. PostgreSQL is loopback-only. The systemd service runs as the unprivileged `jyotara` user.

Runtime layout:
- `/opt/jyotara/releases/20260908-tester`: bundled server, pg dependencies, migration script and SQL migrations.
- `/opt/jyotara/current`: active release symlink.
- `/etc/jyotara/api.env`: root-only configuration loaded by systemd. Never commit or print this file.
- `/etc/letsencrypt/live/jyotara-ip`: certificate managed by Certbot. The supplied timer checks renewal twice daily; the deploy hook checks and reloads Nginx.

Build the server using `node scripts/build-server.mjs` from services/api. The runtime artifact requires pg 8.23.0 plus scripts/migrate-postgres.mjs and drizzle/*.sql. Install runtime dependencies on Linux with scripts disabled. Apply migrations with the Node runtime and the root-only environment file before restarting the API service. The migration entrypoint supports symlinked release directories and checks applied migration checksums.

Required environment names: DATABASE_URL, PROKERALA_CLIENT_ID, PROKERALA_CLIENT_SECRET, PROKERALA_ENVIRONMENT, JYOTARA_CHART_TICKET_KEY (or preserved NIRAYANA_CHART_TICKET_KEY), JYOTARA_TESTER_CODES_SHA256, JYOTARA_TESTER_EXPIRES_AT. Set JYOTARA_QUESTION_LIMIT=15 for this restricted test. Configure OPENROUTER_API_KEY and OPENROUTER_MODEL before evaluating model answers. Raw invitation codes belong only in private tester delivery records; no provider credentials or shared invitation is compiled into the APK.

Verification on 8 September: health returned 200 with an application-table query, missing invitation returned 401, valid invitation returned 200, malformed chart input returned 400 without requesting a provider calculation. Simulated certificate renewal and reload succeeded. These checks do not establish answer quality, backup recovery or physical Android readiness. The model key was not configured at this checkpoint.
