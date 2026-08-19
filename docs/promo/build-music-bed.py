from pathlib import Path
import wave
import numpy as np

sample_rate = 44100
duration = 36.5
t = np.arange(int(sample_rate * duration), dtype=np.float64) / sample_rate
signal = np.zeros_like(t)

for frequency, phase in [(110.0, 0.0), (164.81, 0.7), (220.0, 1.4), (329.63, 2.1)]:
    drift = 1 + 0.0025 * np.sin(2 * np.pi * 0.07 * t + phase)
    signal += 0.055 * np.sin(2 * np.pi * frequency * drift * t + phase)

signal *= 0.72 + 0.28 * np.sin(2 * np.pi * 0.035 * t) ** 2
for cue in [4.0, 9.6, 15.7, 23.4, 31.0]:
    local = t - cue
    mask = (local >= 0) & (local <= 0.9)
    signal[mask] += 0.12 * np.sin(2 * np.pi * 659.25 * local[mask]) * np.exp(-4.5 * local[mask])

fade = np.ones_like(t)
fade[t < 1.2] = t[t < 1.2] / 1.2
fade[t > duration - 2.0] = (duration - t[t > duration - 2.0]) / 2.0
signal *= np.clip(fade, 0, 1)
pcm = np.int16(np.clip(signal, -0.95, 0.95) * 32767)
output = Path(__file__).resolve().parent / "music-bed.wav"
with wave.open(str(output), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)
    wav.writeframes(pcm.tobytes())
print(f"Created {output}")
