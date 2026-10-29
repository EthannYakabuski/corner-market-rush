# Round Five — assortment, pressure and courier collection

The campaign retains 36 stable IDs, titles and six neighbourhoods. Level 1 offers exactly apples and milk; level 2 adds bread; cereal appears at 4, greens at 6 and juice at 8. Arrivals progress from the 12-second tutorial cadence to 7.78 seconds in level 2 and 4.8 seconds late in the campaign. Later shelves start with one item rather than two; baskets combine goods earlier. Four shoppers can be in the shop; the existing bounded queue protects navigable space.

## Ordinary courier

When any available product's reserve is empty, **Call for delivery** is enabled. This is free and uses no ad or backend. The specified wait is 20–45 active-play seconds, frozen by the existing pause/background/fullscreen-ad gates. Calling again while in transit/waiting is rejected. Arrival only reveals an existing licensed Kenney character and cardboard parcel at the real front entry. **Meet courier at door** queues a normal cancellable clerk job: the clerk walks there and completes the interaction before eight reserve units per available product enter the stock ledger. The normal camera hides the entry behind action cards. While the courier waits, a small live inset shows that same actual character and parcel without moving the shop camera or hiding service targets. Only the active clerk collection briefly focuses the doorway, returning after handoff. Shelf and checkout cards stay available; the inset renders only while a courier is present. The player still restocks shelves and checks out each completed basket. A collected parcel cannot be claimed again. Timers, call/collection counts and the travelling clerk job survive snapshots.

Shifts 8, 12, 16, 20, 24, 28, 32 and 36 have 18 baskets each requiring one featured staple. They start with one staple on its shelf and two in reserve. Even the maximum reserve upgrade (+6) and one earned ad crate (+3) supply only 12; shelf-capacity upgrades do not create stock. All 18 baskets are required, so a courier is necessary irrespective of controller skill. All shifts are simulated unassisted at baseline and maximum upgrades with ordinary call/meet/restock/checkout inputs. The optional one-time ad crate retains its previous once-only, assisted-record semantics.

## Existing saves

The exact pre-Round-Five catalogue is retained in `game/shifts_legacy_v2.json`. Version 2 snapshots resolve only against that catalogue; their run ID, stock, orders, task, customer progress, earned state and payment flags remain intact. Version 3 snapshots carry `round_five` or `legacy_v2`; subsequent reloads keep the same ruleset. Finished old runs bank using their original result; the next new run uses current rules. No real player save is changed by source fixtures. Unknown rulesets and malformed courier state are rejected.

## Acceptance and limits

- Focused source fixtures cover all 36 new shifts at baseline and maximum upgrades, stock conservation, necessary delivery demand, no-delivery losses, call/wait/physical collection, timer pause/reload, duplicate rejection, queued/active collection background/fullscreen freeze with explicit Resume, all 36 legacy active-run migrations/completions, and durable once-only settlement/reload of finished old-v2 results.
- Existing profile/UI/ad-lifetime/audio/service tests remain required; payments, assisted scores and platform IDs are preserved.
- Scene fixtures inspect actual UI and licensed courier visibility across phone/tablet viewport sizes. They are synthetic, process-muted and are not real gameplay screenshots or auditory validation.
- Fresh interactive visual/export review is coordinated separately. Android rendering, real device controls/audio, signed-in Play Games and real AdMob earn remain unverified unless separately recorded. Historical exports and captures retain their original provenance.

Source-test and CI evidence is in `ROUND_FIVE_VALIDATION.json`; do not claim a pending gate has passed.
