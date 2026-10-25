# Round Four: service practice, counter standby and customer emotes

This scoped source update preserves the existing shop simulation, 36 authored
shifts, local banked progress, rewards, native callback handling and service IDs.
New exports, exact-commit CI and affected native checks are separate coordinator
gates. The earlier qualified APKs and screenshots retain their dated provenance.

## Seven additional improvements

Shop improvements now includes separate restock practice for Apples, Bread,
Milk, Cereal, Greens and Juice, plus a checkout improvement. Each has three
tiers, the existing `60 + 90 * current_rank` coin cost and atomic purchase/save
rollback. A tier gives 25% more interaction speed, so action time is
`base_interaction / (1 + 0.25 * rank)`; tier three uses 57.14% of the original
interaction time. Walking remains unchanged. Product-specific practice cannot
speed another product. Existing capacity, reserve and decoration remain.

Purchases apply when starting a new shift or practice. A restored active shift
retains its snapshotted service ranks and current task time. Legacy v1 profiles
and v2 active drafts add only optional zero ranks and false emote flags; banked
coins/XP, bought equipment, saved stock, customers, task timing and run identity
are preserved. Profile and snapshot validators reject invalid new values.

## Go to checkout before a basket arrives

The visible **Go to checkout** control accepts one normal clerk job even when
the counter is empty. It can be queued behind a restock. The clerk walks to the
counter, waits, then serves the first complete ready basket. An incomplete or
walking basket never pays. After that single checkout the job ends; this does
not install an automatic cashier for subsequent customers. Targeted customer
cards retain their existing behavior.

An empty-counter standby yields to a deliberately queued shelf job, preventing
a deadlock when shoppers need stock. A queued standby can be cancelled with the
existing queue control. Pause/background and restored-draft Resume freeze the
same authoritative model. Its counter target is at least48dp in the checked
phone/logical7-inch/logical10-inch source viewport profiles with all six SKUs.

## Model-backed emotes

An exclamation bubble appears above a shopper immediately after arriving at an
empty requested shelf. It clears when stock becomes available, while a separate
visit-history flag remembers that the shopper had to wait. A satisfied departure
shows a happy face if the visit never waited for stock and at least half of the
original patience remains at payment. Lost customers show a sad face. Emotes
follow real model phase/position, stay above the name, and disappear with the
departing actor. They add no bonus money and do not modify stock or payment.

The three unchanged PNGs are Kenney Emotes Pack, Vector Style1, under CC0.
Full original notice: `LICENSES/Assets/kenney_emotes-pack-LICENSE.txt`.
The manifest in `assets/ui/emotes/SOURCE.json` records their exact pixel-file
hashes; display uses Sprite3D billboards, not edited/promotional screenshots.

## Source verification, 2026-10-24

Godot4.5.1 isolated headless import and all six source suites pass with strict
script/parse/assertion/resource/ObjectDB checking: 1552 model (including legal
baseline strategies for all36 authored shifts),62 profile,221 scene/lifecycle,
92 ad-loader lifetime,17 audio/import and269 new Round Four checks:2213 total.
The new checks cover per-product speed/caps, legacy profile/draft migration,
counter waiting/cancellation/once-only actual basket payment/queue release,
pause/save restoration, stockout history and actual scene emote textures.
The existing audio teardown drains its real mixer before the new scene fixture
exits. The scene fixture mutes only its process-local master bus while real audio
streams and mixer teardown remain active. This is not audible validation. No
error suppression or weakened strict-log gate is used.

All storage is throwaway process-scoped test data with `-- --qa-isolated`.
No genuine profile, gameplay reward or reserved Taxi state is used or changed.
These are source fixtures, not native SDK/gameplay evidence. New native visual
review should cover the counter button, growth list and above-head icons; only
materially changed views need new genuine captures. Physical/audible/offline/
interactive-Web/production-service acceptance and the previously documented
graphics/SDK qualifications remain open until explicitly verified.

## Focused music pause-state follow-up / qualified verification

Music remains enabled. The focused follow-up avoids redundant pause-state assignments while leaving the gameplay and service rules above intact. Its source is `22052c9907118c4658742d9499b91703b0ffc025`; its [exact hosted CI](https://github.com/EthannYakabuski/corner-market-rush/actions/runs/40146610886) passed. The actual accepted AAB/Web003 components and qualified test package are recorded in `../HANDOFF.txt`. Earlier named-source tests and frozen exports do not establish this follow-up's runtime acceptance.

Corrected Web runtime findings: Bounded isolated Chrome Web003 observations: Home, the tutorial and an ordinary shift opened. Checkout served Mina once; an apple restock used reserve stock to add three units, and stockout emotes were visible. The natural below-target result recorded one of four neighbors served, one restock and an 86-second shift, awarding 4 coins and 6 manager XP. Home retained the 4 coins in the same browser session. No createBuffer recurrence was recorded during the 333-second check. Full original audio and project playback configuration were retained.
Remaining browser and platform limits: This was a genuine below-target shift, not a win; observation/input latency limited shop management. The Pause click reached an already-finishing result, so in-shift Pause/Resume was not verified. Checkout while the counter was empty was also not tested. One startup index.pck request reported net::ERR_ABORTED before the first ready frame; the game subsequently loaded and reached the reported result. The abort remains in the evidence; no error-free browser claim is made. Headless tab changes kept both pages visible and focused; actual hidden/focus-loss and music pause/resume transitions remain unverified. These are bounded Chrome Web003 observations, not Android screenshots or native/device, audible-output, SDK/ad, production-service or release acceptance. No cold browser restart was tested.

Affected Android/native checks, real SDK callbacks and current-build Android screenshots remain unverified. Physical-device play, audible-output and production services are separate acceptance work. Preserve all old APK/capture provenance and full third-party notices.
