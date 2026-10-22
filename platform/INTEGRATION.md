# Services integration contract

`Services` is a Node autoload after `GodotPlayGameServices`. It reads `res://platform/config.json`, and persists only its own pending PGS work to `user://platform_pending_v1.json`. Gameplay owns its profile, active round and request tokens.

| API | Gameplay responsibility |
| --- | --- |
| `set_menu_visible(bool)` | True on menus/results, false in active play. |
| `menu_bottom_reserve(reference: CanvasItem = null)` | Fit menu content above this measured native-banner/safe-area reserve. Pass the stable unscaled root, never a child that is being resized/scaled. Listen for `menu_bottom_reserve_changed`. |
| `round_finished()` | Call once after a genuine completed round is banked, never on page opens, retries, abandon or reload. The adapter may present an every-second-round interstitial. |
| `can_reward()` | Read availability; provide a free unavailable/decline path. |
| `reward_requested(context: String, callback: Callable)` | Callback receives a bool. Mark the request pending and freeze before calling. Validate the current round/request token; grant the intended benefit at most once only on true. |
| `fullscreen_ad_active()` | Keep simulation and gameplay input suspended while true. Reward-earned can occur before endcard dismissal. |
| `unlock(symbolic_key)` | Queue a legitimate earned achievement using an actual catalog key. |
| `submit(symbolic_key, score: int)` | Queue higher-is-better integer boards. The adapter retains the maximum pending score per key. Apply assisted-score exclusions before submission. |
| `status()` | Human-readable current service status. |
| `sign_in()`, `open_achievements()`, `open_leaderboards(key = "")`, `privacy_options()` | Optional service/menu actions; keep local play available when services are missing. |

Signals: `availability_changed`, `service_notice(message: String)`, and `menu_bottom_reserve_changed`.

Use one game-owned pause predicate covering explicit pause, tutorial, app background, reward pending, fullscreen ads and a post-ad Resume gate. Set pending before asking for the ad; do not unfreeze merely because true arrives. After dismissal leave a visible Resume choice. Cancel/obsolete round tokens prevent late callbacks from changing a replacement round. The adapter has once-only callback settlement but cannot decide which game round owns a reward. Native consent/privacy options must stay reachable.

Web/editor and missing-SDK fallback never simulate ad-earned rewards. `platform/tests/services_smoke.gd` checks measured menu geometry, unavailable fallback and synthetic duplicate/late callback settlement in an isolated test profile. Direct callback tests are source checks, not proof of a real SDK ad, consent, sign-in or native lifecycle. Record those separately through genuine native QA. Do not weaken strict log/leak gates to make a test pass.
