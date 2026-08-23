% PURPOSE:
%   Visualizes time-domain waveforms of clean and noisy speech signals
%   for direct comparison of amplitude variations and noise effects.

% INPUTS:
%   - data struct (must be preloaded):
%       data(i).clean : clean speech signal
%       data(i).noisy : noisy speech signal
%       data(i).Fs    : sampling frequency
%       data(i).N     : signal length (samples)
%       data(i).label : file identifier/name

% OUTPUTS:
%   - Time-domain waveform comparison plots for each file
%   - Saved figures:
%       waveform_<label>.fig  (MATLAB figure)
%       waveform_<label>.png  (image file)

% METHOD OVERVIEW:
%   1. Generates time axis using sampling frequency
%   2. Plots clean speech waveform
%   3. Plots corresponding noisy speech waveform
%   4. Displays both signals in stacked subplots
%   5. Saves figures for each audio file

% NOTES:
%   - Useful for observing amplitude distortion and noise presence
%   - Complements frequency-domain and spectrogram analysis
%   - Figures generated in non-visible mode to enable batch processing
%   - Automatically closes figures to prevent memory issues

for i = 1:length(data)

    t = (0 : data(i).N - 1) / data(i).Fs;

    figure('Visible', 'off');  % 'off' so 30 windows don't flood your screen

    subplot(2,1,1);
    plot(t, data(i).clean);
    title('Clean speech');
    xlabel('Time (s)'); ylabel('Amplitude');

    subplot(2,1,2);
    plot(t, data(i).noisy);
    title('Noisy speech — airport 5 dB SNR');
    xlabel('Time (s)'); ylabel('Amplitude');

    sgtitle(sprintf('Waveform Comparison — %s', data(i).label));

    savefig(sprintf('waveform_%s.fig', data(i).label));
    exportgraphics(gcf, sprintf('waveform_%s.png', data(i).label), 'Resolution', 150);
    close;  % close after saving so memory doesn't pile up

    fprintf('Saved: waveform_%s\n', data(i).label);

end

fprintf('Done — %d figures saved.\n', length(data));