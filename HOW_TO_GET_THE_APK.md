# How to get the Android APK (no computer tools needed)

You only need a free GitHub account and a web browser.

## 1. Make a GitHub account
Go to https://github.com and sign up (free).

## 2. Create a repository
- Click the **+** (top right) → **New repository**.
- Name it `callcenterpro-app`. Leave it Public or Private.
- Click **Create repository**.

## 3. Upload the project
- On the new repo page, click **uploading an existing file**.
- Unzip `callcenterpro-app-stage1.zip` on your computer/phone first.
- Drag **the contents** of the `callcenterpro-app` folder into the browser
  (the `.github`, `flutter_app`, `server` folders and the `.md` files).
  Important: upload what is *inside* `callcenterpro-app`, so that `.github`
  and `flutter_app` sit at the top of the repo.
- Click **Commit changes**.

## 4. Let it build
- Open the **Actions** tab.
- You'll see **Build Android APK** running. Wait ~5–10 minutes for the green tick.
- If it's not running, click **Build Android APK** → **Run workflow**.

## 5. Download the APK
- Click the finished run → scroll to **Artifacts** → download **callcenterpro-apk**.
- It downloads a zip; unzip it to get **app-release.apk**.

## 6. Install on an Android phone
- Put `app-release.apk` on the phone (email it to yourself, or USB).
- Tap it. Android will ask to **allow installing from this source** — allow it.
- The app installs. Open it and sign in with a company name + extension +
  password that exist in your `tenant_extensions`.

## What this first build does
Sign in, see the app take your company's brand colour, and move around every
tab (Home, Calls, Keypad, Team, More). It does **not** place live calls yet —
that's the next build stage.

## Windows / iPhone
- **Windows**: the **Build Windows app** workflow produces a zip under Artifacts;
  unzip and run `callcenterpro.exe`.
- **iPhone**: needs your Apple Developer account to sign; tell me when you have
  one and I'll finish the iOS workflow.
