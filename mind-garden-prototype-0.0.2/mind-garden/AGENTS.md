# Instructions for Codex

This is an Android-first, offline, Russian Buddhist practice and mood-journal app
in Godot/GDScript. The garden is an interactive visual backdrop, not a game loop.
Read README.md and DESIGN.md before changing scope. Do not migrate it to a web
app, Flutter, Unity, or a backend without a concrete reason and user direction.

- Implement one small, testable change at a time.
- Keep state, rendering, and UI separate.
- Do not add daily streaks, moral scores, guilt for absence, analytics, AI calls,
  accounts, cloud syncing, ads, health sensors, or multiplayer by default.
- Time outside the app is simulated on re-entry. Never require a perpetual service.
- Re-entry must not replay rewards or double-count elapsed time.
- Mood effects are atmosphere, not karmic judgment. Preserve the user's intent.
- Do not write invented quotations or free-generated replies as the historical Buddha.
- Russian UI uses lowercase polite «вы», neutral gender, restrained warmth and light humor.
- Never use an em dash in copy or documentation.
- Keep existing save data, version the schema, and test migrations before release.
- Never include personal journal files, signing keys, or access tokens in the archive.
- Use a portrait screen. App functions open from bottom controls, not world hotspots.
- Navigate adjacent screens with left/right side arrows. Do not restore a bottom tab bar or top dashboard.
- Player movement is decorative and optional, only in the main garden screen.
- Previous procedural scenery was rejected completely. New generated pixel assets
  are a proposed direction, not approved final brand art. Use assets/ART-DIRECTION.md.
- Before reporting success run engine import, state tests, and UI smoke.
- Review log contents, not just exit status. GDScript runtime errors can exit with code 0.
- Android support in source is not the same as a built or device-tested APK.
- Do not spawn sub-agents unless the user explicitly requests delegation.
