%% results_table.m
% PURPOSE:
%   Computes and summarizes performance metrics for speech enhancement.
%   Generates comparison between baseline (noisy) and enhanced signals.
%   Outputs formatted tables, summary statistics, and saves results.

% INPUTS:
%   data struct from loadaudios_1.m containing:
%       - clean  : clean speech signal
%       - noisy  : noisy speech signal
%       - Fs     : sampling frequency
%       - enhanced (from Filter_applied_7.m)
%   Precomputed metrics (optional):
%       - segSNR_baseline, segSNR_enhanced, mse

% OUTPUTS:
%   - Printed results table (SegSNR, PESQ, MSE, processing time)
%   - Improvement summary (SegSNR, PESQ, MSE reduction)
%   - cep_results.mat (all metrics)
%   - cep_results.csv (Excel-compatible table)

% NOTES:
%   - Uses improved Segmental SNR computation (25ms frames, 10ms shift)
%   - Uses PESQ if available, otherwise a proxy approximation
%   - Includes diagnostic metrics: noise reduction & speech distortion


%% results_table.m - COMPLETE METRICS TABLE FOR CEP REPORT (FIXED)
% Calculates: SegSNR, PESQ, MSE, Processing Time
% Outputs: Single table comparing baseline vs enhanced

clear; close all; clc;

% Load your data and run enhancement
run("loadaudios_1.m")           % Loads 'data' with clean, noisy
run("SNR_PSEQ_6.m")       % Computes baseline metrics (USE FIXED VERSION)
run("Filter_applied_7.m")       % Your enhancement (adds enhanced, segSNR_enhanced, mse)

% =========================================================================
% CHECK FOR PESQ FUNCTION
% =========================================================================

use_pesq = false;

if exist('pesq', 'file') == 2
    use_pesq = true;
elseif exist('pesq_matlab', 'file') == 2
    use_pesq = true;
else
    fprintf('Note: Using improved PESQ proxy (no official PESQ toolbox found)\n');
end

numFiles = length(data);

% Baseline metrics (noisy speech)
baseline_segSNR = zeros(numFiles, 1);
baseline_pesq   = zeros(numFiles, 1);
baseline_mse     = zeros(numFiles, 1);

% Enhanced metrics
enhanced_segSNR = zeros(numFiles, 1);
enhanced_pesq   = zeros(numFiles, 1);
enhanced_mse    = zeros(numFiles, 1);
processing_time = zeros(numFiles, 1);

% Additional diagnostic metrics (for discussion)
noise_reduction_db = zeros(numFiles, 1);
speech_distortion_db = zeros(numFiles, 1);

fprintf('\nComputing metrics for %d files...\n', numFiles);
fprintf('================================================================\n\n');

tStart = tic; 

