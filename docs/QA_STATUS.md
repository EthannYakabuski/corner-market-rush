# Android acceptance status

Status on 2026-10-23: source implementation and test-configured builds are
available, but native core-loop acceptance and final delivery remain unfinished.

## Build and source checks

[Exact gameplay-source CI passed](https://github.com/EthannYakabuski/corner-market-rush/actions/runs/39872243207)
for `25f1ab5a711ec7b19e3b132e71f5069d907c8710`: 1,552 model checks, 62 progression/save
checks, 176 UI/lifecycle checks, 17 audio checks, service contracts, Android/Web
exports and notices. The Android export included a scan-thread warning. All
strict resource/error checks remain enabled.

Verified CI debug APK:
`build/first-pass-ci-25f1ab5a-run39872243207/android/game-debug.apk`.
SHA256: `20FE1A17921AF274D64B3F7991991883280136FEC4B4600FE12FAE74F0254683`.
The Web entry is the sibling `web/index.html`. These artifacts are distinct from
any future build of the SDK-loader cleanup now in source.

## Genuine device state and environment blocker

The first genuine shift remains paused at 13.14 seconds with zero coins, XP,
served customers, restocks or revenue. Its genuine main and backup profiles were
restored byte for byte before first launch when the debug signer changed. This
is restoration across replacement, not proof of same-build cold retention.

The new Home was visually reviewed on Android. The task guest framework then
repeatedly displayed System UI not-responding dialogs, including after one
ordinary Wait. A transient missing-package-service error was reconciled before
replacement: the old APK/profiles were unchanged; the guest recovered its
services without a reboot, and normal app-specific replacement succeeded.

The app correctly requests portrait; the guest compositor had rotated
independently. A temporary normal display lock restored portrait, but System UI
became unresponsive again. No checkout, restock or reward was claimed. Market
was safely stopped, genuine data backed up, and original display/rotation
settings restored. This is an environment blocker; it does not establish an
application defect or a passed native core loop.

## Loader cleanup and screenshots

The source ports Room's verified pending-load lifetime adapter after matching the
bundled SDK ownership contract. The 92-check isolated lifetime suite, service
smoke and affected 176-check UI/lifecycle suite passed with strict diagnostics.
No vendor, audio, gameplay, save format or service-ID changes are included.
Native pending-load exit, replacement artifacts and exact new-commit CI remain
required; source fixtures are not real SDK callback proof.

One unaltered portrait Home capture is accepted at the manifest's original
CI25/APK provenance. Required coverage remains six genuine views per phone,
seven-inch and ten-inch logical profile: Home/storefront, actual shop, distinct
demand/layout, campaign, growth/journal and genuine result. Illustrations do not
count as gameplay captures.

Resume from the genuine paused shift after the task guest is healthy. Complete
real checkout and restocking, verify actual once-only payout/XP through result
close and cold launch, then finish the native lifecycle/ad checks and captures.
Do not replay uncertain inputs or alter saves to manufacture progression.

Physical-device behavior, audible balance/looping, interactive Web play,
production services and an actual disconnected-device session remain unverified.
The emulator has no audio output. Min API 24/target API 35 are tested engine
export constraints, not a current Play release-eligibility assertion. Production
IDs, signing, consent/privacy declarations and Google Play publication remain
owner work. Final packages and handoff are not yet issued.
