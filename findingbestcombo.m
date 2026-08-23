% PURPOSE:
%   Performs systematic parameter optimization for the speech enhancement
%   algorithm to maximize Segmental SNR (SegSNR) improvement.
%   Evaluates multiple parameter combinations and identifies the best configuration.

% INPUTS:
%   - data struct (preloaded):
%       data(i).clean              : clean speech signal
%       data(i).noisy              : noisy speech signal
%       data(i).Fs                 : sampling frequency
%       data(i).segSNR_baseline    : baseline SegSNR (dB)

% OUTPUTS:
%   - results struct array containing:
%       Fs, filter order, HP cutoff frequency
%       alpha, beta, xi_min (SNR parameters)
%       frameLen, hop size, gain smoothing factor
%       avg_improvement (mean SegSNR improvement across dataset)
%       individual_improvements (per-file improvements)
%   - results_sorted              : results sorted by best performance
%   - best                        : best parameter configuration
%   - optimization_results_2dB.mat: saved results file

% METHOD OVERVIEW:
%   1. Defines search space for key parameters:
%       - Sampling rate (Fs), filter order, HP cutoff
%       - Noise adaptation (alpha), SNR smoothing (beta)
%       - Minimum SNR (xi_min), frame size, hop ratio
%       - Gain smoothing factor
%   2. Iterates over all parameter combinations (grid search)
%   3. Applies speech enhancement pipeline for each configuration:
%       - High-pass filtering
%       - Frame-based STFT processing
%       - Noise PSD estimation and tracking
%       - Wiener filtering with adaptive gain control
%   4. Computes SegSNR for enhanced signals
%   5. Calculates improvement over baseline for each file
%   6. Averages results across dataset and ranks configurations

% METRICS:
%   - Segmental SNR (SegSNR) improvement (primary optimization criterion)

% NOTES:
%   - Computationally intensive due to exhaustive grid search
%   - Resampling applied when testing different sampling rates
%   - Handles invalid configurations and numerical stability (eps usage)
%   - Final output identifies optimal parameter set for best performance


% Load your data (assuming data is already loaded)
% load('your_data.mat');

% Parameter ranges to test
params = [];

% === Fs variations ===
fs_values = [8000, 16000];  % Different sampling rates

% === order variations ===
order_values = [32, 64, 128, 256];

% === alpha (noise adaptation speed) ===
alpha_values = [0.85, 0.87, 0.89, 0.91, 0.93, 0.95];

% === beta (xi smoothing) ===
beta_values = [0.70, 0.75, 0.80, 0.85, 0.90];

% === xi_min (minimum a priori SNR) ===
xi_min_values = [0.05, 0.10, 0.15, 0.20];

% === frameLen / hop ===
frameLen_values = [128, 256, 512];
hop_ratios = [0.25, 0.5];  % hop = frameLen * ratio

% === G smoothing factor ===
g_smooth_values = [0.85, 0.90, 0.95];  % from 0.9

% === Additional parameters ===
% High-pass cutoff
hp_cutoff_values = [50, 100, 150, 200];  % Hz

% Store results
results = [];

% Counter for tracking
total_tests = length(fs_values) * length(order_values) * ...
              length(alpha_values) * length(beta_values) * ...
              length(xi_min_values) * length(frameLen_values) * ...
              length(hop_ratios) * length(g_smooth_values) * ...
              length(hp_cutoff_values);
test_idx = 0;

fprintf('Total parameter combinations to test: %d\n', total_tests);
fprintf('This may take a while...\n\n');

