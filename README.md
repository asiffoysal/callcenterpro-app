# CallCenter Pro — agent app (Stage 1)

Multi-tenant mobile agent app for your call center platform, plus the
server pieces it needs. This delivery is Stage 1: the foundation and the
per-tenant live theming. See `BUILD_PLAN.md` for the rest.

## Install the server side

1. Load the schema into the same database your admin dashboard uses:
   ```
   mysql your_db < server/app_schema.sql
   ```
2. Copy `server/app_api.php` and `server/app_jwt.php` next to your existing
   `api/` files. Edit the DB_* constants at the top of `app_api.php` to match
   your config (same values as `api/api.php`).
3. Route `/app/v1/*` to `app_api.php` (nginx/apache rewrite).
4. Copy `server/control-panel/app_theme.php` into the company admin
   dashboard and link it from the Mobile App page. Replace the
   `admin_auth.php` include with your dashboard's real admin-session guard
   (it must set `$TENANT_ID` and provide `getDb()`).
5. The realtime hub is Stage 3. Until it exists, the colour still applies at
   each sign-in; only the instant live update waits on the hub.

## Try the theming flow

- In the admin page, pick a colour and save.
- Sign in on the app with a company name + extension + password that exist in
  `tenant_extensions`. The app takes on that company's colour.
- Change the colour again in the admin page: open apps recolour live once the
  hub is running.

## Build the app

```
cd flutter_app
flutter pub get
flutter run            # Android/iOS device or emulator
flutter run -d windows # Windows desktop
```

Set `kServerBase` and `kHubUrl` in `lib/main.dart` to your server.

## Notes
- Agent credentials are the existing extension password; nothing new to manage.
- Personal phone contacts and the device gallery are never uploaded. Work
  photos are captured inside the app (Stage 5).

<!-- build check 2026-11-21T08:49:55Z -->
