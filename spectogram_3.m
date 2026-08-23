% PURPOSE:
%   Generates and compares time–frequency representations (spectrograms)
%   of clean and noisy speech signals to visualize the effect of noise
%   on speech structure.

% INPUTS:
%   - data struct (must be preloaded):
%       data(i).clean : clean speech signal
%       data(i).noisy : noisy speech signal
%       data(i).Fs    : sampling frequency
%       data(i).label : file identifier/name

% OUTPUTS:
%   - Spectrogram comparison plots for each file (clean vs noisy)
%   - Saved figures:
%       spectrogram_<label>.fig  (MATLAB figure)
%       spectrogram_<label>.png  (image file)

% METHOD OVERVIEW:
%   1. Computes spectrograms using STFT:
%       - Window: Hamming (256 samples)
%       - Overlap: 128 samples (50%)
%       - FFT size: 512
%   2. Displays:
%       - Clean speech spectrogram
%       - Noisy speech spectrogram (airport noise, 5 dB SNR)
%   3. Uses frequency axis in Hz ('yaxis' option)
%   4. Saves each figure for further analysis/reporting

% NOTES:
%   - Spectrograms reveal time-varying frequency content of speech
%   - Useful for observing noise spread and masking of speech formants
%   - Figures generated in non-visible mode for batch processing


for i = 1:length(data)

    figure('Visible', 'off');

    subplot(2,1,1);
    spectrogram(data(i).clean, hamming(256), 128, 512, data(i).Fs, 'yaxis');
    title('Clean speech');
    colorbar off;

    subplot(2,1,2);
    spectrogram(data(i).noisy, hamming(256), 128, 512, data(i).Fs, 'yaxis');
    title('Noisy speech — airport 5 dB SNR');
    colorbar off;

    sgtitle(sprintf('Spectrogram — %s', data(i).label));

    savefig(sprintf('spectrogram_%s.fig', data(i).label));
    exportgraphics(gcf, sprintf('spectrogram_%s.png', data(i).label), 'Resolution', 150);
    close;

    fprintf('Saved: spectrogram_%s\n', data(i).label);

end

fprintf('Done — %d spectrograms saved.\n', length(data));