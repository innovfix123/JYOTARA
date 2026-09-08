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

## Verified release switching

The active API now uses immutable release `3d8ab8d`. Activate an already-built, compatible release with `/usr/local/sbin/activate-jyotara RELEASE`. It atomically replaces the active symlink, restarts the service and checks application health. A failed health check restores the previous release and checks it again. This does not reverse database migrations: confirm backward schema compatibility before switching or rolling back code.

The `--evaluation` option uses only the separate evaluation link, service and loopback port3001. A deliberately failing process was tested there on 8 September; the previous healthy release was restored. Production stayed healthy. Transient evaluation services are removed by systemd after stopping; recreate them deliberately before another isolated test.

## Backups and model state

The configured model is now `openai/gpt-5.4`; credentials are loaded from the root-only environment. Nightly custom-format PostgreSQL backups use a seven-day age threshold, checked nightly. A restore into a temporary database succeeded. A manual off-server database/configuration copy is held in private operator storage; automated off-site backup remains separate work. No backup or environment file belongs in Git.

## Tester APK

From `apps/mobile`, run `python3 tool/build_tester_apk.py BUILD_NUMBER --flutter PATH_TO_FLUTTER` with the configured Android/JDK environment. It sets HTTPS, invitation gating and visible build metadata together. Verify and apply the established internal QA signing identity before handoff. Do not replace an installed tester app's signing identity or uninstall it to work around an upgrade failure: that may lose local profiles and history. These debug candidates are for internal testing, not store distribution.
