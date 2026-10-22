"""Original game music composer/renderer. Apache-2.0, 2026 EthannYakabuski.

No samples, soundfonts or third-party musical material are used. All melodic
phrases below were written for Switchyard Lanterns and Corner Market Rush.
Requires Python 3 and NumPy. Output is deterministic 16-bit mono PCM WAV.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
import wave
import numpy as np

PITCHES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(note):
    if isinstance(note, int):
        return note
    letter, rest = note[0], note[1:]
    accidental = (1 if rest.startswith("#") else -1 if rest.startswith("b") else 0)
    octave = int(rest[1:] if accidental else rest)
    return (octave + 1) * 12 + PITCHES[letter] + accidental


def hz(note):
    return 440 * 2 ** ((midi(note) - 69) / 12)


def envelope(n, sr, attack, release, decay=0.0):
    t = np.arange(n, dtype=np.float64) / sr
    dur = n / sr
    out = np.minimum(1.0, t / max(attack, .001))
    out *= np.minimum(1.0, (dur - t) / max(release, .001))
    out *= np.exp(-decay * t)
    return out


def moving_average(noise, width):
    buf = np.concatenate(([0.0], np.cumsum(noise)))
    return (buf[width:] - buf[:-width]) / width


def tone(note, seconds, kind, sr, seed):
    n = max(2, int(seconds * sr))
    t = np.arange(n, dtype=np.float64) / sr
    f = hz(note)
    phase = 2 * np.pi * f * t
    rng = np.random.default_rng(seed)
    if kind == "plucked":
        a = np.zeros(n)
        # A warm string body with rapidly damping upper partials; two nearby
        # courses add a restrained, acoustic-like shimmer rather than a buzz.
        for h in range(1, 8):
            decay = np.exp(-t * (1.9 + .58 * h))
            a += (.7 / h ** 1.65) * decay * np.sin(phase * h)
            a += (.28 / h ** 1.8) * decay * np.sin(phase * h * 1.0014)
        a *= envelope(n, sr, .006, .13)
    elif kind == "keys":
        a = (np.sin(phase) * np.exp(-2.8 * t)
             + .31 * np.sin(2 * phase) * np.exp(-4.2 * t)
             + .13 * np.sin(3.003 * phase) * np.exp(-7 * t)
             + .055 * np.sin(6.01 * phase) * np.exp(-10 * t))
        a *= envelope(n, sr, .004, .18)
    elif kind == "mallet":
        a = (np.sin(phase) * np.exp(-2.6 * t)
             + .23 * np.sin(2.002 * phase) * np.exp(-5 * t)
             + .06 * np.sin(4.01 * phase) * np.exp(-7 * t))
        a *= envelope(n, sr, .003, .16)
    elif kind == "flute":
        vibrato = .018 * np.sin(2 * np.pi * 4.3 * t) * np.minimum(t / .45, 1)
        a = np.sin(phase + vibrato) + .12 * np.sin(2 * phase) + .028 * np.sin(3 * phase)
        breath = moving_average(rng.normal(0, 1, n + 5), 6)
        a += .023 * breath[:n]
        a *= envelope(n, sr, .055, .17)
    elif kind == "clarinet":
        vibrato = .014 * np.sin(2 * np.pi * 4.7 * t) * np.minimum(t / .4, 1)
        a = np.sin(phase + vibrato) + .20 * np.sin(3 * phase) + .055 * np.sin(5 * phase)
        a *= envelope(n, sr, .028, .16, .17)
    elif kind == "bow":
        a = (np.sin(phase + .024 * np.sin(2 * np.pi * 3.7 * t))
             + .33 * np.sin(2 * phase * .9991)
             + .105 * np.sin(3 * phase * 1.0009))
        a *= envelope(n, sr, .38, .55)
    elif kind == "bass":
        a = np.sin(phase) + .13 * np.sin(2 * phase) + .055 * np.sin(3 * phase)
        a *= envelope(n, sr, .012, .15, .9)
    elif kind == "whistle":
        a = (np.sin(phase + .018 * np.sin(2 * np.pi * 5 * t))
             + .24 * np.sin(phase * 1.259921) + .12 * np.sin(2 * phase))
        a *= envelope(n, sr, .085, .24)
    else:
        raise ValueError(kind)
    return a.astype(np.float32)


def percussion(kind, sr, seed):
    rng = np.random.default_rng(seed)
    n = int(sr * (.20 if kind == "brush" else .14))
    t = np.arange(n) / sr
    if kind == "brush":
        noise = rng.normal(0, 1, n + 4)
        smooth = moving_average(noise, 5)[:n]
        a = smooth * np.exp(-t * 31) * envelope(n, sr, .008, .05)
    elif kind == "wood":
        a = (np.sin(2 * np.pi * 620 * t) + .37 * np.sin(2 * np.pi * 1063 * t))
        a *= np.exp(-t * 55) * envelope(n, sr, .002, .04)
    else:
        phase = 2 * np.pi * (48 * t + 4 * (1 - np.exp(-20 * t)))
        a = np.sin(phase) * np.exp(-t * 32) * envelope(n, sr, .003, .04)
    return a.astype(np.float32)


def add_cyclic(buf, sound, start, gain):
    offset = int(round(start)) % len(buf)
    left = min(len(sound), len(buf) - offset)
    buf[offset:offset + left] += sound[:left] * gain
    if left < len(sound):
        buf[:len(sound) - left] += sound[left:] * gain


def write_loop_metadata(dest, frame_count, sample_rate):
    """Standard RIFF smpl forward-loop metadata (Godot Detect From WAV)."""
    raw=bytearray(dest.read_bytes())
    header=struct.pack('<9I',0,0,round(1_000_000_000/sample_rate),60,0,0,0,1,0)
    loop=struct.pack('<6I',0,0,0,frame_count-1,0,0)
    payload=header+loop
    raw.extend(b'smpl'+struct.pack('<I',len(payload))+payload)
    struct.pack_into('<I',raw,4,len(raw)-8)
    dest.write_bytes(raw)


CHORDS = {
    "D": ["D3", "F#3", "A3", "E4"], "G": ["G2", "B3", "D4", "A4"],
    "Bm": ["B2", "D3", "F#3", "A3"], "A": ["A2", "C#3", "E3", "B3"],
    "Em": ["E3", "G3", "B3", "D4"], "C": ["C3", "E3", "G3", "D4"],
    "Am": ["A2", "C3", "E3", "G3"], "F#m": ["F#2", "A3", "C#4", "E4"],
    "F": ["F2", "A3", "C4", "G4"], "Dm": ["D3", "F3", "A3", "C4"],
    "Bb": ["Bb2", "D3", "F3", "C4"], "Gm": ["G2", "Bb3", "D4", "F4"],
}

# Each bar is an original melodic phrase of (beat, pitch, duration-in-beats).
# Negative spaces are intentional. Four 4-bar phrases create a 16-bar arc.
RAIL_MELODY = [
    [(0,"F#4",.75),(1,"A4",.75),(2,"B4",.5),(3,"A4",.75)],
    [(0,"G4",1.4),(2,"E4",.75),(3,"D4",.6)],
    [(.5,"F#4",.6),(1.5,"D4",.6),(2.5,"B3",.6)],
    [(0,"E4",.75),(1,"F#4",.5),(2,"E4",1.5)],
    [(0,"A4",1.4),(2,"F#4",.65),(3,"E4",.6)],
    [(0,"D4",.75),(1,"G4",.75),(2.5,"B4",1.0)],
    [(0,"A4",.7),(1,"G4",.7),(2,"E4",.7),(3,"B3",.6)],
    [(0,"C#4",1.0),(1.5,"E4",.6),(2.5,"A4",1.2)],
    [(0,"B4",1.2),(1.5,"A4",.6),(2.5,"F#4",1.1)],
    [(0,"G4",.8),(1,"A4",.6),(2,"B4",.8),(3,"D5",.5)],
    [(0,"A4",.8),(1.5,"F#4",.7),(2.5,"E4",.7)],
    [(0,"C#4",.75),(1,"E4",.75),(2,"B4",.5),(3,"A4",.6)],
    [(0,"G4",1.1),(1.5,"B4",.5),(2.5,"A4",.9)],
    [(0,"F#4",.8),(1,"E4",.6),(2,"C#4",.6),(3,"E4",.6)],
    [(0,"F#4",1.2),(1.5,"A4",.6),(2.5,"D5",.75)],
    [(0,"A4",.8),(1.2,"F#4",.8),(2.5,"D4",1.1)],
]

MARKET_MELODY = [
    [(0,"E5",.5),(.75,"G5",.5),(1.5,"A5",.5),(2.5,"G5",.75)],
    [(.25,"F5",.5),(1,"E5",.5),(2,"D5",.75),(3,"C5",.6)],
    [(0,"E5",.75),(1.25,"G5",.5),(2,"E5",.5),(3,"C5",.6)],
    [(0,"D5",.75),(1.5,"B4",.5),(2.5,"G4",1.0)],
    [(0,"C5",.5),(.75,"E5",.5),(1.5,"G5",.65),(2.75,"A5",.75)],
    [(.25,"G5",.65),(1.5,"E5",.5),(2.5,"D5",.5),(3.25,"C5",.5)],
    [(0,"F5",.8),(1.25,"A5",.5),(2.25,"G5",.5),(3,"E5",.6)],
    [(0,"D5",.75),(1.5,"G5",.75),(2.75,"B5",.7)],
    [(0,"A5",.6),(1,"G5",.5),(1.75,"E5",.5),(2.75,"C5",.75)],
    [(.25,"F5",.75),(1.5,"E5",.5),(2.25,"D5",.5),(3,"C5",.65)],
    [(0,"E5",.5),(.75,"G5",.5),(1.5,"C6",.8),(3,"B5",.65)],
    [(0,"A5",.6),(1,"F5",.5),(2,"E5",.75),(3,"D5",.65)],
    [(0,"F5",.5),(.75,"A5",.5),(1.5,"G5",.7),(2.75,"E5",.8)],
    [(0,"D5",.6),(1,"B4",.5),(2,"D5",.6),(3,"G5",.6)],
    [(0,"E5",.7),(1.25,"G5",.5),(2.25,"C6",.6),(3,"G5",.5)],
    [(0,"E5",.8),(1.25,"D5",.65),(2.5,"C5",1.2)],
]

TRACKS = {
 "switchyard-lanterns": {
  "sample_rate":22050,
  "tracks":[
   dict(name="menu",title="A Lantern at the Junction",bpm=80,key="D major",chords="D G Bm A D G Em A Bm G D A G A D D",variant=0,mood="Warm chamber-folk introduction: plucked courses, woodwind and low bowed harmony."),
   dict(name="pine",title="Pine Junction",bpm=80,key="D major",chords="D G D A Bm G Em A D G Bm A G A D D",variant=1,mood="Open, lightly brushed plucks with a clear walking melody."),
   dict(name="orchard",title="Orchard Branch",bpm=80,key="G major",chords="G C G D Em C Am D G C Em D C D G G",variant=2,mood="Bright mallet answers and gentle string pulses."),
   dict(name="canal",title="Reflections on Canal Works",bpm=80,key="E minor",chords="Em C G D Em Am C D Em C G Bm Am D Em Em",variant=3,mood="Airy woodwind with sparse plucks, soft chord reflections and no driving drums."),
   dict(name="quarry",title="The Quarry Loop",bpm=80,key="A Dorian",chords="Am D G Em Am C D G Am D Em Bm C D Am Am",variant=4,mood="Low pizzicato, deliberate wooden rhythm and restrained melody."),
   dict(name="midnight",title="Midnight Crossing",bpm=80,key="B minor",chords="Bm G D A Em Bm G F#m Bm G Em A G F#m Bm Bm",variant=5,mood="Hushed, slower-feeling bowed harmony with widely spaced flute phrases."),
   dict(name="grand",title="Grand Dispatch",bpm=80,key="D major",chords="D G Bm A D Em G A Bm G D A G A D D",variant=6,mood="A fuller reprise with warm counterpoint and a quiet arrival cadence."),
  ]
 },
 "corner-market-rush": {
  "sample_rate":32000,
  "tracks":[
   dict(name="menu",title="The Corner Everyone Knows",bpm=80,key="C major",chords="C F Am G C F Dm G Am F C G F G C C",variant=0,mood="Welcoming soft keys, pizzicato-style bass, clarinet-like lead and brushed pulse."),
   dict(name="day",title="Open for the Neighborhood",bpm=84,key="C major",chords="C F C G Am F Dm G C F Am G F G C C",variant=1,mood="Cheerful day shift with short key phrases and a gently syncopated bass."),
   dict(name="rush",title="Baskets in Good Company",bpm=84,key="C major",chords="C Am F G C F Dm G Am F C G Dm G C C",variant=2,mood="More active mallets, rhythmic chords and quiet brush accents without alarm-like pressure."),
   dict(name="evening",title="Lanterns in the Shop Window",bpm=78,key="F major",chords="F Bb Dm C F Bb Gm C Dm Bb F C Bb C F F",variant=3,mood="Lower-register keys and warm sustained harmony for rainy and lantern shifts."),
  ]
 }
}


def snap_to_chord_scale(note, chord, shift=0):
    """Keep written motif contour while fitting each district's chord/colour."""
    n = midi(note) + shift
    # Non-chord passing notes use a common diatonic colour set for the current
    # harmony. Nearest pitch preserves melodic contour and avoids wrong thirds.
    root = midi(CHORDS[chord][0]) % 12
    minor = "m" in chord
    allowed = {(root + x) % 12 for x in ([0,2,3,5,7,9,10] if minor else [0,2,4,5,7,9,11])}
    return min(range(n-1,n+2),key=lambda p: (p%12 not in allowed,abs(p-n),p))


