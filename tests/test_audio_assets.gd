extends SceneTree
const EXPECTED_TRACKS = ["menu.wav", "day.wav", "rush.wav", "evening.wav"]
var failures: int = 0
var checked: int = 0
func _initialize() -> void:
 call_deferred("run")
func verify(value: bool, label: String) -> void:
 checked += 1
 if not value:
  failures += 1
  push_error("Audio import contract: "+label)
func run() -> void:
 var tracks: int = 0
 for filename in EXPECTED_TRACKS:
  if not filename.ends_with(".wav"): continue
  var stream: AudioStream = load("res://assets/audio/music/"+filename)
  verify(stream is AudioStreamWAV, filename+" is imported WAV")
  if stream is AudioStreamWAV:
   tracks += 1
   verify(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,filename+" retains forward loop metadata")
   verify(stream.get_length() >= 40.0 and stream.get_length() <= 100.0,filename+" musical loop duration")
   verify(stream.loop_end > stream.loop_begin,filename+" nonempty loop")
   print("TRACK ",filename," seconds=",stream.get_length()," format=",stream.format," loop=",stream.loop_mode," rate=",stream.mix_rate)
  stream = null
 verify(tracks == EXPECTED_TRACKS.size(),"all expected menu/district music streams imported")
 print("AUDIO IMPORT CHECKS ",checked," failures=",failures,". Technical source/import evidence only; no auditory acceptance.")
 await process_frame
 quit(0 if failures == 0 else 1)
