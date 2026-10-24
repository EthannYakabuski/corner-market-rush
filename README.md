# Corner Market Rush

## Round 4 build continuation (2026-10-24)

The Android preset now defaults to **AAB** with Gradle, minimum API **24** and target API **35**. ARM64, x86 and x86_64 are selected; the [Round 4 Android guide](docs/ROUND_FOUR_ANDROID.md) explains the native ABI-pair validator and release-owner steps. These are current preset choices, not permanent engine restrictions.

Round 4 exact-source hosted CI and affected native acceptance are pending in this dated continuation snapshot; consult `HANDOFF.txt` for later source-bound results. An ABI-validated debug AAB is test-signed and does not establish Google Play acceptance. Dated APK hashes and screenshots below retain their original build provenance. This round does not start new games.

## Round Four source update

Seven product/checkout service improvements, an early **Go to checkout** standby job, and model-backed Kenney stockout/satisfied-departure emotes are implemented. [Current rules and2213 isolated source checks](docs/ROUND_FOUR.md) are separate from pending new export/native/CI gates. Earlier qualified binaries and screenshots below retain their original scope.

A little shop. A lively rush. Run a welcoming neighborhood grocery, keep the shelves stocked, and help every complete basket reach the checkout.

Final toast-card source `9934b51e` is public with passing exact-source
Android/Web CI: 215 UI, 92 lifetime, 1552 model, 62 profile, 17 audio and services. The affected
phone native card presentation passed after genuine signer-restoration; final
normal Save&Close, unchanged genuine state and display restoration are verified. Earlier
cfa core/payout/cold/earned-reserve checks and 18 accepted screenshots keep their
original provenance; 131f separately verified same-phone foreground/pause/Resume.
Whole-process logs retain distinct EGL, ad-header and emulator media diagnostics;
full native strict status is false. Local test package location:
`build/first-pass-qualified-20261023/packages/`. Its `LOCAL_PACKAGE_RECEIPT.json`
identifies verified archive hashes/source/runtime; if absent, packaging is
incomplete. See [acceptance status](docs/QA_STATUS.md).

## Play

Open `project.godot` with **Godot 4.5.1**, using the **Compatibility** renderer, and run the main scene at [scenes/main.tscn](scenes/main.tscn). Portrait Android is primary; Web is an additional export where feasible. No Windows distribution is planned.

- Customers walk to the shelves and collect the exact products shown on their basket cards. Stock visibly depletes from the same model that owns the basket quantities.
- Tap a shelf or its large product card to restock from reserve. Tap a customer's **Checkout** card after the complete basket reaches the counter. Incomplete baskets never pay.
- The clerk performs one job and can hold one additional queued job. Use **Cancel queued job** to change the waiting task. There is no joystick or automatic cashier.
- **Pause**, Android Back and background return stop shop time. **Save & Home** preserves the active customers, stock, clock and both task slots. Restored play waits for an explicit **Resume**.
- A completed or settled shift banks its real sales and XP once. Campaign completion requires the stated customer target; retries are free.

The first shift introduces apples and bread with four customers and generous patience. Later shifts introduce mixed baskets, different demand patterns and reserve deliveries. Untimed practice is available for each neighborhood's first shift, with no currency, XP or campaign unlocks.

## Included systems

- **36 authored shifts** across six themes: Maple Corner, Morning Bakery, Rainy Window, Market Square, Tram Stop Express and Lantern Night.
- Six regular customers, manager XP/levels with a modest coin welcome gift at each new level, capped shelf/reserve improvements and visible shop decorations. Level gifts share the once-only saved shift receipt.
- A daily basket, three daily goals and a seven-claim welcome calendar. Claims use UTC dates; missing a day does not erase the welcome calendar. Offline play does not invent idle earnings.
- **20 achievement definitions and three higher-is-better records**. The best-combo record excludes earned assistance. Exact names, descriptions, criteria and icon paths live in [game/catalog.json](game/catalog.json).
- Selected Kenney CC0 shop, character, furniture, nature, street and UI assets; original music and matching licensed sound effects with separate persisted Music/Effects On/Off settings.
- Local versioned saves, previous-good backup recovery and atomic, idempotent reward settlement. Private saves and test evidence must remain outside publication.

Google Play Games and AdMob adapters are included with disabled blank production mappings and Google test advertising IDs. Local play remains available without services. An optional earned reserve delivery grants assistance only from a valid earned callback; close, unavailable and obsolete callbacks grant nothing. Play stays frozen through the endcard and dismissal, then waits for Resume. Web never simulates an earned reward.