def render(game, spec, out):
    sr = TRACKS[game]["sample_rate"]
    beat = 60 / spec["bpm"]
    total = 64 * beat
    n = int(round(total * sr))
    mix = np.zeros(n,dtype=np.float32)
    rail = game.startswith("switchyard")
    variant = spec["variant"]
    chords = spec["chords"].split()
    melody = RAIL_MELODY if rail else MARKET_MELODY
    seed = 8675309 + variant * 101 + (0 if rail else 2000)
    events = []

    def place(bar, at, note, beats, kind, gain):
        nonlocal seed
        start = (bar * 4 + at) * beat
        dur = beats * beat
        sound = tone(note,dur,kind,sr,seed)
        add_cyclic(mix,sound,start*sr,gain)
        events.append(dict(bar=bar+1,beat=at,pitch=midi(note),duration_beats=beats,instrument=kind,gain=gain))
        seed += 1

    for b, chord in enumerate(chords):
        notes = [midi(x) for x in CHORDS[chord]]
        # One soft sustained harmony per bar; sparse voicing leaves space for
        # touch feedback and the melodic line. Release spills over cyclically.
        for nn in notes[1:]:
            place(b,0,nn,4.45,"bow",.030 if rail else .021)
        root = notes[0]
        place(b,0,root,1.6,"bass",.17 if rail else .20)
        fifth = root + 7
        place(b,2,fifth,1.35,"bass",.115 if rail else .14)
        if not rail and variant in [1,2]:
            place(b,3.25,root+12,.58,"bass",.075)

        # Broken chord motion differs by arrangement rather than only pitch.
        arps = [(.0,1),(.75,2),(1.5,3),(2.25,2),(3.0,1),(3.5,2)] if rail else [(.5,1),(1.5,2),(2.5,3),(3.5,2)]
        if rail and variant in [3,5]:
            arps = [(0.5,1),(1.5,2),(3,3)]
        for at, idx in arps:
            kind = "mallet" if (rail and variant==2) or (not rail and variant==2) else "plucked" if rail else "keys"
            place(b,at,notes[idx],1.35 if rail else .85,kind,.082 if rail else .092)
        if not rail:
            for at in ([0,1.75,3] if variant==2 else [0,2]):
                for nn in notes[1:3]:
                    place(b,at,nn+12,.65,"keys",.040 if variant!=3 else .026)

        for idx,(at,pitch,dur) in enumerate(melody[b]):
            if rail and variant==5 and idx%2:
                continue
            shift = 0
            if rail:
                shift = {0:0,1:0,2:5,3:2,4:-5,5:-3,6:0}[variant]
            elif variant==3:
                shift = -7
            nn = snap_to_chord_scale(pitch,chord,shift)
            if rail:
                lead = "flute" if variant in [0,1,3,5,6] else "plucked"
                gain = .092 if lead=="flute" else .125
            else:
                lead = "clarinet" if variant in [0,3] else "keys" if variant==1 else "mallet"
                gain = .082 if lead=="clarinet" else .125
            place(b,at,nn,dur,lead,gain)

        # Quiet counter-melody in the final phrase makes the 16-bar form evolve.
        if b>=8 and (not rail or variant in [0,2,6]):
            place(b,1,notes[2]+12,.7,"mallet" if not rail else "plucked",.045)
            place(b,3,notes[1]+12,.7,"mallet" if not rail else "plucked",.04)
        # No machine-gun clicks: small foot-tap/brush accents well below melody.
        percs = []
        if rail and variant not in [3,5]:
            percs = [(0,"kick",.035),(2,"wood",.022)]
            if variant in [1,4,6]:
                percs += [(1,"brush",.026),(3,"brush",.026)]
        elif not rail and variant!=3:
            percs = [(0,"kick",.045),(2,"wood",.027)]
            percs += [(x,"brush",.025 if variant!=2 else .040) for x in ([.5,1.5,2.5,3.5] if variant==2 else [1,3])]
        for at,kind,gain in percs:
            add_cyclic(mix,percussion(kind,sr,seed),(b*4+at)*beat*sr,gain)
            seed += 1

    # Circular room taps preserve a true continuous musical loop: tail from the
    # last bar is present at the beginning. There is no repeated fade-to-silence.
    dry = mix.copy()
    for delay,amount in [(0.071,.10),(0.137,.070),(0.229,.038)]:
        mix += np.roll(dry,int(delay*sr))*amount
    mix -= np.mean(mix)
    # Keep original dynamics and hard headroom. A track is attenuated only when
    # necessary; no peak-clipping limiter, sample saturation or loudness chase.
    peak=float(np.max(np.abs(mix)))
    scale=min(.70/peak,.135/(np.sqrt(np.mean(mix.astype(float)**2))+1e-12))
    mix*=scale
    pcm=np.round(mix*32767).astype('<i2')
    dest=out/(spec['name']+'.wav')
    with wave.open(str(dest),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
    write_loop_metadata(dest,len(pcm),sr)
    arr=pcm.astype(np.float64)/32768
    metrics=dict(file=dest.name,title=spec['title'],bpm=spec['bpm'],key=spec['key'],bars=16,
                 duration_seconds=len(pcm)/sr,sample_rate=sr,channels=1,bit_depth=16,
                 peak_dbfs=20*math.log10(max(np.max(np.abs(arr)),1e-12)),
                 rms_dbfs=20*math.log10(max(np.sqrt(np.mean(arr**2)),1e-12)),
                 dc_offset=float(np.mean(arr)),clipped_samples=int(np.count_nonzero(np.abs(pcm.astype(int))>=32767)),
                 loop_boundary_step=float(abs(arr[-1]-arr[0])),
                 largest_interior_step=float(np.max(np.abs(np.diff(arr)))),
                 sha256=hashlib.sha256(dest.read_bytes()).hexdigest().upper(),bytes=dest.stat().st_size,
                 mood=spec['mood'],loop_mode='forward',loop_begin_frame=0,loop_end_frame=len(pcm),
                 score=events)
    assert metrics['clipped_samples']==0
    assert metrics['loop_boundary_step'] < .06, metrics
    assert 45 <= metrics['duration_seconds'] <= 90
    return metrics


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    for game, config in TRACKS.items():
        out=args.output/game/'music';out.mkdir(parents=True,exist_ok=True)
        result=[]
        for spec in config['tracks']:
            m=render(game,spec,out);result.append(m)
            print(game,m['file'],m['duration_seconds'],m['peak_dbfs'],m['loop_boundary_step'],flush=True)
        (args.output/game/'original_music_manifest.json').write_text(json.dumps({
            'game':game,'license':'Apache-2.0','copyright':'2026 EthannYakabuski',
            'original_composition':True,'external_music_samples':False,
            'technical_validation_only':True,'auditory_device_validation':False,
            'rendering':'Deterministic additive synthesis, cyclic release tails and short circular room reflections.',
            'tracks':result},indent=2)+'\n',encoding='utf-8')
    # A short, soft original railway whistle: purposeful feedback, not a music
    # sample or a Kenney attribution. Kept separately identified in provenance.
    p=args.output/'switchyard-lanterns'/'sfx';p.mkdir(parents=True,exist_ok=True)
    sr=22050;a=tone('D5',1.15,'whistle',sr,830)
    a*=.48/max(float(np.max(np.abs(a))),1e-9)
    with wave.open(str(p/'whistle.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(np.round(a*32767).astype('<i2').tobytes())


if __name__=='__main__':
    main()
