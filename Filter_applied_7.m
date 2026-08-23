% PURPOSE:
%   Implements a speech enhancement algorithm using a Wiener filter
%   with decision-directed SNR estimation and adaptive noise tracking.
%   Enhances noisy speech signals and computes performance metrics.

% INPUTS:
%   - data struct (from loadaudios_1.m and SNR_PSEQ_6.m):
%       data(i).noisy            : noisy speech signal
%       data(i).clean            : clean reference signal
%       data(i).Fs               : sampling frequency
%       data(i).segSNR_baseline  : baseline Segmental SNR (optional)

% OUTPUTS:
%   - data(i).enhanced           : enhanced speech signal
%   - data(i).segSNR_enhanced    : Segmental SNR after enhancement (dB)
%   - data(i).mse                : Mean Squared Error (enhanced vs clean)
%   - data(i).noise_reduction    : noise reduction in dB

% METHOD OVERVIEW:
%   1. Applies a mild high-pass FIR filter (cutoff = 100 Hz)
%   2. Performs frame-based STFT processing (Hann window, overlap-add)
%   3. Estimates noise PSD from initial frames
%   4. Uses decision-directed approach for prior SNR estimation
%   5. Applies Wiener gain with temporal smoothing and adaptive flooring
%   6. Reconstructs enhanced signal via inverse FFT and overlap-add

% METRICS:
%   - Segmental SNR (SegSNR):
%       Computed using 25 ms frames and 10 ms overlap (standard)
%       with clipping to [-10, 35] dB to avoid outliers
%   - Mean Squared Error (MSE)
%   - Noise Reduction (dB)

% NOTES:
%   - Designed for robustness under low SNR conditions (e.g., 5 dB)
%   - Uses consistent SegSNR computation aligned with results_table.m
%   - Includes adaptive noise tracking and speech presence probability
%   - Avoids musical noise using gain flooring and smoothing
Fs = 8000;

order = 256;

% Mild HIGH-PASS filter (only removes low-frequency noise)
b = fir1(order, 100/(Fs/2), 'high');

figure;
freqz(b, 1, 1024, Fs);
title('High-pass Filter (Cutoff = 100 Hz)');

figure;
grpdelay(b, 1, 1024, Fs);
title('Group Delay');

fprintf('Filter designed — order: %d\n', order);
fprintf('\n========================================\n');
fprintf('Processing Speech Enhancement\n');
fprintf('========================================\n\n');

