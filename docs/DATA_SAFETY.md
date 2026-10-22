# Corner Market Rush: technical data inventory and release worksheet

This is an engineering handoff, **not a completed Play Console form or legal-compliance certification**. Review it against the exact APK/dependency graph and the owner's final backend, audience, privacy-message and hosting choices. The current test configuration cannot substantiate production behavior.

| Component | Current source behavior | Owner verification before release |
| --- | --- | --- |
| Local game profile | `user://corner_market/profile.json`; shift progress and active service state, run receipts, coins, XP, served/restock records, local achievements, daily/calendar dates and claims, music/effects preferences; validated `.bak`/`.tmp` files may exist. | Confirm the final schema in `game/profile.gd`, save/recovery behavior and local deletion UX. Preserve genuine QA backups privately. |
| Pending online records | `platform/services.gd` keeps symbolic achievement unlocks and maximum pending integer scores in `user://platform_pending_v1.json`. | Explain that deleting remote data alone does not clear local records; retained pending work may be resubmitted after sign-in. |
| Play Games | Disabled by `platform/config.json`; blank maps and game ID; export sentinel game ID `0`. When configured, calls the Google wrapper for authentication, achievement unlocks and score submission. No cloud-save API, custom account system, email or friend-list request is implemented by this adapter. | Configure the correct numeric game ID in JSON and Android export option, package/signing fingerprints and testers. Inspect automatic SDK behavior as well as explicit API calls. Test real account controls and public-record visibility. |
| Advertising | Google demo App ID and three sample units; Android only; menu banner, optional earned reward and every-second-completed-round interstitial when available. | Keep sample units for development. `test_mode` is wording only. Configure test devices separately before testing real units. Inventory actual SDK/mediation data flows. |
| Consent/privacy | UMP update at Android adapter start; form when required/available; initialization waits for `OBTAINED` or `NOT_REQUIRED`; privacy-options method available. | Configure owner's AdMob messages/age treatment. Verify the actual visible privacy action, required/declined/unavailable/region flows and any cached-consent behavior. No production consent flow has yet been accepted by this document. |
| Network/permissions | Fresh preset explicitly enables Internet and network-state access; no location/contact/storage/camera/microphone permission is requested there. Vendored ads AAR additionally declares `android.permission.AD_ID`. SDK manifests can merge additional declarations. | Inspect the **final merged APK manifest**, including Advertising ID declarations; do not infer no data processing from unchecked location permissions or the test-mode label. |
| Debug diagnostics | Adapter can print ad event/context and menu-layout information in a debug build. No custom telemetry uploader is in this adapter. | Keep raw logs/captures/profile backups private. Recheck the full game source and final release logging/dependencies rather than treating this adapter inventory as an app-wide network audit. |
| Web fallback | Native ad-earned entitlement is never simulated; PGS/native ad APIs unavailable; game progress stays in browser storage. No hosting is enabled by the workflow. | Choose/disclose hosting provider and actual access logs/cookies; validate interactive Web behavior and storage independently. |

## SDK pins and matching disclosure sources

The vendored plugin source pins Poing AdMob **5.1.0**, requesting `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0` (GMA Next-Gen) and `androidx.constraintlayout:constraintlayout:2.2.0`. Its exporter forces `androidx.browser:browser:1.8.0`. Google Play Games plugin **3.4.0** requests `com.google.android.gms:play-services-games-v2:21.0.0` and `com.google.code.gson:gson:2.11.0`. These are source requests, **not a verified resolved release dependency report**; record resolved transitive versions, including UMP, during the Android build. No extra mediation adapters are selected in this foundation.

Google's current Next-Gen disclosure identifies advertising/analytics/fraud-prevention processing of network addresses, interactions, diagnostics and device/account identifiers. Verify its version applicability to the shipped SDK rather than copying a form answer. [GMA Next-Gen disclosure](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure).

Google's PGS disclosure covers identity, analytics/diagnostics and feature-dependent records such as achievements/scores, with Google account controls. [PGS disclosure](https://developer.android.com/games/pgs/data-collection).

Consult [UMP integration guidance](https://developers.google.com/admob/android/privacy) for configured messages/privacy choices and [Play Console Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) for the publisher's form. These links were checked on 2026-10-22; the publisher must recheck them for release. No SDK upgrade or host/security change was made to prepare this worksheet.

## Production checklist owned by publisher

1. Inspect exact source and resolved release APK/manifest; enumerate SDKs, permissions, telemetry, optional features and hosting.
2. Decide audience/age handling and configure valid privacy messages, test devices, production IDs and tester accounts. Keep secrets/signing material outside Git.
3. Supply the real publisher identity, contact, effective date and hosted privacy-policy URL in `docs/PRIVACY.md`; ensure in-app/store links point to the intended public policy.
4. Decide and document retention/deletion/request handling for local records, Google's records and any support messages. Do not promise remote deletion merely because local storage is cleared.
5. Test consent/privacy options, offline/missing-service play, native ad reward/cancel/close lifecycle, real PGS controls and browser-storage behavior on the intended builds.
6. Complete the Play Console form from those verified practices and final SDK guidance. Android min24/target35 here remains an engine/test export constraint, not current store eligibility. Publication and final declarations remain with the owner.