for f = 1:length(fs_values)
    Fs_test = fs_values(f);
    
    for o = 1:length(order_values)
        order_test = order_values(o);
        
        for hp = 1:length(hp_cutoff_values)
            hp_cutoff = hp_cutoff_values(hp);
            
            for a = 1:length(alpha_values)
                alpha_test = alpha_values(a);
                
                for b = 1:length(beta_values)
                    beta_test = beta_values(b);
                    
                    for xm = 1:length(xi_min_values)
                        xi_min_test = xi_min_values(xm);
                        
                        for fl = 1:length(frameLen_values)
                            frameLen_test = frameLen_values(fl);
                            
                            for hr = 1:length(hop_ratios)
                                hop_test = round(frameLen_test * hop_ratios(hr));
                                
                                for gs = 1:length(g_smooth_values)
                                    g_smooth_test = g_smooth_values(gs);
                                    
                                    test_idx = test_idx + 1;
                                    
                                    if mod(test_idx, 100) == 0
                                        fprintf('Progress: %d/%d (%.1f%%)\n', ...
                                            test_idx, total_tests, 100*test_idx/total_tests);
                                    end
                                    
                                    % Skip invalid combos (hop must be at least 1)
                                    if hop_test < 1
                                        continue;
                                    end
                                    
                                    % Run the enhancement with these parameters
                                    data_test = data;  % Copy original data
                                    
                                    for i = 1:length(data_test)
                                        
                                        % Resample if needed
                                        if Fs_test ~= data_test(i).Fs
                                            if exist('resample', 'file')
                                                data_test(i).noisy = resample(data_test(i).noisy, Fs_test, data_test(i).Fs);
                                                data_test(i).clean = resample(data_test(i).clean, Fs_test, data_test(i).Fs);
                                                data_test(i).Fs = Fs_test;
                                            else
                                                % Skip resampling if not available
                                                data_test(i).enhanced_segsnr = -inf;
                                                continue;
                                            end
                                        end
                                        
                                        noisy = data_test(i).noisy;
                                        clean = data_test(i).clean;
                                        Fs = data_test(i).Fs;
                                        
                                        % High-pass filter
                                        b_hp = fir1(order_test, hp_cutoff/(Fs/2), 'high');
                                        noisy = filtfilt(b_hp, 1, noisy);
                                        
                                        % Windowing
                                        win = sqrt(hann(frameLen_test, 'periodic'));
                                        
                                        nFrames = floor((length(noisy)-frameLen_test)/hop_test) + 1;
                                        
                                        % Noise initialization (first 6 frames)
                                        noise_psd = zeros(frameLen_test, 1);
                                        for k = 1:min(6, nFrames)
                                            idx = (k-1)*hop_test + (1:frameLen_test);
                                            frame = noisy(idx) .* win;
                                            noise_psd = noise_psd + abs(fft(frame)).^2;
                                        end
                                        noise_psd = max(noise_psd / min(6, nFrames), 1e-8);
                                        
                                        % Main loop
                                        enhanced_out = zeros(size(noisy));
                                        ola_norm = zeros(size(noisy));
                                        G_prev = ones(frameLen_test, 1) * 0.6;
                                        
                                        for k = 1:nFrames
                                            idx = (k-1)*hop_test + (1:frameLen_test);
                                            frame = noisy(idx) .* win;
                                            
                                            Y = fft(frame);
                                            mag2 = abs(Y).^2;
                                            
                                            gamma = mag2 ./ (noise_psd + eps);
                                            xi_direct = max(gamma - 1, 0);
                                            
                                            xi = beta_test * (G_prev.^2 .* gamma) + ...
                                                 (1 - beta_test) * xi_direct;
                                            xi = max(xi, xi_min_test);
                                            
                                            % Speech probability
                                            speech_prob = xi ./ (xi + 1.0);
                                            
                                            % Noise update
                                            noise_psd = alpha_test * noise_psd + ...
                                                        (1 - alpha_test) * (mag2 .* (1 - speech_prob));
                                            noise_psd = max(noise_psd, 1e-8);
                                            
                                            % Wiener gain
                                            G = xi ./ (1 + xi);
                                            G = g_smooth_test * G + (1 - g_smooth_test) * G_prev;
                                            
                                            % Adaptive floor
                                            G_floor = 0.3 + 0.2 * (xi ./ (xi + 2));
                                            G = max(G, G_floor);
                                            
                                            % Silent part reduction
                                            silent_mask = xi < 0.3;
                                            G(silent_mask) = G(silent_mask) * 0.85;
                                            
                                            % Reconstruction
                                            frame_out = real(ifft(G .* Y)) .* win;
                                            enhanced_out(idx) = enhanced_out(idx) + frame_out;
                                            ola_norm(idx) = ola_norm(idx) + win.^2;
                                            
                                            G_prev = G;
                                        end
                                        
                                        ola_norm(ola_norm < 1e-8) = 1;
                                        enhanced_out = enhanced_out ./ ola_norm;
                                        
                                        % Calculate SegSNR
                                        Lmin = min(length(clean), length(enhanced_out));
                                        clean_t = clean(1:Lmin);
                                        enh_t = enhanced_out(1:Lmin);
                                        
                                        frame_seg = round(0.02 * Fs);
                                        nFrames_seg = floor(Lmin / frame_seg);
                                        
                                        segsnr_vals = zeros(nFrames_seg, 1);
                                        for seg = 1:nFrames_seg
                                            idx_seg = (seg-1)*frame_seg + (1:frame_seg);
                                            sig = clean_t(idx_seg);
                                            err = sig - enh_t(idx_seg);
                                            segsnr_vals(seg) = 10*log10(sum(sig.^2) / (sum(err.^2) + eps));
                                        end
                                        segsnr_vals(segsnr_vals < -10) = [];
                                        data_test(i).segSNR_enhanced = mean(segsnr_vals);
                                        
                                        % Improvement
                                        data_test(i).improvement = data_test(i).segSNR_enhanced - ...
                                                                   data_test(i).segSNR_baseline;
                                    end
                                    
                                    % Calculate average improvement across all recordings
                                    improvements = [data_test(:).improvement];
                                    avg_improvement = mean(improvements(isfinite(improvements)));
                                    
                                    % Store result
                                    result_entry = struct(...
                                        'Fs', Fs_test, ...
                                        'order', order_test, ...
                                        'hp_cutoff', hp_cutoff, ...
                                        'alpha', alpha_test, ...
                                        'beta', beta_test, ...
                                        'xi_min', xi_min_test, ...
                                        'frameLen', frameLen_test, ...
                                        'hop', hop_test, ...
                                        'g_smooth', g_smooth_test, ...
                                        'avg_improvement', avg_improvement, ...
                                        'individual_improvements', improvements);
                                    
                                    results = [results; result_entry];
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

