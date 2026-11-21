# Integration check — app vs your call center solution

You asked me to check the app against the complete solution. Here's how each
app feature maps to what your backend already does, what I reused, and what
each later stage still has to wire. Everything is tenant-scoped.

## Verified in your backend (from the code you provided)

- **Agent auth**: `/api/tenant/login` validates `tenant_extensions` (company
  resolved by slug/domain; password compared directly). The app reuses this
  logic in `/app/v1/login` and adds JWT + lockout. SIP user =
  `{company_slug}_{extension}_ws`. ✔ consistent.
- **Licensing**: `baw1_gate()` / `lib/license.php` gates the web agent login.
  The app now calls the same gate. ✔ app is under the licence.
- **CDR**: written server-side from the call engine's `h` hangup extension
  (not the browser), so app calls get CDRs the same way IP-phone calls do. ✔
- **Recordings**: gated at the answering agent's channel via the per-company
  rec hook; stored on the server. App playback just reads these. ✔
- **AMI**: api.php talks to the call engine manager (127.0.0.1:5038) for live
  status / origination. Transfer, monitor and presence reuse this. ✔
- **Existing agent API actions** already present in `api.php`: `presence`,
  `queue`, `calllog`, `cdr`, `disposition`, `callback`, `dropped`, `break`,
  `breakcodes`, `summary`, `agentrank`, `notice`, `ringstatus`, `transfer`,
  `scripts`, `extensions`, `recordings`, `useractivity`. The app calls these
  directly — no duplication. ✔
- **Add-ons** in `features_api.php`: `crm`, `phonebook`, `sms` (agent token
  from `agentTokenFor`). The app's client info, phonebook and SMS screens use
  these. ✔

## Feature → backend mapping

| App screen | Backend it uses | Status |
|---|---|---|
| Login | `/app/v1/login` → `tenant_extensions` + licence gate | built (Stage 1) |
| Status / breaks / DND | `presence`, `break`, `breakcodes` | endpoints exist; wire in Stage 2 |
| Keypad / calls | SIP/WSS to call engine + WebRTC | Stage 3 |
| Incoming + caller history | SIP INVITE + `calllog`/`crm` lookup | Stage 3 |
| In-call controls | WebRTC + AMI (hold/transfer) | Stage 3 |
| Transfer (blind/attended) | `transfer` + AMI | Stage 3 |
| Disposition + wrap-up | `disposition` (+ skip flag) | Stage 2 |
| Callbacks | `callback` | Stage 2 |
| Call history / missed / pending | `calllog`, `cdr`, `dropped` | Stage 2 |
| Recordings playback | `recordings` | Stage 2 |
| Queue (live) | `queue` + realtime hub | Stage 2/3 |
| Team + presence | `extensions`, `presence` + hub | Stage 2 |
| Chat | `workspace_api` / chat-files | Stage 2 |
| Scripts | `scripts` | Stage 2 |
| Client info / CRM forms | `features_api` `crm` | Stage 2 |
| SMS | `features_api` `sms` | Stage 2 |
| Phonebook (company) | `features_api` `phonebook` | Stage 2 |
| My summary / rank | `summary`, `agentrank` | Stage 2 |
| Notices | `notice` | Stage 2 |
| Ringtones | `ringtones` | Stage 2 |
| Theme (live) | `/app/v1` theme + `theme.update` hub event | built (Stage 1) |

## Gaps to close (so nothing is missed)

1. **Realtime hub** (Node) — not in your current tree. Needed for live
   presence/queue/call events and the instant `theme.update`. Build in Stage 3;
   until then the app polls the existing endpoints (as the web UI does now).
2. **TURN (coturn)** — add to `setup.sh` for calls on mobile data/NAT.
3. **Opus** — prefer Opus on the WebRTC extensions for mobile data.
4. **Push bridge** — dialplan should wait for app registration before ringing
   a mobile agent (Stage 4).
5. **Offline queue** — app stores disposition/notes/form if the network drops
   and syncs on reconnect, so reports stay complete.
6. **`app_theme.php` auth include** — point it at your `company/` admin guard.
7. **Timezone** — your API is fixed to Asia/Dhaka; fine for now, but note it in
   `app_tenant_settings` if you ever onboard another timezone.

## Conclusion

The app sits on top of your existing solution rather than duplicating it:
same credentials, same licence, same CDR/recording/AMI paths, same agent
endpoints. Stage 1 (auth, theming, device/permissions schema) is in and
licence-gated. Stages 2–6 wire the screens to the endpoints above.