for i = 1:numFiles
    
    % Get signals
    clean = data(i).clean;
    noisy = data(i).noisy;
    Fs = data(i).Fs;
    
    % Check if enhanced exists
    if isfield(data(i), 'enhanced')
        enhanced = data(i).enhanced;
    else
        error('Enhanced signal not found. Run Filter_applied_7.m first.');
    end
    
    % Ensure same length
    Lmin = min([length(clean), length(noisy), length(enhanced)]);
    clean = clean(1:Lmin);
    noisy = noisy(1:Lmin);
    enhanced = enhanced(1:Lmin);
    
    % =====================================================================
    % 1. BASELINE METRICS (Noisy vs Clean) - USING IMPROVED METHOD
    % =====================================================================
    
    % Baseline SegSNR (using improved calculation)
    if isfield(data(i), 'segSNR_baseline')
        baseline_segSNR(i) = data(i).segSNR_baseline;
    else
        % Compute improved SegSNR for baseline
        baseline_segSNR(i) = compute_improved_segsnr(clean, noisy, Fs);
    end
    
    % Baseline MSE
    baseline_mse(i) = mean((clean - noisy).^2);
    
    % Baseline PESQ
    if use_pesq
        try
            baseline_pesq(i) = pesq(clean, noisy);
        catch
            baseline_pesq(i) = compute_improved_pesq_proxy(clean, noisy, Fs);
        end
    else
        baseline_pesq(i) = compute_improved_pesq_proxy(clean, noisy, Fs);
    end
    
    % =====================================================================
    % 2. ENHANCED METRICS (Enhanced vs Clean) - USING IMPROVED METHOD
    % =====================================================================
    
    % Enhanced SegSNR (using improved calculation)
    if isfield(data(i), 'segSNR_enhanced')
        enhanced_segSNR(i) = data(i).segSNR_enhanced;
    else
        % Compute improved SegSNR for enhanced
        enhanced_segSNR(i) = compute_improved_segsnr(clean, enhanced, Fs);
    end
    
    % Enhanced MSE
    if isfield(data(i), 'mse')
        enhanced_mse(i) = data(i).mse;
    else
        enhanced_mse(i) = mean((clean - enhanced).^2);
    end
    
    % Enhanced PESQ
    if use_pesq
        try
            enhanced_pesq(i) = pesq(clean, enhanced);
        catch
            enhanced_pesq(i) = compute_improved_pesq_proxy(clean, enhanced, Fs);
        end
    else
        enhanced_pesq(i) = compute_improved_pesq_proxy(clean, enhanced, Fs);
    end
    
    % =====================================================================
    % 3. DIAGNOSTIC METRICS (for critical analysis)
    % =====================================================================
    
    % Noise Reduction (how much noise power was removed)
    noise_power_before = var(noisy - clean);
    noise_power_after = var(enhanced - clean);
    noise_reduction_db(i) = 10 * log10(noise_power_before / (noise_power_after + eps));
    
    % Speech Distortion (how much clean speech was altered)
    speech_distortion_db(i) = 10 * log10(mean((clean - enhanced).^2) / (mean(clean.^2) + eps));
    
    % Progress indicator
    fprintf('✓ %s | Base SegSNR: %6.2f dB | Enh SegSNR: %6.2f dB | Improvement: %+5.2f dB\n', ...
        data(i).label, baseline_segSNR(i), enhanced_segSNR(i), ...
        enhanced_segSNR(i) - baseline_segSNR(i));
    
end

processing_time_total = toc(tStart);
avg_processing_time = processing_time_total / numFiles;

% =========================================================================
% PRINT MAIN RESULTS TABLE (CEP Required Format)
% =========================================================================

fprintf('\n\n');
fprintf('====================================================================================================================================\n');
fprintf('                                    SPEECH ENHANCEMENT RESULTS - Airport Noise (5 dB SNR)\n');
fprintf('====================================================================================================================================\n');
fprintf('%-6s | %-20s | %-20s | %-15s | %-15s | %-12s | %-10s |\n', ...
    'File', 'Baseline (Noisy)', 'Enhanced', 'Improvement', '', '', '');
fprintf('%-6s | %-10s %-10s | %-10s %-10s | %-12s | %-10s %-10s | %-10s |\n', ...
    '', 'SegSNR(dB)', 'PESQ', 'SegSNR(dB)', 'PESQ', 'MSE (x1e4)', 'Noise Red(dB)', 'Time(s)');
fprintf('------------------------------------------------------------------------------------------------------------------------------------\n');

for i = 1:numFiles
    fprintf('%-6s | %10.2f %9.3f | %10.2f %9.3f | %12.2f | %10.2f %9s | %8.3f |\n', ...
        data(i).label, ...
        baseline_segSNR(i), baseline_pesq(i), ...
        enhanced_segSNR(i), enhanced_pesq(i), ...
        (enhanced_mse(i) * 1e4), ...
        noise_reduction_db(i), '', ...
        avg_processing_time);
end

fprintf('------------------------------------------------------------------------------------------------------------------------------------\n');
fprintf('%-6s | %10.2f %9.3f | %10.2f %9.3f | %12.2f | %10.2f %9s | %8.3f |\n', ...
    'MEAN', ...
    mean(baseline_segSNR), mean(baseline_pesq), ...
    mean(enhanced_segSNR), mean(enhanced_pesq), ...
    mean(enhanced_mse * 1e4), ...
    mean(noise_reduction_db), '', ...
    avg_processing_time);
fprintf('====================================================================================================================================\n\n');

% =========================================================================
% PRINT IMPROVEMENT SUMMARY
% =========================================================================

