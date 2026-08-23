% PURPOSE:
%   Plays clean, noisy, and enhanced speech signals sequentially
%   for subjective (listening-based) evaluation of enhancement quality.

% INPUTS:
%   - data struct:
%       data(i).clean      : clean speech signal
%       data(i).noisy      : noisy speech signal
%       data(i).enhanced   : enhanced speech signal
%       data(i).Fs         : sampling frequency
%       data(i).label      : file identifier/name
%   - i (index): selects which audio sample to play

% OUTPUTS:
%   - Audio playback of:
%       1. Clean signal
%       2. Noisy signal
%       3. Enhanced signal
%   - Console messages indicating playback progress

% NOTES:
%   - Uses soundsc() for normalized audio playback
%   - Includes pauses to allow full playback of each signal
%   - Useful for qualitative evaluation alongside objective metrics
i = 4;   % <-- change this to test different files (1 to 30)

clean     = data(i).clean;
noisy     = data(i).noisy;
enhanced  = data(i).enhanced;
Fs        = data(i).Fs;

fprintf('Playing file: %s\n', data(i).label);

% ---- Play CLEAN ----
disp('Playing CLEAN...');
soundsc(clean, Fs);
pause(length(clean)/Fs + 1);

% ---- Play NOISY ----
disp('Playing NOISY...');
soundsc(noisy, Fs);
pause(length(noisy)/Fs + 1);

% ---- Play ENHANCED ----
disp('Playing ENHANCED...');
soundsc(enhanced, Fs);