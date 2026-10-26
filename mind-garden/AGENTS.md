# Instructions for Codex

This is an Android-first, offline, Russian Buddhist practice and mood-journal app
in Godot/GDScript. The garden is an interactive visual backdrop, not a game loop.
Read README.md and DESIGN.md before changing scope. Do not migrate it to a web
app, Flutter, Unity, or a backend without a concrete reason and user direction.

- Implement one small, testable change at a time.
- Keep state, rendering, and UI separate.
- Do not add daily streaks, moral scores, guilt for absence, remote analytics, AI calls,
  accounts, cloud syncing, ads, health sensors, or multiplayer by default.
- World time outside the app is simulated on re-entry. Meditation continues on desktop focus loss; reliable Android locked-screen audio is a separate export-stage task.
- User explicitly authorizes local aggregate interaction patterns to vary scenery. No moral/psychological interpretation, no raw keystrokes, no tracking outside this app.
- APK export is deferred by the user. Future target: Nothing Phone (3a) Pro, Android 16, Nothing OS 4.1.
- Re-entry must not replay rewards or double-count elapsed time.
- Mood effects are atmosphere, not karmic judgment. Preserve the user's intent.
- Do not write invented quotations or free-generated replies as the historical Buddha.
- Russian UI uses lowercase polite «вы», neutral gender, restrained warmth and light humor.
- Never use an em dash in copy or documentation.
- Keep existing save data, version the schema, and test migrations before release.
- Never include personal journal files, signing keys, or access tokens in the archive.
- Use a portrait screen. App functions open from bottom controls AND optional desk/cushion hotspots.
- Navigate adjacent screens with swipes and visible left/right side arrows. Do not restore a bottom tab bar or top dashboard.
- Player movement is decorative and optional on all three screens; allow walking through side exits.
- Previous procedural scenery was rejected completely. New generated pixel assets
  are a proposed direction, not approved final brand art. Use assets/ART-DIRECTION.md.
- Before reporting success run engine import, state tests, and UI smoke.
- Review log contents, not just exit status. GDScript runtime errors can exit with code 0.
- Android support in source is not the same as a built or device-tested APK.
- Do not spawn sub-agents unless the user explicitly requests delegation.

# Revision 0.0.4
- Tiny5 was explicitly rejected. Use Manrope for all UI text, including titles and timers.
- Main garden has no primary CTA; show the actual dynamic garden elements with icons and counts.
- Side navigation and sound are icon-only, with tooltip descriptions.
- Keep the enlarged camera crop, readable actor/plant sizes, and mask-based A* navigation.
- Preserve the approved cat art. Side walking uses contact/passing poses.
- Fix all GDScript warnings; do not suppress them or disable warnings-as-errors.
- Time-of-day light follows the local device clock; tests may override hours only in capture mode.
