% PURPOSE:
%   Computes and visualizes the Power Spectral Density (PSD) of clean and
%   noisy speech signals using Welch’s method. Enables comparison of
%   spectral characteristics and noise impact across frequencies.

% INPUTS:
%   - data struct (must be preloaded):
%       data(i).clean : clean speech signal
%       data(i).noisy : noisy speech signal
%       data(i).Fs    : sampling frequency
%       data(i).label : file identifier/name

% OUTPUTS:
%   - PSD comparison plots for each file (clean vs noisy)
%   - Saved figures:
%       psd_<label>.fig  (MATLAB figure)
%       psd_<label>.png  (image file)

% METHOD OVERVIEW:
%   1. Applies Welch’s method (pwelch) to estimate PSD:
%       - Window length: 512 samples
%       - Overlap: 256 samples
%       - FFT length: 512
%   2. Computes PSD for both clean and noisy signals
%   3. Plots both spectra on the same graph for comparison
%   4. Labels axes and adds legend
%   5. Saves plots for each audio file

% NOTES:
%   - PSD highlights how noise affects different frequency bands
%   - Useful for analyzing broadband vs narrowband noise behavior
%   - Figures generated in non-visible mode for batch processing
for i = 1:length(data)

    figure('Visible', 'off');

    pwelch(data(i).clean, 512, 256, 512, data(i).Fs);
    hold on;
    pwelch(data(i).noisy, 512, 256, 512, data(i).Fs);
    hold off;

    legend('Clean', 'Noisy — airport 5 dB SNR');
    title(sprintf('Power Spectral Density — %s', data(i).label));
    xlabel('Frequency (Hz)');
    ylabel('Power/Frequency (dB/Hz)');

    savefig(sprintf('psd_%s.fig', data(i).label));
    exportgraphics(gcf, sprintf('psd_%s.png', data(i).label), 'Resolution', 150);
    close;

    fprintf('Saved: psd_%s\n', data(i).label);

end

fprintf('Done — %d PSD plots saved.\n', length(data));