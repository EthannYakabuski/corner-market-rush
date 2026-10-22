# Corner Market Rush: service catalog

`game/catalog.json` is the source of truth. Enter production IDs only as values of the same symbolic keys in `platform/config.json`; never rename the keys to backend IDs. All committed values are blank and PGS is disabled.

## Achievements

| Key | Name | Description / score | Icon |
| --- | --- | --- | --- |
| first_basket | A Warm Welcome | Check out your first complete basket. (served >= 1) | marketing/achievements/first_basket.png |
| shelf_keeper | Shelf Keeper | Finish 10 restocking jobs. (restocks >= 10) | marketing/achievements/shelf_keeper.png |
| perfect_shift | Not One Neighbor Missed | Complete a shift without losing a customer. (perfect_shifts >= 1) | marketing/achievements/perfect_shift.png |
| know_the_regulars | Our Kind of Corner | Serve all six neighborhood regulars. (regular_count >= 6) | marketing/achievements/know_the_regulars.png |
| maple_corner | Maple Neighbor | Complete the six Maple Corner shifts. (chapter_0 >= 6) | marketing/achievements/maple_corner.png |
| morning_bakery | The Morning Crowd | Complete the six Morning Bakery shifts. (chapter_1 >= 6) | marketing/achievements/morning_bakery.png |
| rainy_window | A Light in the Rain | Complete the six Rainy Window shifts. (chapter_2 >= 6) | marketing/achievements/rainy_window.png |
| market_square | Heart of the Square | Complete the six Market Square shifts. (chapter_3 >= 6) | marketing/achievements/market_square.png |
| tram_stop | Right on Time | Complete the six Tram Stop Express shifts. (chapter_4 >= 6) | marketing/achievements/tram_stop.png |
| lantern_night | Lantern Keeper | Complete the six Lantern Night shifts. (chapter_5 >= 6) | marketing/achievements/lantern_night.png |
| queue_composer | A Lovely Rhythm | Reach a five-customer service combo. (best_combo >= 5) | marketing/achievements/queue_composer.png |
| hundred_hellos | A Hundred Hellos | Serve 100 customers. (served >= 100) | marketing/achievements/hundred_hellos.png |
| neighborhood_anchor | Neighborhood Anchor | Serve 250 customers. (served >= 250) | marketing/achievements/neighborhood_anchor.png |
| fresh_every_day | Fresh Every Day | Finish 100 restocking jobs. (restocks >= 100) | marketing/achievements/fresh_every_day.png |
| market_manager | Market Manager | Reach manager level 5. (level >= 5) | marketing/achievements/market_manager.png |
| corner_legend | Corner Legend | Reach manager level 10. (level >= 10) | marketing/achievements/corner_legend.png |
| daily_regular | Same Time Tomorrow | Complete daily baskets on three different days. (daily_wins >= 3) | marketing/achievements/daily_regular.png |
| week_welcome | A Week of Welcomes | Collect all seven welcome-calendar rewards. (login_claims >= 7) | marketing/achievements/week_welcome.png |
| unassisted_rhythm | All in a Day's Care | Reach a 10-customer combo without earned assistance. (best_combo >= 10) | marketing/achievements/unassisted_rhythm.png |
| every_corner | Every Corner a Story | Complete all 36 campaign shifts. (completed_count >= 36) | marketing/achievements/every_corner.png |

## Leaderboards

| Key | Name | Description / score | Icon |
| --- | --- | --- | --- |
| served_customers | Neighborhood Welcomes | Total customers served across completed and settled shifts; higher is better. (served; higher is better) | marketing/leaderboards/served_customers.png |
| best_unassisted_combo | A Perfect Service Rhythm | Best customer combo in an unassisted shift; higher is better. (best_combo; higher is better) | marketing/leaderboards/best_unassisted_combo.png |
| manager_xp | Corner Market Managers | Total manager experience earned; higher is better. (xp; higher is better) | marketing/leaderboards/manager_xp.png |
