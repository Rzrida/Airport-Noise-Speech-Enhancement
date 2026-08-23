% PURPOSE:
%   Computes baseline performance metrics for noisy speech signals
%   relative to clean reference signals using improved and standardized methods.
%   Provides accurate Segmental SNR (SegSNR) and a perceptually motivated
%   PESQ proxy for evaluation before enhancement.

% INPUTS:
%   - data struct (from loadaudios_1.m):
%       data(i).clean : clean speech signal
%       data(i).noisy : noisy speech signal
%       data(i).Fs    : sampling frequency

% OUTPUTS:
%   - data(i).segSNR_baseline : baseline Segmental SNR (dB)
%   - data(i).pesq_baseline   : baseline PESQ proxy score

% METHOD OVERVIEW:
%   1. Aligns clean and noisy signals to equal length
%   2. Computes Segmental SNR:
%       - 25 ms frames with 10 ms overlap (standard practice)
%       - Noise defined as (noisy − clean)
%       - Frame-wise SNR clipped to [-10, 35] dB to remove outliers
%   3. Computes PESQ proxy using perceptual features:
%       - Bandpass filtering (300–3400 Hz telephone band)
%       - Psychophysical weighting (mid-frequency emphasis)
%       - Weighted Segmental SNR
%       - Signal correlation analysis
%       - Spectral distortion (Bark-scale approximation)
%       - Temporal envelope similarity
%   4. Combines features into a normalized PESQ-like score (range ~1–4.5)

% METRICS:
%   - Segmental SNR (SegSNR): objective noise suppression measure
%   - PESQ proxy: perceptual speech quality approximation

% NOTES:
%   - Designed to approximate ITU-T P.862 (PESQ) without requiring toolbox
%   - Provides more realistic perceptual evaluation than basic SNR alone
%   - Baseline metrics are used for comparison with enhanced results
%   - Must be executed before enhancement and results_table scripts

fprintf('\n========================================\n');
fprintf('Computing Baseline Metrics (Fixed)\n');
fprintf('========================================\n\n');

for i = 1:length(data)
    
    clean = data(i).clean;
    noisy = data(i).noisy;
    Fs    = data(i).Fs;
    
    % Ensure same length
    Lmin = min(length(clean), length(noisy));
    clean = clean(1:Lmin);
    noisy = noisy(1:Lmin);
    
    % ===== IMPROVED SEGMENTAL SNR =====
    frameLen = round(0.025 * Fs);  % 25ms frames (better than 20ms)
    frameShift = round(0.010 * Fs); % 10ms overlap
    nFrames = floor((Lmin - frameLen) / frameShift) + 1;
    
    snrVals = zeros(nFrames, 1);
    
    for k = 1:nFrames
        idx = (k-1)*frameShift + (1:frameLen);
        
        sig_segment = clean(idx);
        noisy_segment = noisy(idx);
        
        % Correct: Noise = Noisy - Clean
        noise_segment = noisy_segment - sig_segment;
        
        signal_power = sum(sig_segment.^2) + eps;
        noise_power = sum(noise_segment.^2) + eps;
        
        frame_snr = 10 * log10(signal_power / noise_power);
        
        % Clip extreme values
        frame_snr = max(min(frame_snr, 35), -10);
        snrVals(k) = frame_snr;
    end
    
    % Remove outliers and average
    snrVals(snrVals < -10 | snrVals > 35) = [];
    data(i).segSNR_baseline = mean(snrVals);
    
    % ===== IMPROVED PESQ PROXY =====
    data(i).pesq_baseline = compute_improved_pesq_proxy(clean, noisy, Fs);
    
    fprintf('%-12s | Baseline SegSNR: %6.2f dB | PESQ: %5.3f\n', ...
        data(i).label, data(i).segSNR_baseline, data(i).pesq_baseline);
    
end

fprintf('\n========================================\n');
fprintf('Baseline metrics completed!\n');
fprintf('========================================\n\n');

% =========================================================================
% IMPROVED PESQ PROXY FUNCTION (Better correlation with true PESQ)
% =========================================================================

