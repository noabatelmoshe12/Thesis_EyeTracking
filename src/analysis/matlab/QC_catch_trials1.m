%% QC_catch_trials.m
% =========================================================================
% Quality-control script for catch / dominance trials
%
% Purpose:
% This script checks whether each participant passed the behavioral
% attention/comprehension criterion based on the catch trials.
%
% In the current experiment, the catch trials are implemented in the code as
% "dominance" trials. These are trials in which one alternative clearly
% dominates the other, so the correct answer should be relatively obvious.
%
% Experimental structure:
% - Each participant completed 2 experimental blocks.
% - Each block contains 103 experimental trials:
%       100 regular trials
%       3 dominance trials
% - Therefore, each participant should have:
%       3 dominance trials x 2 blocks = 6 catch trials in total.
%
% Catch-trial criterion:
% - A participant passes the QC criterion if they answered at least
%   4 out of 6 catch/dominance trials correctly.
%
% Output:
% The script creates a QC summary table with one row per participant:
%       Subject
%       FileFound
%       nCatch
%       nCorrectCatch
%       CatchAccuracy
%       PassedCatchCriterion
%
% The table is saved as:
%       catch_trials_QC_subjects_201_244.csv
%       catch_trials_QC_subjects_201_244.mat
%
% Important:
% This script does NOT delete or modify any participant data files.
% It only reads the behavioral result files and creates a QC summary.
% =========================================================================

clear;
clc;

%% -------------------------------------------------------------------------
% Settings
% -------------------------------------------------------------------------

% Define the subject numbers to check.
subjects = 201:244;

% Define the folder where the behavioral result files are stored.
% The script will look for files such as:
% Subject_201_Results_Decision_Strategy_Experiment.mat
% Subject_202_Results_Decision_Strategy_Experiment.mat
% etc.
dataFolder = 'C:\Users\user\Documents\Noa\Thesis_EyeTracking\src\experiment';

% Define the minimum number of correct catch trials required for inclusion.
% The criterion is at least 4 correct responses out of 6 catch trials.
minCorrectCatch = 4;

% Define the folder where the QC output files will be saved.
% This version saves the outputs inside the current MATLAB folder,
% in a subfolder called QC_results, to avoid permission problems.
outputFolder = fullfile(pwd, 'QC_results');

% If the output folder does not exist, create it.
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Define the full paths of the output files.
outputCSV = fullfile(outputFolder, 'catch_trials_QC_subjects_201_244.csv');
outputMAT = fullfile(outputFolder, 'catch_trials_QC_subjects_201_244.mat');

%% -------------------------------------------------------------------------
% Initialize QC table
% -------------------------------------------------------------------------

% Create an empty table.
% Each iteration of the loop will add one row for one subject.
QC = table();

%% -------------------------------------------------------------------------
% Loop over subjects
% -------------------------------------------------------------------------

for subj = subjects

    % Construct the expected behavioral results file name for this subject.
    fileName = fullfile(dataFolder, ...
        sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat', subj));

    fprintf('\nChecking subject %d...\n', subj);

    %% ---------------------------------------------------------------------
    % Check whether the subject's file exists
    % ---------------------------------------------------------------------

    if ~exist(fileName, 'file')

        fprintf('  File not found: %s\n', fileName);

        newRow = table(subj, false, NaN, NaN, NaN, false, ...
            'VariableNames', {'Subject', 'FileFound', 'nCatch', ...
                              'nCorrectCatch', 'CatchAccuracy', ...
                              'PassedCatchCriterion'});

        QC = [QC; newRow];

        continue
    end

    %% ---------------------------------------------------------------------
    % Load required variables
    % ---------------------------------------------------------------------

    load(fileName, 'Data', 'Trial_Type')

    %% ---------------------------------------------------------------------
    % Identify catch / dominance trials and extract their accuracy
    % ---------------------------------------------------------------------

    catchIdx = Trial_Type == "dominance";

    % Count the number of catch/dominance trials found for this subject.
    % This should normally be 6.
    nCatch = sum(catchIdx);

    %% ---------------------------------------------------------------------
    % Extract trial-by-trial accuracy
    % ---------------------------------------------------------------------

    acc = Data{3}{2};

    %% ---------------------------------------------------------------------
    % Safety checks
    % ---------------------------------------------------------------------

    if nCatch ~= 6
        warning('Subject %d: expected 6 catch/dominance trials, but found %d.', ...
            subj, nCatch);
    end

    if length(acc) ~= length(Trial_Type)
        warning('Subject %d: length mismatch. acc = %d, Trial_Type = %d.', ...
            subj, length(acc), length(Trial_Type));
    end

    %% ---------------------------------------------------------------------
    % Extract accuracy for catch/dominance trials only
    % ---------------------------------------------------------------------

    catchAcc = acc(catchIdx);

    %% ---------------------------------------------------------------------
    % Compute catch-trial performance
    % ---------------------------------------------------------------------

    % Count how many catch trials were answered correctly.
    nCorrectCatch = sum(catchAcc == 1, 'omitnan');

    % Compute proportion correct out of all catch trials.
    if nCatch > 0
        catchAccuracy = nCorrectCatch / nCatch;
    else
        catchAccuracy = NaN;
    end

    % Determine whether the participant passed the criterion.
    passedCatchCriterion = nCorrectCatch >= minCorrectCatch;

    %% ---------------------------------------------------------------------
    % Print subject result to Command Window
    % ---------------------------------------------------------------------

    fprintf('  Catch performance: %d/%d correct, accuracy = %.2f, passed = %d\n', ...
        nCorrectCatch, nCatch, catchAccuracy, passedCatchCriterion);

    %% ---------------------------------------------------------------------
    % Add subject result to QC table
    % ---------------------------------------------------------------------

    newRow = table(subj, true, nCatch, nCorrectCatch, ...
        catchAccuracy, passedCatchCriterion, ...
        'VariableNames', {'Subject', 'FileFound', 'nCatch', ...
                          'nCorrectCatch', 'CatchAccuracy', ...
                          'PassedCatchCriterion'});

    QC = [QC; newRow];

    %% ---------------------------------------------------------------------
    % Clear loaded variables before moving to the next subject
    % ---------------------------------------------------------------------

    clear Data Trial_Type acc catchIdx catchAcc

end

%% -------------------------------------------------------------------------
% Display final QC table
% -------------------------------------------------------------------------

disp(QC)

%% -------------------------------------------------------------------------
% Create inclusion and exclusion lists
% -------------------------------------------------------------------------

% Subjects to exclude:
% File was found, but the participant did not pass the catch-trial criterion.
subjectsToExclude = QC.Subject(QC.FileFound & ~QC.PassedCatchCriterion);

% Subjects to include:
% File was found, and the participant passed the catch-trial criterion.
subjectsToInclude = QC.Subject(QC.FileFound & QC.PassedCatchCriterion);

fprintf('\nSubjects to exclude based on catch trials:\n');
disp(subjectsToExclude)

fprintf('Subjects to include based on catch trials:\n');
disp(subjectsToInclude)

%% -------------------------------------------------------------------------
% Save outputs
% -------------------------------------------------------------------------

writetable(QC, outputCSV);

save(outputMAT, 'QC', 'subjectsToExclude', 'subjectsToInclude');

fprintf('\nQC table saved to:\n%s\n', outputCSV);
fprintf('MAT file saved to:\n%s\n', outputMAT);