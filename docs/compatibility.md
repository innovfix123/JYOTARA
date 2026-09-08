# Rename and saved-data compatibility

The product display name, Dart package and classes, API provider title, Android code namespace and web metadata use Jyotara.

These old identifiers are deliberately retained because changing them would require a separate migration:

- Android application ID `in.innovfix.nirayana`: preserves the installed app's data sandbox. Updates also require the same signing certificate; the private signing key is not part of this repository.
- Secure storage key `nirayana.private-profile.v1` and preference keys `nirayana.chat_language.v1` / `nirayana.ui_language.v1`: preserve profiles, pending requests and language settings.
- Session cookie `nirayana_pilot_session`: preserves client/server session ownership.
- Authenticated-encryption additional-data domains `nirayana:anonymous-chart:v1` and `nirayana:guidance-reply:v1:`: preserve decryption of existing chart tickets and saved replies.
- Browser history field `nirayanaScreen`: preserves history entries already in open browser sessions.
- `NIRAYANA_API_BASE_URL`, `NIRAYANA_LOCAL_QA` and `NIRAYANA_CHART_TICKET_KEY`: legacy configuration aliases. New configuration uses `JYOTARA_*`. New API URL and encryption-key variables take precedence when defined. Either debug QA flag enables the existing exact-loopback exception, only in debug mode.

Changing the API origin is a server migration, not just a rename: saved server sessions and chart tickets belong to their original origin. Existing client origin checks remain in place. Existing records require the matching database and encryption key on the new service; importing source does not perform that migration.

Local tests cover persisted sessions, profile restore/replacement/deletion, pending request replay, encrypted tickets and stored replies. A signed in-place device upgrade with an existing profile is still needed before a release compatibility claim.


## Gender selection

New profiles explicitly select Male, Female, Non-binary or Prefer not to say. Nothing is preselected. Existing profiles without this field remain readable; missing/unrecognized metadata is treated as unselected. The value is saved alongside the profile in the existing encrypted local vault and cleared on profile replacement/deletion. Updating it with unchanged birth inputs preserves the chart and conversations. It is not included in chart-provider or guidance requests in this version and is not part of the calculation identity. No calculation-accuracy or language-personalization claim is made from this field alone.
