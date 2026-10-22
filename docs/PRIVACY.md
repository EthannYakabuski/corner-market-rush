# Corner Market Rush: privacy policy draft

Status: **owner completion required before production publication**. This draft describes the current application/source configuration. It is not a claim that production services, a public policy URL or a completed Play Console disclosure exist.

Publisher/controller: **OWNER TO SUPPLY LEGAL NAME**
Privacy/support contact: **OWNER TO SUPPLY CONTACT ADDRESS**
Public policy URL: **OWNER TO SUPPLY AND HOST URL**
Effective date: **OWNER TO SET WHEN PUBLISHED**

## Local gameplay information

The game stores shift progress and active service state, run receipts, coins, XP, served/restock records, local achievements, daily/calendar dates and claims, music/effects preferences on your device. Its profile is `user://corner_market/profile.json`; a prior valid backup (`.bak`) and a temporary write (`.tmp`) may accompany it. Optional online achievement/score requests are saved separately as `user://platform_pending_v1.json`. Gameplay does not require signing in. This project does not provide developer-operated cloud saves, an account-creation form or a custom analytics endpoint.

On Android, clearing this app's storage or uninstalling it removes its local game files and loses local progress. This does not delete information held separately by Google. The export preset disables Android's app-data backup flag; verify the final merged manifest before release. A Web build uses browser-managed local storage, which can be removed by clearing that site's data; the eventual hosting provider and its access logging must be disclosed by the owner before hosting.

## Android advertising and privacy choices

The Android integration includes Google Mobile Ads through Poing AdMob and Google's User Messaging Platform (UMP). It can request consent information and present the configured privacy message before initializing ads. If consent information is unavailable or requires a decision, the current adapter keeps ads paused; local gameplay remains available. The in-game Android privacy-options action calls UMP to reopen the available choices. Availability depends on the owner's AdMob messages and the user's region; an unconfigured test app is not proof of a completed production consent flow.

The current source uses Google's sample App ID and banner/interstitial/rewarded units. Sample ads are development configuration, not a promise of zero SDK data processing. The SDK may process network/device identifiers, ad interactions and diagnostics under Google's terms. Review the matching SDK version's [Google data-disclosure information](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure) and [Google Privacy Policy](https://policies.google.com/privacy). The owner must update this policy for the final ad configuration and any additional mediation partners. `test_mode` text alone does not make a production unit a test request.

## Optional Google Play Games

Google Play Games integration is currently disabled, with blank production game/achievement/leaderboard IDs. If the owner configures and enables it, signing in allows this game to send earned achievement unlocks and higher-is-better scores to Google for this game. The adapter does not implement cloud saves or request the player's email address/friend list. Google handles the associated Play Games identity and service data under its policies. The visibility of online records depends on your Google Play Games settings. Google's [Play Games data-disclosure guide](https://developer.android.com/games/pgs/data-collection) explains its controls, including deleting game data through Play Games/Google account settings.

Deleting remote Google data does not automatically erase local game data or the local pending-submission queue. Once online services are enabled, retained local records can be submitted again; clear the app's local storage as well if you intend to remove its retained local records. Do not expect an ad privacy choice to delete a gameplay profile or a Play Games record.

## Owner release decisions still required

Supply the publisher/contact/date/public URL above; confirm target audience and age treatment; configure production privacy messages and the visible privacy-options entry point; inspect the actual resolved SDKs/manifest and any hosting logs; finalize data retention/deletion/support handling; update this policy to the shipped behavior and complete Play Console Data Safety. Current `tag_for_under_age_of_consent=false` is a configuration placeholder, not an audience declaration or compliance determination. See `docs/DATA_SAFETY.md` and `docs/PLATFORM_SETUP.md` for the technical inventory and owner setup steps.