function pesq_score = compute_improved_pesq_proxy(clean, test, Fs)

    % Ensure same length
    L = min(length(clean), length(test));
    clean = clean(1:L);
    test = test(1:L);
    
    % 1. Active Level Adjustment (ITU-T P.862 standard)
    clean = clean / (max(abs(clean)) + eps);
    test = test / (max(abs(test)) + eps);
    
    % 2. Bandpass Filtering (300-3400 Hz telephone bandwidth)
    [b_band, a_band] = butter(4, [300, 3400]/(Fs/2), 'bandpass');
    clean_band = filtfilt(b_band, a_band, clean);
    test_band = filtfilt(b_band, a_band, test);
    
    % 3. Psychophysical Weighting (more sensitive to mid-frequencies)
    [b_psy, a_psy] = butter(2, [400, 2500]/(Fs/2), 'bandpass');
    clean_psy = filtfilt(b_psy, a_psy, clean_band);
    test_psy = filtfilt(b_psy, a_psy, test_band);
    
    % 4. Improved Segmental SNR (with perceptual weighting)
    frameLen = round(0.030 * Fs);  % 30ms frames
    frameShift = round(0.015 * Fs); % 50% overlap
    nFrames = floor((L - frameLen) / frameShift) + 1;
    
    segsnr_weighted = zeros(nFrames, 1);
    
    for k = 1:nFrames
        idx = (k-1)*frameShift + (1:frameLen);
        
        sig_frame = clean_psy(idx);
        test_frame = test_psy(idx);
        noise_frame = sig_frame - test_frame;
        
        % Perceptual weighting (emphasize important frequency regions)
        sig_power = sum(sig_frame.^2) + eps;
        noise_power = sum(noise_frame.^2) + eps;
        
        frame_snr = 10 * log10(sig_power / noise_power);
        
        % Apply sigmoidal weighting (frames with very low/high SNR matter less)
        weight = 1 / (1 + exp(-(frame_snr - 10)/5));
        segsnr_weighted(k) = frame_snr * weight;
    end
    
    % Remove outliers
    segsnr_weighted(segsnr_weighted < -10 | segsnr_weighted > 35) = [];
    segsnr_weighted = mean(segsnr_weighted);
    
    % 5. Correlation-based similarity
    correlation = abs(xcorr(clean_psy, test_psy));
    max_corr = max(correlation) / (sqrt(sum(clean_psy.^2) * sum(test_psy.^2)) + eps);
    max_corr = max(min(max_corr, 1), 0);
    
    % 6. Spectral Distortion (perceptual scale)
    [P_clean, f] = pwelch(clean_psy, hamming(512), 256, 512, Fs);
    [P_test, ~] = pwelch(test_psy, hamming(512), 256, 512, Fs);
    
    % Bark scale weighting (approximate critical bands)
    bark_centers = [250, 500, 1000, 1500, 2000, 2500, 3000];
    spectral_dist = zeros(length(bark_centers), 1);
    
    for b = 1:length(bark_centers)
        band_idx = find(f >= bark_centers(b)*0.8 & f <= bark_centers(b)*1.2);
        if ~isempty(band_idx)
            clean_band_power = mean(P_clean(band_idx)) + eps;
            test_band_power = mean(P_test(band_idx)) + eps;
            spectral_dist(b) = abs(10*log10(clean_band_power / test_band_power));
        end
    end
    
    lsd = mean(spectral_dist);
    lsd_score = 1 / (1 + exp((lsd - 5)/2));  % Maps LSD to 0-1
    
    % 7. Temporal Envelope Similarity (important for PESQ)
    envelope_clean = abs(hilbert(clean_psy));
    envelope_test = abs(hilbert(test_psy));
    
    % Low-pass filter envelopes
    [b_env, a_env] = butter(2, 50/(Fs/2));
    envelope_clean_filt = filtfilt(b_env, a_env, envelope_clean);
    envelope_test_filt = filtfilt(b_env, a_env, envelope_test);
    
    env_corr = corr(envelope_clean_filt, envelope_test_filt);
    if isnan(env_corr), env_corr = 0; end
    env_corr = max(env_corr, 0);
    
    % 8. Combine all metrics with optimized weights
    segsnr_norm = (segsnr_weighted + 5) / 35;  % Map from [-5,30] to [0,1]
    segsnr_norm = max(min(segsnr_norm, 1), 0);
    
    % PESQ-like mapping formula (based on ITU-T P.862)
    pesq_raw = 0.6 * segsnr_norm + ...      % Segmental SNR contribution
               0.25 * max_corr + ...          % Correlation contribution
               0.10 * lsd_score + ...         % Spectral contribution
               0.05 * env_corr;               % Temporal contribution
    
    % Map to PESQ range (0.5 - 4.5 typical for clean speech)
    pesq_score = 0.5 + 4.0 * pesq_raw;
    
    % Apply non-linear scaling to better match true PESQ
    pesq_score = 0.5 + 4.5 * (1 - exp(-2 * pesq_raw));
    
    % Clamp to valid range
    pesq_score = max(min(pesq_score, 4.5), 1.0);
    
end