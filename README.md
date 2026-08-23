# Airport-Noise-Speech-Enhancement

MATLAB implementation of a **two-stage speech enhancement system** designed to suppress airport noise in the **NOIZEUS speech corpus at 5 dB SNR**.

## Overview

The system first analyzes the noise using waveform, PSD, FFT, and spectrograms. Based on the spectral characteristics, a two-stage enhancement pipeline is implemented:

1. **256th-order FIR High-Pass Filter**

   * Cutoff: **100 Hz**
   * Linear-phase design
   * Removes low-frequency engine rumble

2. **Decision-Directed Wiener Post-Filter**

   * STFT-based processing
   * Adaptive frequency-domain noise suppression
   * Temporal gain smoothing to reduce musical noise

## Dataset

* **NOIZEUS Corpus**
* Sampling rate: **8 kHz**
* Airport noise
* Input SNR: **5 dB**
* 30 IEEE sentences

## Results

Across all 30 sentences:

| Metric               | Baseline |     Enhanced |
| -------------------- | -------: | -----------: |
| Mean SegSNR          | -1.50 dB |  **0.78 dB** |
| SegSNR Improvement   |        — | **+2.28 dB** |
| Approx. PESQ         |    2.635 |        2.633 |
| Mean Noise Reduction |        — |  **1.95 dB** |

All 30 sentences achieved a positive SegSNR improvement.

## MATLAB Pipeline

```text
NOIZEUS Audio
     ↓
Pre-processing
     ↓
Signal & Noise Analysis
(Waveform / PSD / FFT / Spectrogram)
     ↓
FIR High-Pass Filter
(100 Hz, Order 256)
     ↓
Decision-Directed Wiener Filter
     ↓
Enhanced Speech
     ↓
SegSNR / PESQ / MSE / Noise Reduction
```

## Scripts

* `loadaudios_1.m` — Load and prepare dataset
* `timeplot_2.m` — Time-domain analysis
* `spectogram_3.m` — Spectrogram analysis
* `PSD_4.m` — Power spectral density analysis
* `FFT_noise_5.m` — Noise frequency analysis
* `SNR_PESQ_6.m` — Baseline metrics
* `Filter_applied_7.m` — FIR + Wiener enhancement
* `listen_8.m` — Audio playback
* `save_all_figures_5.m` — Generate figures
* `Results_Table_9.m` — Export evaluation results

## Key Takeaway

The project demonstrates an **evidence-driven speech enhancement design**: spectral analysis is performed before filter selection, leading to a combination of fixed low-frequency suppression and adaptive in-band noise reduction.

### References

* Hu & Loizou, *Subjective comparison and evaluation of speech enhancement algorithms*, Speech Communication, 2007.
* Jaiswal et al., *Single-channel speech enhancement using implicit Wiener filter*, 2022.
* Upadhyay, *Psychoacoustic model-driven spectral subtraction for monaural speech enhancement*, 2023.