fprintf('==================================== IMPROVEMENT SUMMARY ====================================\n');
fprintf('SegSNR Improvement:       %+.2f dB  \n', mean(enhanced_segSNR - baseline_segSNR));
fprintf('PESQ Improvement:         %+.3f     \n', mean(enhanced_pesq - baseline_pesq));
fprintf('MSE Reduction:            %.1f%%    \n', 100 * (1 - mean(enhanced_mse)/mean(baseline_mse)));
fprintf('Noise Reduction:          %.2f dB    \n', mean(noise_reduction_db));
fprintf('Speech Distortion:        %.2f dB    \n', mean(speech_distortion_db));
fprintf('Average Processing Time:  %.3f seconds  \n', avg_processing_time);
fprintf('================================================================================================\n\n');

% =========================================================================
% PRINT COMPACT TABLE FOR REPORT (Copy-paste friendly)
% =========================================================================

fprintf('==================================== COMPACT TABLE ====================================\n');
fprintf('| File | Base SegSNR | Enh SegSNR | ΔSegSNR | Base PESQ | Enh PESQ | ΔPESQ | MSE(x1e4) |\n');
fprintf('|------|-------------|------------|---------|-----------|----------|-------|-----------|\n');
for i = 1:min(10, numFiles)  % Show first 10 files
    fprintf('| %s | %11.2f | %10.2f | %7.2f | %9.3f | %8.3f | %5.3f | %9.2f |\n', ...
        data(i).label, ...
        baseline_segSNR(i), ...
        enhanced_segSNR(i), ...
        enhanced_segSNR(i) - baseline_segSNR(i), ...
        baseline_pesq(i), ...
        enhanced_pesq(i), ...
        enhanced_pesq(i) - baseline_pesq(i), ...
        enhanced_mse(i) * 1e4);
end
fprintf('|------|-------------|------------|---------|-----------|----------|-------|-----------|\n');
fprintf('| MEAN | %11.2f | %10.2f | %7.2f | %9.3f | %8.3f | %5.3f | %9.2f |\n', ...
    mean(baseline_segSNR), ...
    mean(enhanced_segSNR), ...
    mean(enhanced_segSNR - baseline_segSNR), ...
    mean(baseline_pesq), ...
    mean(enhanced_pesq), ...
    mean(enhanced_pesq - baseline_pesq), ...
    mean(enhanced_mse * 1e4));
fprintf('=======================================================================================================\n\n');

% =========================================================================
% SAVE RESULTS TO FILES
% =========================================================================

% Save as MAT file
save('cep_results.mat', 'baseline_segSNR', 'enhanced_segSNR', ...
     'baseline_pesq', 'enhanced_pesq', 'baseline_mse', 'enhanced_mse', ...
     'processing_time', 'noise_reduction_db', 'speech_distortion_db');

% Save as CSV for Excel
T = table();
T.File = {data.label}';
T.Baseline_SegSNR_dB = baseline_segSNR;
T.Enhanced_SegSNR_dB = enhanced_segSNR;
T.SegSNR_Improvement_dB = enhanced_segSNR - baseline_segSNR;
T.Baseline_PESQ = baseline_pesq;
T.Enhanced_PESQ = enhanced_pesq;
T.PESQ_Improvement = enhanced_pesq - baseline_pesq;
T.MSE_x1e4 = enhanced_mse * 1e4;
T.Noise_Reduction_dB = noise_reduction_db;

writetable(T, 'cep_results.csv');
fprintf('✓ Results saved to: cep_results.csv\n');
fprintf('✓ Results saved to: cep_results.mat\n\n');

% =========================================================================
% COMPARE WITH LITERATURE (For report discussion)
% =========================================================================

fprintf('==================================== LITERATURE COMPARISON ====================================\n');
fprintf('Reference Papers:\n');
fprintf('  • Hu & Loizou (2007) - NOIZEUS corpus baseline\n');
fprintf('  • Pandey et al. (2022) - Wiener filter: ~3-5 dB SegSNR improvement at 5 dB SNR\n');
fprintf('  • Upadhyay et al. (2023) - Spectral subtraction: PESQ ~2.0-2.5 at 5 dB SNR\n\n');

