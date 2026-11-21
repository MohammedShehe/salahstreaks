# Ummah Leaderboard – setup guide

The leaderboard is **fully serverless**: the app talks straight from the device to
Google's Firebase REST APIs (anonymous sign-in + Cloud Firestore). There is no
SalahStreaks backend, no Cloud Functions, and no native Firebase plugin or
`google-services.json` to install. Security comes from the Firestore rules in
[`firestore.rules`](../firestore.rules).

Until you connect a Firebase project the rest of the app works exactly as before
(the leaderboard screen just shows a "Connect" card).

## 1. Create the Firebase project (≈5 min, free Spark plan)

1. <https://console.firebase.google.com> → **Add project** (Analytics not needed).
2. **Build → Authentication → Get started → Sign-in method → Anonymous → Enable.**
3. **Build → Firestore Database → Create database** → any region → *Production mode*.
4. **Firestore → Rules** → paste the contents of `firestore.rules` → **Publish**.
   (CLI alternative: `firebase deploy --only firestore:rules` – `firebase.json` is included.)
5. **Project settings (⚙) → General**: copy the **Project ID**.
   Copy the **Web API Key** (shown there; if missing, click *Add app → Web* once).

No indexes are required – every query uses single-field indexes that Firestore creates automatically.

## 2. Connect the app

Pick one:

* **In the app (no rebuild):** Home → 🌍 icon → paste *Project ID* + *Web API key* → **Save & connect**.
* **At build time:**
  ```bash
  flutter build apk \
    --dart-define=LB_FIREBASE_PROJECT_ID=your-project-id \
    --dart-define=LB_FIREBASE_API_KEY=AIza...
  ```
  (An in-app value, if entered, takes priority over the build-time default.)

Both values are public identifiers, not secrets – the rules are what protect the data.

## 3. Recommended hardening (2 min)

* Google Cloud console → **APIs & Services → Credentials → your Web API key → API restrictions**:
  allow only *Identity Toolkit API*, *Token Service API*, *Cloud Firestore API*.
* **Billing → Budgets & alerts**: set a small budget so abuse can never surprise you.

## How it works

| Piece | Detail |
|---|---|
| Identity | Anonymous Firebase Auth uid per install (stored on device). No email/phone. |
| Opt-in | Nothing is uploaded until the user taps **Join** and accepts the consent. |
| Shared fields | Display name, emoji avatar index, lifetime / weekly / monthly points, current streak counts. **Never** logs, notes, amounts, location, or prayer times. |
| Scoring | Re-derived from the logs with per-day caps (max 750/day) – see *Scoring & privacy* in the app. Caps match the rules. |
| Layout | `profiles/{uid}` (global), `periods/w2026-47/entries/{uid}` (weekly), `periods/m2026-11/entries/{uid}` (monthly). One atomic `commit` per sync. |
| Weekly / monthly | Separate period documents → boards "reset" naturally with no cron job. Weeks are ISO (Monday start); months are calendar months, using the device's local date. |
| Discovery | Prefix search on display name; ⭐ follow adds a person to **Friends**, stored on the device. |
| Rankings | Top 50 per board, plus your exact rank via a server-side count if you're outside the top 50. |
| Offline | Boards are cached on disk and shown instantly / offline. Your upload is idempotent: the app compares a fingerprint of your latest snapshot with what the server last accepted and retries (30 s → 15 min back-off, on app resume, every 15 min) until it succeeds. Leaving while offline queues the deletion. |
| Leaving | **Profile → Leave** deletes your profile and weekly/monthly entries. |
| Existing data | The leaderboard only *reads* the app's data. SQLite / SharedPreferences data, backups, streaks and points are untouched. Its own settings use `lb_`-prefixed keys, which "Clear all data" intentionally keeps so a published profile can't be orphaned. |

## Known limits (honest notes)

* **No backend = client-trusted scores.** The rules enforce schema, ownership, server time, rate limit and score ceilings, so a tampered client is limited to what is humanly achievable in a day/week/month – but it can't prove points were earned. If you later need real anti-cheat, add a Cloud Function that recomputes scores; the data layout is ready for that.
* **Free-tier quota.** Spark allows ~50k reads and ~20k writes per day. Each sync is 3 writes; each board view ≈ 50 reads (cached 60 s). Roughly 500–1000 daily-active users fit; beyond that enable Blaze with a budget cap.
* **Reinstalling** creates a new anonymous identity (the old entry can't be deleted by the new install). Entries with no activity drop off the boards automatically (only points > 0 are listed).
* Names are user-chosen; there is no profanity filter or report flow in this version.
* Rules length limits count characters loosely (≤ 96 units) so Arabic/emoji names pass; the app itself limits to 24 characters.

## Troubleshooting

| Message in app | Fix |
|---|---|
| "The server rejected the request…" | Rules not published, or Firestore not created. |
| "Enable Anonymous sign-in…" | Authentication → Sign-in method → Anonymous. |
| "The Firebase API key looks invalid." | Re-copy the *Web API key*; check API restrictions include the three APIs above. |
| Always "Offline" | Check network / that the Project ID is right. |