## Continue development

Read [AGENTS.md](AGENTS.md), [the design](docs/DESIGN.md) and the current handoff before changing behavior. A new task must use repository files as context rather than assuming access to prior conversations.

| Area | Source or guide |
| --- | --- |
| Authoritative movement, stock, baskets, tasks and payout | [game/market_model.gd](game/market_model.gd) |
| All authored shift manifests | [game/shifts.json](game/shifts.json) |
| Progression, daily calendar and atomic saves | [game/profile.gd](game/profile.gd) |
| Touch UI, pause and service lifecycle | [scripts/main.gd](scripts/main.gd) |
| Shop, real models and model-driven animation | [scripts/shop_world.gd](scripts/shop_world.gd) |
| Production service IDs, manifest App ID, signing and exports | [Platform setup](docs/PLATFORM_SETUP.md) |
| Achievement/record names, icons and backend key mappings | [Platform catalog](docs/PLATFORM_CATALOG.md) |
| Adapter API and ad lifecycle responsibilities | [Integration contract](platform/INTEGRATION.md) |
| Music, effects, licenses and validation limits | [Audio](docs/AUDIO.md) |
| Illustration provenance and asset treatment | [Art](docs/ART.md) |
| Data disclosures | [Privacy](docs/PRIVACY.md), [data safety](docs/DATA_SAFETY.md) |

The AdMob **manifest App ID in `project.godot` is separate from the JSON configuration**. `test_mode` does not turn production unit IDs into test requests. The owner must configure and verify production Google Play Games, advertising/consent, signing and Play Console details. The current Android min24/target35 settings are the current preset configuration, **not a claim of current Play release eligibility**.

## Validate

Use Godot 4.5.1 and import the project before running checks. Isolate **all** test storage: process-local `APPDATA` and `LOCALAPPDATA` on Windows, or `XDG_DATA_HOME` on Linux. Pass `-- --qa-isolated` to every test. Never run fixtures against a real owner or device profile.

```sh
# Example for a disposable Linux test session; godot is the 4.5.1 executable.
export XDG_DATA_HOME="$(mktemp -d)"
godot --headless --editor --path . --import --quit
godot --headless --path . --script platform/tests/services_smoke.gd -- --qa-isolated
godot --headless --path . --script tests/test_market_model.gd -- --qa-isolated
godot --headless --path . --script tests/test_profile.gd -- --qa-isolated
godot --headless --path . --script tests/test_ui.gd -- --qa-isolated
godot --headless --path . --script tests/test_ad_load_lifetime.gd -- --qa-isolated
```

The current 9934 exact-source CI passed **1,552 model checks**, including legal baseline strategies for all 36 shifts; **62 progression/save checks**; **215 scene/lifecycle checks**; and **17 audio checks**. The 92 lifetime checks, import and service smoke checks also passed strict source gates; known export/runner warnings remain recorded. Keep the strict script/error/assertion log gate alongside exit codes. The scene test's service callbacks are explicitly synthetic fixtures, never evidence of a real SDK ad or native reward.

The prior cfa APK has genuine native checkout/restock/completed-shift evidence and byte-identical settled-profile retention across result close and same-APK cold launch. The first Mina sale belonged to the genuine predecessor run; the remaining three customers and settlement completed on cfa. Actual background-modal and normal SDK cleanup checks passed. Actual native earned reserve and all 18 visual reviews passed on cfa; local package receipt/final docs/public CI and distinct EGL/SDK-media/surface-return qualifications are tracked in docs/QA_STATUS.md.

Still open: verification of the local package receipt and final reviewed docs/commit/public CI and retained EGL/SDK-media/surface-return qualifications. Actual offline verification, auditory listening, physical-device, interactive Web and production-service validation remain unverified. The 18 accepted logical-profile images are genuine raw Android captures, with practice explicitly labelled; illustrations are never gameplay screenshots.

## Licenses

Original project work is [Apache 2.0](LICENSE). Keep [NOTICE](NOTICE) and the complete [LICENSES](LICENSES) directory with source and distributions. Selected third-party models, textures, fonts, plugins and engine notices retain their own terms. The stock-visible fruit model is a documented split of original CC0 geometry; [the deterministic derivation](game/derive_fruit_asset.py) preserves the original model, geometry attributes and texture.
