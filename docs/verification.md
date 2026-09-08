# Verification

From `services/api`:

```sh
pnpm install --frozen-lockfile
pnpm test
pnpm typecheck
pnpm build
```

From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
flutter test --dart-define=JYOTARA_LOCAL_QA=true test/local_backend_boundary_test.dart
flutter test --dart-define=NIRAYANA_LOCAL_QA=true test/local_backend_boundary_test.dart
flutter build apk --debug --dart-define=JYOTARA_API_BASE_URL=https://YOUR_CONFIGURED_API_HOST
```

APK compilation alone does not test server connectivity or answer quality. Debug signing is for internal builds only. Production signing is not configured.

## Private historical regression

The default API suite uses fabricated fixtures, including three explicit natal occupancy geometries in `tests/fixtures/charts.synthetic.json`. They are not provider-calculated charts or evidence of real-answer quality.

The original historical compatibility checks and 300-case coverage audit remain available separately. Set `JYOTARA_PRIVATE_QA_DIR` to the private directory containing `results.json`, `all-100-questions-three-profiles.json` and `manual-review-local.json`, set `JYOTARA_PRIVATE_YOGA_FILE` to the retained paid yoga response file, then run:

```sh
node --test private-tests/*.test.mjs
node scripts/evaluate-retained-coverage.mjs --summary
```

These checks intentionally fail if the private records are absent or incomplete. They never fetch providers, generate answers, or convert historical failures into quality passes. Keep input files and audit outputs outside this repository.

## Publication checks

Review every staged file before the initial push. Exclude keys, local environment values, private QA, databases, APKs, toolchains, dependency folders and build outputs. `.gitignore` is a guardrail; it is not a substitute for inspecting the actual staged contents. GitHub write authentication must be verified separately before reporting a successful push.
