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
%       catch_trials_QC_subjects_201_226.csv
%       catch_trials_QC_subjects_201_226.mat
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
% For now, the relevant replication/sample range is 201-226.
subjects = 201:227;

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
% This is your results folder inside the thesis project.
outputFolder = 'C:\Users\user\Documents\Noa\Thesis_EyeTracking\data\results';

% If the output folder does not exist, create it.
% This prevents an error when trying to save the CSV/MAT files.
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Define the full paths of the output files.
outputCSV = fullfile(outputFolder, 'catch_trials_QC_subjects_201_226.csv');
outputMAT = fullfile(outputFolder, 'catch_trials_QC_subjects_201_226.mat');

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
    % Example:
    % C:\...\Subject_221_Results_Decision_Strategy_Experiment.mat
    fileName = fullfile(dataFolder, ...
        sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat', subj));

    fprintf('\nChecking subject %d...\n', subj);

    %% ---------------------------------------------------------------------
    % Check whether the subject's file exists
    % ---------------------------------------------------------------------

    % If the file does not exist, the script records this in the QC table
    % and continues to the next subject.
    if ~exist(fileName, 'file')

        fprintf('  File not found: %s\n', fileName);

        % Add a row indicating that the file was not found.
        % NaN is used for numeric fields that cannot be calculated.
        newRow = table(subj, false, NaN, NaN, NaN, false, ...
            'VariableNames', {'Subject', 'FileFound', 'nCatch', ...
                              'nCorrectCatch', 'CatchAccuracy', ...
                              'PassedCatchCriterion'});

        QC = [QC; newRow];

        % Skip the rest of the loop for this subject.
        continue
    end

    %% ---------------------------------------------------------------------
    % Load required variables
    % ---------------------------------------------------------------------

    % Load only the variables needed for this QC check:
    %
    % Data:
    %   A cell array saved by the experiment script.
    %   Data{3}{2} contains the subject's accuracy on each experimental trial.
    %
    % Trial_Type:
    %   A 206x1 string array indicating whether each experimental trial is:
    %       "regular"
    %       "dominance"
    %
    % Note:
    % Trial_Type includes experimental trials only, not practice trials.
    load(fileName, 'Data', 'Trial_Type')

    %% ---------------------------------------------------------------------
    % Identify catch / dominance trials and extract their accuracy
    % ---------------------------------------------------------------------

    % In the experiment code, the catch trials are not called "catch".
    % They are implemented and saved as "dominance" trials.
    %
    % Trial_Type is a 206x1 string array:
    %   - one row for each experimental trial
    %   - 103 trials in block 1
    %   - 103 trials in block 2
    %   - practice trials are NOT included
    %
    % Therefore, the catch trials can be identified by selecting the rows
    % where Trial_Type is equal to "dominance".
    %
    % Expected result:
    %   3 dominance trials in block 1
    %   3 dominance trials in block 2
    %   total = 6 catch/dominance trials per subject.

    catchIdx = Trial_Type == "dominance";

    % Count the number of catch/dominance trials found for this subject.
    % This should normally be 6.
    nCatch = sum(catchIdx);

    %% ---------------------------------------------------------------------
    % Extract trial-by-trial accuracy
    % ---------------------------------------------------------------------

    % Data{3}{2} contains the subject's accuracy for each experimental trial.
    %
    % Coding:
    %   1   = correct response
    %   0   = incorrect response
    %   NaN = missing response / timeout, if present
    %
    % Because Trial_Type and Data{3}{2} both refer to experimental trials only,
    % they should have the same length, usually 206.

    acc = Data{3}{2};

    %% ---------------------------------------------------------------------
    % Safety checks
    % ---------------------------------------------------------------------

    % These checks do not stop the script.
    % They only print warnings if something unexpected is found.
    %
    % This is useful because a subject file may be incomplete if the experiment
    % crashed, if saving stopped early, or if the file structure differs from
    % the expected format.

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

    % The logical index catchIdx is true only for dominance trials.
    % Therefore, acc(catchIdx) returns the accuracy values only for the
    % catch/dominance trials.
    %
    % Example:
    %   catchAcc = [1; 1; 0; 1; 1; 1]
    %
    % This would mean the subject answered 5 out of 6 catch trials correctly.

    catchAcc = acc(catchIdx);

    %% ---------------------------------------------------------------------
    % Compute catch-trial performance
    % ---------------------------------------------------------------------

    % Count how many catch trials were answered correctly.
    % NaN values are ignored.
    nCorrectCatch = sum(catchAcc == 1, 'omitnan');

    % Compute proportion correct out of all catch trials.
    % Expected denominator: 6.
    catchAccuracy = nCorrectCatch / nCatch;

    % Determine whether the participant passed the criterion.
    % The subject passes if they answered at least 4 catch trials correctly.
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

    % This avoids accidentally using variables from a previous subject if
    % something unexpected happens in the next iteration.
    clear Data Trial_Type acc catchIdx catchAcc

end

%% -------------------------------------------------------------------------
% Display final QC table
% -------------------------------------------------------------------------

% Show the full QC table in the Command Window.
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

% Save the QC table as a CSV file.
% This file can be opened in Excel or inspected later.
writetable(QC, outputCSV);

% Save the QC table and the include/exclude lists as a MAT file.
% This is useful for loading directly into MATLAB analysis scripts later.
save(outputMAT, 'QC', 'subjectsToExclude', 'subjectsToInclude');

fprintf('\nQC table saved to:\n%s\n', outputCSV);
fprintf('MAT file saved to:\n%s\n', outputMAT);