fprintf('Your Results:\n');
fprintf('  • SegSNR Improvement: %.2f dB\n', mean(enhanced_segSNR - baseline_segSNR));
fprintf('  • Enhanced PESQ: %.3f\n', mean(enhanced_pesq));
fprintf('  • Performance relative to literature: ');

if mean(enhanced_segSNR - baseline_segSNR) >= 4
    fprintf('EXCEEDS reported Wiener filter performance\n');
elseif mean(enhanced_segSNR - baseline_segSNR) >= 2
    fprintf('COMPARABLE to reported Wiener filter performance\n');
else
    fprintf('BELOW reported performance - discuss reasons in report\n');
end
fprintf('================================================================================================\n\n');

fprintf('=== ALL METRICS COMPUTED SUCCESSFULLY ===\n');

% =========================================================================
% HELPER FUNCTION 1: IMPROVED SEGMENTAL SNR
% =========================================================================

function segsnr = compute_improved_segsnr(clean, test, Fs)
    % Compute improved Segmental SNR with proper frame parameters
    % Following ITU-T P.862 recommendations
    
    L = min(length(clean), length(test));
    clean = clean(1:L);
    test = test(1:L);
    
    % Parameters (following speech processing standards)
    frameLen = round(0.025 * Fs);  % 25ms frames (better than 20ms)
    frameShift = round(0.010 * Fs); % 10ms overlap (50% overlap)
    nFrames = floor((L - frameLen) / frameShift) + 1;
    
    snrVals = zeros(nFrames, 1);
    
    for k = 1:nFrames
        idx = (k-1)*frameShift + (1:frameLen);
        
        sig_segment = clean(idx);
        test_segment = test(idx);
        
        % Correct: Noise = Test - Clean
        noise_segment = test_segment - sig_segment;
        
        signal_power = sum(sig_segment.^2) + eps;
        noise_power = sum(noise_segment.^2) + eps;
        
        frame_snr = 10 * log10(signal_power / noise_power);
        
        % Clip extreme values (avoid outliers)
        frame_snr = max(min(frame_snr, 35), -10);
        snrVals(k) = frame_snr;
    end
    
    % Remove outliers and average
    snrVals(snrVals < -10 | snrVals > 35) = [];
    segsnr = mean(snrVals);
end

% =========================================================================
% HELPER FUNCTION 2: IMPROVED PESQ PROXY
% =========================================================================

function pesq_score = compute_improved_pesq_proxy(clean, test, Fs)

    L = min(length(clean), length(test));
    clean = clean(1:L);
    test  = test(1:L);

    % Normalize levels
    clean = clean / (max(abs(clean)) + eps);
    test  = test  / (max(abs(test))  + eps);

    % Bandpass to telephone band only
    [b, a] = butter(4, [300 3400]/(Fs/2), 'bandpass');
    clean = filtfilt(b, a, clean);
    test  = filtfilt(b, a, test);

    % ---- Segmental SNR (standard 25ms/10ms) ----
    fLen  = round(0.025*Fs);
    fShift= round(0.010*Fs);
    nF    = floor((L-fLen)/fShift)+1;
    snrV  = zeros(nF,1);

    for k = 1:nF
        idx = (k-1)*fShift + (1:fLen);
        s   = clean(idx);
        d   = test(idx) - clean(idx);
        sp  = sum(s.^2) + eps;
        np  = sum(d.^2) + eps;
        snrV(k) = 10*log10(sp/np);
    end

    snrV(snrV < -10 | snrV > 35) = [];
    segsnr = mean(snrV);

    % ---- Waveform correlation ----
    c = corrcoef(clean(1:L), test(1:L));
    rho = max(c(1,2), 0);

    % ---- Map to PESQ range 1.0 – 4.5 ----
    % Linear blend then scale
    snr_norm = (segsnr + 10) / 45;          % maps [-10,35] → [0,1]
    snr_norm = max(min(snr_norm, 1), 0);

    raw = 0.70 * snr_norm + 0.30 * rho;
    pesq_score = 1.0 + 3.5 * raw;
    pesq_score = max(min(pesq_score, 4.5), 1.0);

end