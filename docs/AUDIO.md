# Audio continuation

All paths below are under `res://assets/audio/`. Music is original 16-bit mono PCM WAV; selected effects are unchanged Kenney CC0 Ogg Vorbis. Files, exact hashes, source-pack paths, durations and score events are in `AUDIO_MANIFEST.json` and `music/original_music_manifest.json`.

| Music file | Title | Length | BPM | Tonality |
|---|---|---:|---:|---|
| `menu.wav` | The Corner Everyone Knows | 48.00s | 80 | C major |
| `day.wav` | Open for the Neighborhood | 45.71s | 84 | C major |
| `rush.wav` | Baskets in Good Company | 45.71s | 84 | C major |
| `evening.wav` | Lanterns in the Shop Window | 49.23s | 78 | F major |

Use `menu.wav` on the storefront. The theme mapping in `game/catalog.json` selects `day.wav` for Maple Corner, Morning Bakery and Rainy Window; `rush.wav` for Market Square and Tram Stop Express; and `evening.wav` for Lantern Night. Play coin once per actual checkout, restock once when placing goods, door on a new visible customer entry, and sparse footsteps only during actual clerk movement. Avoid a footstep for every frame.

| Effect | Source | Length |
|---|---|---:|
| `sfx/click.ogg` | kenney_interface-sounds/Audio/click_003.ogg | 0.010s |
| `sfx/coin.ogg` | kenney_rpg-audio/Audio/handleCoins.ogg | 0.846s |
| `sfx/door.ogg` | kenney_rpg-audio/Audio/doorOpen_1.ogg | 0.919s |
| `sfx/footstep.ogg` | kenney_impact-sounds/Audio/footstep_concrete_000.ogg | 0.106s |
| `sfx/confirm.ogg` | kenney_interface-sounds/Audio/confirmation_002.ogg | 0.539s |
| `sfx/error.ogg` | kenney_interface-sounds/Audio/error_002.ogg | 0.165s |
| `sfx/restock.ogg` | kenney_rpg-audio/Audio/cloth1.ogg | 0.661s |

Each music file contains standard RIFF `smpl` metadata: forward loop from frame 0 through its final frame, infinite repeat. Godot 4.5 WAV importer **Detect From WAV** (default `edit/loop_mode=0`) should retain that loop. Keep trim and normalize off, and leave high-quality Quite OK Audio compression (`compress/mode=2`, the Godot 4.5 default). PCM source remains unchanged. Importer forward override is `edit/loop_mode=2`, begin 0, end -1 if metadata is not retained. Do not loop sound effects. The isolated Godot audio test verifies the imported AudioStreamWAV forward-loop state; audible playback remains a separate acceptance check. [Godot 4.5 WAV importer reference](https://docs.godotengine.org/en/4.5/classes/class_resourceimporterwav.html).

Integration uses separate `Music` and `Effects` buses with persisted independent On/Off settings. Player gains are fixed at -16 dB for music and -6 dB for effects; these settings are mute toggles, not adjustable volume controls. One background player changes streams only when the selected track changes, and four one-shot players serve effects. Background/full-screen-ad handling pauses playback, and teardown stops players and releases stream references. The source scores have RMS near -17.4 dBFS and at least 3 dB peak headroom; real-device listening is still needed to assess balance.

Technical checks completed: deterministic source composition; original layered melodic/harmonic/bass/percussion arrangements; 16-bar musical form; cyclic note releases and room taps; valid PCM headers; exact sample counts; forward-loop RIFF metadata; no clipped PCM samples; zero-centered waveforms; loop-boundary step below 0.006 of full scale; source/copy SHA256 equality; valid unchanged Ogg page lengths/durations; exact included CC0 license copies. Completed isolated Godot checks also verified the imported WAV streams, their forward-loop mode, nonempty loop bounds and expected duration. UI fixtures exercise background/full-screen-ad lifecycle and stream teardown; these checks do not establish audible looping, mute behavior or device balance. Human listening on real phones/tablets remains unverified. The task emulator has audio output disabled, so it cannot establish what the music sounds like on a device.

Original composition and synthesis source: `LICENSES/Audio/compose_original_music.py` (Python 3 + NumPy), Apache-2.0. It can reproduce both game scores with `--output <chosen-folder>` and uses no sampled music. Per-pack notices and original-music notice are in `LICENSES/Audio/`; preserve them with source and distributions. No reference-project audio, real service IDs or private test data is included.