% Sort by best average improvement
[~, sort_idx] = sort([results.avg_improvement], 'descend');
results_sorted = results(sort_idx);

% Display top 10 configurations
fprintf('\n========== TOP 10 CONFIGURATIONS ==========\n');
for i = 1:min(10, length(results_sorted))
    r = results_sorted(i);
    fprintf('\n%d. Avg Improvement: %.2f dB\n', i, r.avg_improvement);
    fprintf('   Fs=%d, order=%d, HP_cutoff=%dHz\n', r.Fs, r.order, r.hp_cutoff);
    fprintf('   alpha=%.3f, beta=%.3f, xi_min=%.3f\n', r.alpha, r.beta, r.xi_min);
    fprintf('   frameLen=%d, hop=%d, g_smooth=%.3f\n', r.frameLen, r.hop, r.g_smooth);
end

% Best configuration
best = results_sorted(1);
fprintf('\n========== BEST CONFIGURATION ==========\n');
fprintf('Parameters:\n');
fprintf('  Fs = %d Hz\n', best.Fs);
fprintf('  Filter order = %d\n', best.order);
fprintf('  HP cutoff = %d Hz\n', best.hp_cutoff);
fprintf('  alpha = %.3f\n', best.alpha);
fprintf('  beta = %.3f\n', best.beta);
fprintf('  xi_min = %.3f\n', best.xi_min);
fprintf('  frameLen = %d\n', best.frameLen);
fprintf('  hop = %d\n', best.hop);
fprintf('  g_smooth = %.3f\n', best.g_smooth);
fprintf('\nExpected average SNR improvement: %.2f dB\n', best.avg_improvement);

% Save results
save('optimization_results_2dB.mat', 'results_sorted', 'best');
fprintf('\nResults saved to optimization_results_2dB.mat\n');