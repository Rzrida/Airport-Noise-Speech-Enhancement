% PURPOSE:
%   Analyzes and visualizes the frequency content of noise present in
%   noisy speech signals by computing the FFT of the noise component
%   (noise = noisy − clean). Helps identify dominant noise frequencies.

% INPUTS:
%   - data struct (must be preloaded):
%       data(i).clean : clean speech signal
%       data(i).noisy : noisy speech signal
%       data(i).Fs    : sampling frequency
%       data(i).N     : signal length
%       data(i).label : file identifier/name

% OUTPUTS:
%   - Frequency-domain plots of noise magnitude spectrum for each file
%   - Saved figures:
%       fft_noise_<label>.fig  (MATLAB figure)
%       fft_noise_<label>.png  (image file)

% METHOD OVERVIEW:
%   1. Computes noise signal as: noise = noisy − clean
%   2. Applies FFT to obtain frequency spectrum
%   3. Converts magnitude to decibel (dB) scale
%   4. Extracts single-sided spectrum (0 to Fs/2)
%   5. Plots frequency vs magnitude (dB)
%   6. Annotates key speech band limits (300–3400 Hz)
%   7. Saves figures for each audio sample

% NOTES:
%   - Useful for understanding noise characteristics (e.g., low-frequency hum,
%     broadband airport noise, etc.)
%   - Helps justify filter design choices (e.g., high-pass cutoff frequency)
%   - Figures are generated in non-visible mode for batch processing
for i = 1:length(data)

    % Isolate the noise signal
    noise = data(i).noisy - data(i).clean;

    % FFT
    N   = data(i).N;
    Fs  = data(i).Fs;
    f   = (0 : N/2) * Fs / N;          % frequency axis (Hz)
    mag = abs(fft(noise, N));           % magnitude spectrum
    mag = mag(1 : N/2 + 1);            % single-sided
    mag_dB = 20 * log10(mag + eps);    % convert to dB

    figure('Visible', 'off');

    plot(f, mag_dB);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title(sprintf('Noise Frequency Profile — %s', data(i).label));
    xline(300,  '--r', '300 Hz',  'LabelVerticalAlignment', 'bottom');
    xline(3400, '--r', '3400 Hz', 'LabelVerticalAlignment', 'bottom');
    xlim([0 Fs/2]);
    grid on;

    savefig(sprintf('fft_noise_%s.fig', data(i).label));
    exportgraphics(gcf, sprintf('fft_noise_%s.png', data(i).label), 'Resolution', 150);
    close;

    fprintf('Saved: fft_noise_%s\n', data(i).label);

end

fprintf('Done — %d FFT noise profiles saved.\n', length(data));