for i = 1:length(data)

    noisy = data(i).noisy;
    clean = data(i).clean;
    Fs    = data(i).Fs;

    % ---------- High-pass filter ----------
    noisy = filtfilt(b, 1, noisy);

    frameLen = 512;
    hop      = 128;
    win      = sqrt(hann(frameLen,'periodic'));

    nFrames = floor((length(noisy)-frameLen)/hop) + 1;

    % ---------- Noise Initialization ----------
    noise_psd = zeros(frameLen,1);
    
    for k = 1:15
    idx = (k-1)*hop + (1:frameLen);
    frame = noisy(idx).*win;
    noise_psd = noise_psd + abs(fft(frame)).^2;
    end
    noise_psd = noise_psd / 15;

    
    noise_psd = max(noise_psd, 1e-8);

    % ---------- CONTROL PARAMETERS ----------
    alpha  = 0.920;
    beta   = 0.780;
    xi_min = 0.01;
    enhanced_out = zeros(size(noisy));
    ola_norm     = zeros(size(noisy));

    G_prev = ones(frameLen,1)*0.6;

    % ================= MAIN ENHANCEMENT LOOP =================
    for k = 1:nFrames

        idx = (k-1)*hop + (1:frameLen);
        frame = noisy(idx).*win;

        Y = fft(frame);
        mag2 = abs(Y).^2;

        % Posterior SNR
        gamma = mag2 ./ (noise_psd + eps);
        xi_direct = max(gamma - 1, 0);

        % Prior SNR estimation (Decision-Directed approach)
        xi = beta*(G_prev.^2 .* gamma) + (1-beta)*xi_direct;
        xi = max(xi, xi_min);

        % Speech presence probability
        speech_prob = xi ./ (xi + 1.0);

        % Noise PSD update
        noise_psd = alpha*noise_psd + (1-alpha)*(mag2 .* (1 - speech_prob));
        noise_psd = max(noise_psd, 1e-8);

        % Wiener gain
        G = xi ./ (1 + xi);

        % Temporal smoothing
        G = 0.9*G + 0.1*G_prev;

        % Adaptive gain floor
        G_floor = 0.08 + 0.10 * (xi ./ (xi + 2));
        G = max(G, G_floor);
        
        % Gentle noise reduction in silent parts
       silent_mask = xi < 0.5;
       G(silent_mask) = G(silent_mask) * 0.60;

        % Reconstruction
        frame_out = real(ifft(G .* Y)) .* win;

        enhanced_out(idx) = enhanced_out(idx) + frame_out;
        ola_norm(idx) = ola_norm(idx) + win.^2;

        G_prev = G;

    end
    
    % ---------- Overlap-Add normalization ----------
    ola_norm(ola_norm < 1e-8) = 1;
    enhanced_out = enhanced_out ./ ola_norm;

    data(i).enhanced = enhanced_out;

    % ================= IMPROVED SEGSNR CALCULATION =================
    % Using the same improved method as in results_table.m
    
    Lmin = min(length(clean), length(enhanced_out));
    clean_t = clean(1:Lmin);
    enh_t = enhanced_out(1:Lmin);
    
    % Improved SegSNR parameters (25ms frames, 50% overlap)
    frameLen_seg = round(0.025 * Fs);  % 25ms frames (standard)
    frameShift = round(0.010 * Fs);     % 10ms shift (50% overlap)
    nFrames_seg = floor((Lmin - frameLen_seg) / frameShift) + 1;
    
    snrVals = zeros(nFrames_seg, 1);
    
    for k = 1:nFrames_seg
        idx = (k-1)*frameShift + (1:frameLen_seg);
        
        sig_segment = clean_t(idx);
        enh_segment = enh_t(idx);
        
        % Correct: Error = Enhanced - Clean (distortion)
        error_segment = enh_segment - sig_segment;
        
        signal_power = sum(sig_segment.^2) + eps;
        error_power = sum(error_segment.^2) + eps;
        
        frame_snr = 10 * log10(signal_power / error_power);
        
        % Clip extreme values
        frame_snr = max(min(frame_snr, 35), -10);
        snrVals(k) = frame_snr;
    end
    
    % Remove outliers and average
    snrVals(snrVals < -10 | snrVals > 35) = [];
    data(i).segSNR_enhanced = mean(snrVals);
    
    % MSE calculation
    data(i).mse = mean((clean_t - enh_t).^2);
    
    % Also compute noise reduction ratio
    noise_before = var(noisy - clean_t);
    noise_after = var(enh_t - clean_t);
    data(i).noise_reduction = 10 * log10(noise_before / (noise_after + eps));
    
    % Print progress with consistent formatting
    fprintf('%-12s | Baseline: %6.2f dB | Enhanced: %6.2f dB | Improvement: %+6.2f dB | NR: %5.2f dB\n', ...
        data(i).label, ...
        data(i).segSNR_baseline, ...
        data(i).segSNR_enhanced, ...
        data(i).segSNR_enhanced - data(i).segSNR_baseline, ...
        data(i).noise_reduction);

end

% ================= SUMMARY =================
fprintf('\n========================================\n');
fprintf('ENHANCEMENT SUMMARY\n');
fprintf('========================================\n');

avg_baseline = mean([data.segSNR_baseline]);
avg_enhanced = mean([data.segSNR_enhanced]);
avg_improvement = avg_enhanced - avg_baseline;
avg_noise_reduction = mean([data.noise_reduction]);

fprintf('Average Baseline SegSNR:  %.2f dB\n', avg_baseline);
fprintf('Average Enhanced SegSNR:  %.2f dB\n', avg_enhanced);
fprintf('Average Improvement:       %+.2f dB\n', avg_improvement);
fprintf('Average Noise Reduction:   %.2f dB\n', avg_noise_reduction);
fprintf('========================================\n\n');

fprintf('DONE.\n');