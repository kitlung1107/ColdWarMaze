"""Generate original, deterministic 8-bit event sounds using only Python's stdlib."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
SCORES = {
    "chest": (0.85, [(72, 0, .13), (76, .10, .13), (79, .20, .15), (84, .34, .38)]),
    "door": (.55, [(43, 0, .12), (55, .09, .13), (62, .21, .22)]),
    "tower": (.95, [(81, 0, .12), (81, .22, .12), (88, .48, .30)]),
    "shortcut": (.70, [(55, 0, .11), (60, .08, .11), (64, .16, .11), (67, .24, .11), (72, .32, .23)]),
    "file": (.50, [(76, 0, .13), (81, .13, .25)]),
    "complete": (1.65, [(69, 0, .20), (72, .20, .20), (76, .40, .24), (81, .70, .66), (69, .70, .66)]),
    "wrong": (.48, [(57, 0, .17), (55, .18, .22)]),
    "purchase": (.48, [(83, 0, .07), (88, .09, .10), (95, .21, .18)]),
    "switch": (.20, []),
    "click": (.10, [(79, 0, .055)]),
    "exit_hint": (.62, [(64, 0, .20), (69, .23, .26)]),
    "footstep": (.10, [(34, 0, .07)]),
    "bump": (.18, [(39, 0, .12)]),
    "locked": (.28, [(49, 0, .07), (46, .09, .12)]),
    "investigate": (.48, [(64, .08, .13), (71, .21, .20)]),
    "select": (.12, [(79, 0, .075)]),
    "place": (.20, [(67, 0, .10), (74, .065, .10)]),
    "files_ready": (1.10, [(69, 0, .16), (72, .16, .16), (76, .32, .18), (83, .54, .42)]),
    "insufficient": (.44, [(52, 0, .14), (48, .18, .20)]),
    "incomplete": (.42, [(72, 0, .13), (69, .18, .17)]),
    "shop_open": (.65, [(43, 0, .10), (55, .10, .12), (64, .24, .25)]),
}


def render(duration, notes):
    samples = [0.0] * round(duration * RATE)
    for midi, start, length in notes:
        hz = 440 * 2 ** ((midi - 69) / 12)
        for j in range(round(length * RATE)):
            i = round(start * RATE) + j
            if i >= len(samples):
                break
            t = j / RATE
            phase = (hz * t) % 1
            pulse = .7 if phase < .25 else -.7
            triangle = 1 - 4 * abs(phase - .5)
            envelope = min(1, t / .008, (length - t) / .06) * math.exp(-t / length)
            samples[i] += (.30 * pulse + .70 * triangle) * envelope
    peak = max(abs(s) for s in samples) or 1
    return [s * .48 / peak for s in samples]


def write_wav(path, samples):
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", round(s * 32767)) for s in samples))


def render_door():
    """A latch click, a heavier mechanical clack, then a subtle hinge scrape."""
    rng = random.Random(1947)
    samples = [0.0] * round(.72 * RATE)
    for start, length, amp, pitch in [(0.025, .055, .75, 2100), (.115, .14, 1.0, 530)]:
        previous = 0.0
        for j in range(round(length * RATE)):
            t = j / RATE
            noise = rng.uniform(-1, 1)
            click = noise - previous * .75
            previous = noise
            body = math.sin(2 * math.pi * pitch * t) + .35 * math.sin(2 * math.pi * pitch * 1.73 * t)
            env = min(1, t / .0015) * math.exp(-t / (length / 5))
            samples[round(start * RATE) + j] += amp * (.65 * click + .35 * body) * env
    filtered = 0.0
    phase = 0.0
    for j in range(round(.32 * RATE)):
        t = j / RATE
        filtered = .82 * filtered + .18 * rng.uniform(-1, 1)
        phase += 2 * math.pi * (190 - 85 * t / .32) / RATE
        env = math.sin(math.pi * t / .32) ** 2
        scrape = filtered * .22 + math.sin(phase) * .026
        samples[round(.19 * RATE) + j] += scrape * env
    peak = max(abs(s) for s in samples)
    # Held samples and stepped amplitude give the mechanical sound a retro digital edge.
    result = []
    held = 0.0
    for i, sample in enumerate(samples):
        if i % 3 == 0:
            held = round(sample * .48 / peak * 127) / 127
        result.append(held)
    return result


def render_switch():
    rng = random.Random(1989)
    samples = [0.0] * round(.20 * RATE)
    for start, pitch in [(0, 1500), (.065, 2300)]:
        for j in range(round(.045 * RATE)):
            t = j / RATE
            phase = (t * pitch) % 1
            pulse = 1 if phase < .25 else -1
            env = min(1, t / .001) * math.exp(-t / .009)
            samples[round(start * RATE) + j] += (.65 * rng.uniform(-1, 1) + .35 * pulse) * env * .38
    return samples


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*", choices=list(SCORES))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    names = args.names or list(SCORES)
    for name in names:
        score = SCORES[name]
        samples = render_door() if name == "door" else render_switch() if name == "switch" else render(*score)
        write_wav(OUT / (name + ".wav"), samples)
    print("Generated", len(names), "original event sounds")
