# CallCenter Pro app — complete setup guide

Follow the parts in order. Part A is on your server (SSH). Part B gets the
installable app. Part C installs it. Part D configures it. Part E tests it.

If anything errors, copy the red/error text and send it to me.

---

## Part A — Server side (the app's backend)

You need SSH access to your call center server (the one at cc.aitoyes.com).

### A1. Put the app files with your platform code
From the zip, copy the server files into your baw1 project so `setup.sh`
deploys them like everything else:

- `server/app_api.php`      → `configs/web/api/app_api.php`
- `server/app_jwt.php`      → `configs/web/api/app_jwt.php`
- `server/app_schema.sql`   → `configs/web/api/app_schema.sql`
- `server/app_install.sh`   → project root (next to `setup.sh`)
- `server/control-panel/app_theme.php` → `configs/web/company/app_theme.php`

### A2. Hook the installer into setup.sh
Open `setup.sh`, find **STEP 9 (Deploying Web Files)**, and after that block
add one line:

```bash
bash "$SCRIPT_DIR/app_install.sh" "$WEB_ROOT"
```

(The installer needs `app_schema.sql`, `app_api.php`, `app_jwt.php` and the
`control-panel/` folder beside it — keep them together, or edit the paths at
the top of `app_install.sh`.)

### A3. Run it
On an already-running server you don't need a full reinstall — just run the
installer once:

```bash
sudo bash app_install.sh /var/www/html
```

Or run your normal `sudo bash setup.sh` and it happens automatically.

What it does: creates the app tables, deploys the API to `/var/www/html/api`,
adds the `/app/v1` route to `.htaccess`, and reloads the web server.

### A4. Point the theme page at your admin login
Open `/var/www/html/company/app_theme.php`. At the top, replace:

```php
require_once __DIR__ . "/lib/admin_auth.php"; // must provide $TENANT_ID + getDb()
```

with whatever your other `company/*.php` pages use to load the logged-in
company admin (it must set `$TENANT_ID` and give a `getDb()`). If you paste me
one of your existing `company/` pages, I'll give you the exact line.

### A5. Turn the app on for a company
By default the app is off per tenant. Enable it (replace `1` with the
tenant id):

```sql
INSERT INTO app_tenant_access (tenant_id, app_enabled, max_seats)
VALUES (1, 1, 50)
ON DUPLICATE KEY UPDATE app_enabled = 1, max_seats = 50;
```

### A6. Check it works
From any browser:
`https://cc.aitoyes.com/app/v1/login` with a POST should respond with JSON.
Easiest check: the app in Part C will tell you if the server is reachable.

---

## Part B — Build the installable app (GitHub, no tools needed)

See `HOW_TO_GET_THE_APK.md` for this with pictures-in-words. Short version:

1. Free account at https://github.com.
2. New repository → name `callcenterpro-app` → Create.
3. "uploading an existing file" → drag in everything **inside** the
   `callcenterpro-app` folder (so `.github` and `flutter_app` are at the top)
   → Commit.
4. **Actions** tab → "Build Android APK" runs → wait for the green tick.
5. Open the run → **Artifacts** → download `callcenterpro-apk` → unzip →
   `app-release.apk`.

Windows: the "Build Windows app" workflow gives a zip you unzip and run.
iPhone: needs your Apple Developer account — tell me when you have one.

---

## Part C — Install on a phone

1. Put `app-release.apk` on the Android phone (email/USB/download link).
2. Tap it → Android asks to allow installing from this source → allow.
3. Open the app.
4. Sign in: **company name** + **extension** + **password** (a real
   `tenant_extensions` row). The app sets up the connection to your server
   automatically.

Set the server address: in `flutter_app/lib/main.dart`, `kServerBase` and
`kHubUrl` must point to your server (`https://cc.aitoyes.com`). Change it in
GitHub before building if it's different.

---

## Part D — Configure from the control panel

In the company admin dashboard:

- **Mobile app → Theme**: pick your brand colour and save. Every agent's app
  recolours.
- **Mobile app → Agents**: turn app access on per agent, set devices per agent.
- **Permissions**: turn features on/off per agent (they appear/disappear in
  the app).
- **Device lock & work photos**: camera-only-in-app and screen-pin now; MDM
  toggles for managed company phones later.

---

## Part E — End-to-end test

1. Enable a test extension for the app (Part A5 + Part D).
2. Build & install (Parts B–C).
3. Sign in on the phone → you should see your brand colour and all tabs.
4. Change the colour in the control panel → the app recolours (live once the
   realtime hub is running, otherwise on next sign-in).
5. Calling is the next build stage; it won't place a live call yet.

---

## What's built vs coming

- **Now**: sign-in, licence check, per-tenant theming, permissions, the app
  shell (Home, Calls, Keypad, Team, More), control-panel theme page, auto
  install via `setup.sh`.
- **Next stages**: live calling (SIP/Opus/TURN), push + CallKit, device lock
  + work photos, the remaining control-panel pages. See `BUILD_PLAN.md`.
