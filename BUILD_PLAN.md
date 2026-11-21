# CallCenter Pro — agent app build plan

The app is built in stages. Each stage is usable on its own, and every
feature is multi-tenant: data is scoped by `tenant_id`, agents sign in with
their **company name + extension + password**, and the SIP user stays
`{company_slug}_{extension}_ws`.

## Stage 1 — Foundation + live theming  ✅ (in this delivery)
- `server/app_schema.sql` — multi-tenant app tables (settings/theme, access,
  per-agent permissions, devices, login attempts, work photos, location).
- `server/app_api.php` — `/app/v1` agent API: login (on `tenant_extensions`,
  with lockout), bootstrap (theme + permissions + settings), device register.
- `server/app_jwt.php` — token signing.
- `server/control-panel/app_theme.php` — **admin picks the brand colour; every
  agent's app for that company recolours** (stored + bumped `theme_rev` +
  `theme.update` broadcast to the tenant's realtime channel).
- `flutter_app/` — theme model, controller (cache → bootstrap → live update),
  API + realtime clients, and a login screen that proves the whole path.

How the colour flow works end to end:
1. Admin saves a colour in `app_theme.php`.
2. Server stores it and pushes `theme.update` to the tenant channel.
3. Open apps recolour within ~1s; others load it at next sign-in; the device
   caches it so there is no colour flash on launch.

## Stage 2 — App shell + screens
All 28 approved screens from the mockups, wired to bootstrap permissions
(a feature the admin turns off disappears from the app).

## Stage 3 — Voice (the core)
- SIP over WSS to the call engine, audio via WebRTC.
- Opus first for low data use on mobile networks; ulaw fallback for trunks.
- `coturn` (TURN over TLS 443) added by `setup.sh` so calls connect on
  carrier NAT and restrictive Wi-Fi.
- Reconnect + ICE restart on 4G↔Wi-Fi switch without dropping the call.

## Stage 4 — Push
- Android: high-priority FCM → full-screen incoming call.
- iOS: APNs VoIP (PushKit) → CallKit, wakes a closed app.
- Dialplan waits briefly for the app to register before ringing.

## Stage 5 — Device control (company shift phones)
- In-app camera: work photos upload to the dashboard, tagged with agent,
  time and customer. No gallery upload.
- Screen-pinning soft lock (no MDM) + MDM setup guide for the hard lock
  (kiosk, auto-wipe on logout) on managed company devices.

## Stage 6 — Control-panel server pages
PHP pages behind the control-panel mockups: app users & devices,
per-agent permissions, location map, work photos, activity log.

## What you provide
- Apple Developer account + a Mac for the iOS build (Stage 4).
- Google Play account + Firebase project (Stage 4).
- Decision on MDM for Stage 5 (free Android option is fine to start).
