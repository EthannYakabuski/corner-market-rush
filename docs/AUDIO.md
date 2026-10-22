# Audio continuation

All paths below are under `res://assets/audio/`. Music is original 16-bit mono PCM WAV; selected effects are unchanged Kenney CC0 Ogg Vorbis. Files, exact hashes, source-pack paths, durations and score events are in `AUDIO_MANIFEST.json` and `music/original_music_manifest.json`.

| Music file | Title | Length | BPM | Tonality |
|---|---|---:|---:|---|
| `menu.wav` | The Corner Everyone Knows | 48.00s | 80 | C major |
| `day.wav` | Open for the Neighborhood | 45.71s | 84 | C major |
| `rush.wav` | Baskets in Good Company | 45.71s | 84 | C major |
| `evening.wav` | Lanterns in the Shop Window | 49.23s | 78 | F major |

Use `menu.wav` on the storefront; `day.wav` for ordinary/day/bakery shifts; `rush.wav` for busy express/market-square shifts; `evening.wav` for rainy and lantern themes. Play coin once per actual checkout, restock once when placing goods, door on a new visible customer entry, and sparse footsteps only during actual clerk movement. Avoid a footstep for every frame.

| Effect | Source | Length |
|---|---|---:|
| `sfx/click.ogg` | kenney_interface-sounds/Audio/click_003.ogg | 0.010s |
| `sfx/coin.ogg` | kenney_rpg-audio/Audio/handleCoins.ogg | 0.846s |
| `sfx/door.ogg` | kenney_rpg-audio/Audio/doorOpen_1.ogg | 0.919s |
| `sfx/footstep.ogg` | kenney_impact-sounds/Audio/footstep_concrete_000.ogg | 0.106s |
| `sfx/confirm.ogg` | kenney_interface-sounds/Audio/confirmation_002.ogg | 0.539s |
| `sfx/error.ogg` | kenney_interface-sounds/Audio/error_002.ogg | 0.165s |
| `sfx/restock.ogg` | kenney_rpg-audio/Audio/cloth1.ogg | 0.661s |

Each music file contains standard RIFF `smpl` metadata: forward loop from frame 0 through its final frame, infinite repeat. Godot 4.5 WAV importer **Detect From WAV** (default `edit/loop_mode=0`) should retain that loop. Keep trim and normalize off, and leave high-quality Quite OK Audio compression (`compress/mode=2`, the Godot 4.5 default). PCM source remains unchanged. Importer forward override is `edit/loop_mode=2`, begin 0, end -1 if metadata is not retained. Do not loop sound effects. Verify actual imported AudioStreamWAV loop state in the engine before acceptance. [Godot 4.5 WAV importer reference](https://docs.godotengine.org/en/4.5/classes/class_resourceimporterwav.html).

Integration: use separate `Music` and `Effects` buses with persisted independent enable toggles and volume controls. Start music around -12 to -16 dB and effects around -6 to -12 dB, then tune on physical-device listening. The source scores have RMS near -17.4 dBFS and at least 3 dB peak headroom. Door/footstep/wood effects should be quieter (-14 to -22 dB); four simultaneous one-shot effects is an upper limit, with repeat debounce. Use one background player; only change stream when the selected track changes, crossfade modestly if supported, and never restart music on every UI redraw. Pause/duck on background and full-screen ads; resume safely without piling up delayed effects. Stop players and release stream references during teardown rather than leaving audio resources retained after tests.

Technical checks completed: deterministic source composition; original layered melodic/harmonic/bass/percussion arrangements; 16-bar musical form; cyclic note releases and room taps; valid PCM headers; exact sample counts; forward-loop RIFF metadata; no clipped PCM samples; zero-centered waveforms; loop-boundary step below 0.006 of full scale; source/copy SHA256 equality; valid unchanged Ogg page lengths/durations; exact included CC0 license copies. This is **not** auditory acceptance. Engine import, runtime stream looping/mute/lifecycle, real phone/tablet balance and human listening remain to be verified. The task emulator has audio output disabled, so it cannot establish what the music sounds like on a device.

Original composition and synthesis source: `LICENSES/Audio/compose_original_music.py` (Python 3 + NumPy), Apache-2.0. It can reproduce both game scores with `--output <chosen-folder>` and uses no sampled music. Per-pack notices and original-music notice are in `LICENSES/Audio/`; preserve them with source and distributions. No reference-project audio, real service IDs or private test data is included.
