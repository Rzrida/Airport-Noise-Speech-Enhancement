%% loadaudios_1.m
% PURPOSE:
%   Loads paired clean and noisy speech audio files from specified directories,
%   aligns and normalizes them, and stores them in a structured format for
%   further processing and evaluation.

% INPUTS:
%   - cleanDir : directory path containing clean speech (.wav) files
%   - noisyDir : directory path containing noisy speech (.wav) files
%   (Both directories must contain corresponding audio files)

% OUTPUTS:
%   - data struct array containing:
%       data(i).label : identifier for each audio pair
%       data(i).Fs    : sampling frequency (Hz)
%       data(i).N     : signal length (samples)
%       data(i).clean : normalized clean speech signal
%       data(i).noisy : normalized noisy speech signal

% METHOD OVERVIEW:
%   1. Reads clean and noisy audio files from directories
%   2. Sorts filenames to ensure correct pairing
%   3. Matches corresponding clean-noisy pairs
%   4. Trims signals to equal length
%   5. Normalizes both signals using peak value of clean signal
%   6. Stores processed signals in structured array

% NOTES:
%   - Assumes one-to-one correspondence between clean and noisy files
%   - Uses peak normalization for consistent amplitude scaling
%   - Supports subset (e.g., 16 files) or full dataset loading
%   - Output struct is used throughout the speech enhancement pipeline

clc; clear; close all;


%selected 16 audios
cleanDir = "C:\Users\rzrid\Desktop\DSP\Project\Final_5dB\audios\clean\clean";
noisyDir = "C:\Users\rzrid\Desktop\DSP\Project\Final_5dB\audios\airport_5dB\5dB";

%complete audios
%cleanDir = "C:\Users\rzrid\Desktop\DSP\Project\clean";
%noisyDir = "C:\Users\rzrid\Desktop\DSP\Project\airport_5dB\5dB";

cleanList = dir(fullfile(cleanDir, "*.wav"));
noisyList = dir(fullfile(noisyDir, "*.wav"));

cleanNames = sort({cleanList.name});
noisyNames = sort({noisyList.name});

nFiles = min(length(cleanNames), length(noisyNames));

data = struct();

for i = 1:nFiles

    cleanPath = fullfile(cleanDir, cleanNames{i});
    noisyPath = fullfile(noisyDir, noisyNames{i});

    fprintf("Pair %d:\n%s\n%s\n\n", i, cleanNames{i}, noisyNames{i});

    [clean_raw, Fs] = audioread(cleanPath);
    [noisy_raw, ~ ] = audioread(noisyPath);

    % Trim
    N = min(length(clean_raw), length(noisy_raw));
    clean_raw = clean_raw(1:N);
    noisy_raw = noisy_raw(1:N);

    % Normalize
    peak = max(abs(clean_raw));
    clean_raw = clean_raw / peak;
    noisy_raw = noisy_raw / peak;

    % Store
    data(i).label = sprintf('pair_%02d', i);
    data(i).Fs    = Fs;
    data(i).N     = N;
    data(i).clean = clean_raw;
    data(i).noisy = noisy_raw;

end

fprintf('Loaded %d sentence pairs.\n', nFiles);