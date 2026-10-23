# Corner Market Rush

A little shop. A lively rush. Run a welcoming neighborhood grocery, keep the shelves stocked, and help every complete basket reach the checkout.

The gameplay source and exact-source Android/Web CI build have passed their source gates. Genuine Android acceptance is unfinished: the guest System UI became unstable before the saved shift could be played. One real portrait Home view is reviewed. A focused SDK-loader cleanup has passed isolated regressions in source and still needs a replacement build/native exit check. See [acceptance status](docs/QA_STATUS.md). Final packages and `HANDOFF.txt` have not been issued.

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
- Selected Kenney CC0 shop, character, furniture, nature, street and UI assets; original music and matching licensed sound effects with separate persisted volume toggles.
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

The AdMob **manifest App ID in `project.godot` is separate from the JSON configuration**. `test_mode` wording does not turn production ad IDs into test requests. The owner must configure and verify production Google Play Games, advertising/consent, signing and Play Console details. The current Android min24/target35 settings are a tested engine/export constraint, **not a claim of current Play release eligibility**.

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

The current isolated engine checks pass **1,552 model checks**, including legal baseline strategies for all 36 shifts; **62 progression/save checks**; **176 scene/lifecycle checks**; and **17 audio checks**. The import and service smoke checks also pass without strict diagnostics. Keep the strict script/error/assertion log gate alongside exit codes. The scene test's service callbacks are explicitly synthetic fixtures, never evidence of a real SDK ad or native reward.

The revised Android Home is readable on the verified CI25 APK. Basket-count/footer and deferred page cleanup fixes have 176 source UI/lifecycle checks; their actual shop acceptance is still pending. The real saved shift remains paused at 13.14 seconds with no checkouts or rewards. The new SDK-loader ownership suite adds 92 local checks, automatically discovered by CI, without replacing native shutdown validation.

Still required for acceptance: genuine Android completion/restock/checkout and once-only payment across cold load; real pause/Back/save behavior; available real service flows; actual offline verification; reviewed Android/Web packages; and six genuine views each for phone, seven-inch and ten-inch profiles. Auditory listening, physical-device, interactive Web and production-service validation have not been established by these source checks. Illustrated marketing images are never gameplay screenshots.

## Licenses

Original project work is [Apache 2.0](LICENSE). Keep [NOTICE](NOTICE) and the complete [LICENSES](LICENSES) directory with source and distributions. Selected third-party models, textures, fonts, plugins and engine notices retain their own terms. The stock-visible fruit model is a documented split of original CC0 geometry; [the deterministic derivation](game/derive_fruit_asset.py) preserves the original model, geometry attributes and texture.
