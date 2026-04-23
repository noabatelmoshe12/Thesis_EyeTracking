% This script is based on the original raw MATLAB file provided by Gal,
% a PhD student in the lab, for extracting variables from the behavioral data.
% The original file name was: data_extraction_noa.m
% It was renamed to: behavior_wa_scores_export.m
% to reflect its current role in exporting subject-level WA scores
% for downstream analysis in Python.
% The original logic was preserved as much as possible,
% with only minimal changes made for output formatting and CSV export.
%
% Input:
% - Subject-level MATLAB files in .mat format
%   (e.g., subject_101_Results_Decision_Strategy_Experiment.mat)
% - Each file is expected to contain the behavioral Data structure used
%   in the original script.
%
% Output:
% - A CSV file named behavior_wa_scores.csv
% - The output contains subject-level behavioral variables:
%   subject_id, wa_score_3, wa_score_4
%
% Purpose:
% - To extract subject-level behavioral WA-based scores from the original
%   MATLAB behavioral data and export them in a format that can be read
%   easily in Python for downstream correlation analysis with eye-movement metrics.

%% extract data
clear; clc
a1 = 'subject_'; a2 = '_Results_Decision_Strategy_Experiment.mat';
numOfSubjects = 40;
numOfTrials = 100;
numOfPractice = 10;
data_strategy_class_3 = [];
data_strategy_class_4 = [];

for i = 1:numOfSubjects
    file_madm = [a1,num2str(100+i),a2];
    load(file_madm)
    % stimuli and response data
    stimuli_differences_3 = nan(numOfTrials,3);
    stimuli_differences_4 = nan(numOfTrials,4);
    for j = 1:numOfTrials
        stimuli_differences_3(j,:) = (Data{1,5}{1,j+numOfPractice+1}(:,1)...
            -Data{1,5}{1,j+numOfPractice+1}(:,2))';
        stimuli_differences_4(j,:) = (Data{1,5}{1,j+2*numOfPractice+numOfTrials+1}(:,1)...
            -Data{1,5}{1,j+2*numOfPractice+numOfTrials+1}(:,2))';
    end
    subject_response_3 = Data{1,2}{1,2}(1:numOfTrials);
    subject_response_4 = Data{1,2}{1,2}(numOfTrials+1:2*numOfTrials);
    accuracy_3_trial = Data{1,3}{1,2}(1:numOfTrials);
    accuracy_4_trial = Data{1,3}{1,2}(numOfTrials+1:2*numOfTrials);

    % slow trials indicators
    slowTrials_3 = isnan(subject_response_3);
    slowTrials_4 = isnan(subject_response_4);
    subject_response_3 = subject_response_3(~slowTrials_3);
    subject_response_4 = subject_response_4(~slowTrials_4);
    accuracy_3_trial = accuracy_3_trial(~slowTrials_3);
    accuracy_4_trial = accuracy_4_trial(~slowTrials_4);

    % data for strategy classification
    subs3 = i*ones(sum(~slowTrials_3),1);
    subs4 = i*ones(sum(~slowTrials_4),1);
    % WA predictions
    dummy_WApredictions3 = Data{1,1}{1,2}(numOfPractice+1:numOfTrials+numOfPractice);
    dummy_WApredictions3 = dummy_WApredictions3(~slowTrials_3);
    dummy_WApredictions4 = Data{1,1}{1,2}(numOfTrials+2*numOfPractice+1:end);
    dummy_WApredictions4 = dummy_WApredictions4(~slowTrials_4);
    % TTB predictions
    dummy_TTBpredictions3 = nan(numOfTrials,1);
    for c = 1:numOfTrials
        k = 1;
        while k <= 3
            if stimuli_differences_3(c,k) > 0
                dummy_TTBpredictions3(c) =  1;
                k = 6;
            elseif stimuli_differences_3(c,k) < 0
                dummy_TTBpredictions3(c) =  2;
                k = 6;
            else
                k = k + 1;
            end
        end
    end
    dummy_TTBpredictions3 = dummy_TTBpredictions3(~slowTrials_3);
    %ttb predictions 4
    dummy_TTBpredictions4 = nan(numOfTrials,1);
    for c = 1:numOfTrials
        k = 1;
        while k <= 4
            if stimuli_differences_4(c,k) > 0
                dummy_TTBpredictions4(c) =  1;
                k = 6;
            elseif stimuli_differences_4(c,k) < 0
                dummy_TTBpredictions4(c) =  2;
                k = 6;
            else
                k = k + 1;
            end
        end
    end
    dummy_TTBpredictions4 = dummy_TTBpredictions4(~slowTrials_4);
    consistent_trials_3 = dummy_TTBpredictions3 == dummy_WApredictions3;
    data_strategy_class_3 = [data_strategy_class_3;subs3,consistent_trials_3,...
        accuracy_3_trial];
    consistent_trials_4 = dummy_TTBpredictions4 == dummy_WApredictions4;
    data_strategy_class_4 = [data_strategy_class_4;subs4,consistent_trials_4,...
        accuracy_4_trial];
    % logistic regression for the attribute weights
    % subject_response_3(subject_response_3 == 2) = 0;
    % subject_response_4(subject_response_4 == 2) = 0;
    % stimuli_differences_3 = stimuli_differences_3(~slowTrials_3,:);
    % stimuli_differences_4 = stimuli_differences_4(~slowTrials_4,:);
    % weights_3(i,:) = glmfit(stimuli_differences_3,...
    %     subject_response_3, 'binomial')';
    % weights_4(i,:) = glmfit(stimuli_differences_4,...
    %     subject_response_4, 'binomial')';
end

% Strategy classification
% 3
subjects_strategy3 = nan(numOfSubjects,1);
choices_WAV_p_3 = nan(numOfSubjects,1);
%strategyLong3 = nan(length(subs3),1);
for i = 1:numOfSubjects
    choices_WAV_p_3(i) = mean(data_strategy_class_3(data_strategy_class_3(:,1) == i & ~data_strategy_class_3(:,2),3));
    subjects_strategy3(i) = choices_WAV_p_3(i)>=0.5;
    %strategyLong3(subs3 == i) = subjects_strategy3(i-1)*ones(sum(subs3 == i),1);
end
% 4
subjects_strategy4 = nan(numOfSubjects,1);
choices_WAV_p_4 = nan(numOfSubjects,1);
%strategyLong4 = nan(length(subs4),1);
for i = 1:numOfSubjects
    choices_WAV_p_4(i) = mean(data_strategy_class_4(data_strategy_class_4(:,1) == i & ~data_strategy_class_4(:,2),3));
    subjects_strategy4(i) = choices_WAV_p_4(i)>=0.5;
    %strategyLong4(subs4 == i) = subjects_strategy4(i-1)*ones(sum(subs4 == i),1);
end

subject_id = (101:100+numOfSubjects)';

results_table = table( ...
    subject_id, ...
    choices_WAV_p_3, ...
    choices_WAV_p_4, ...
    'VariableNames', { ...
        'subject_id', ...
        'wa_score_3', ...
        'wa_score_4'} ...
);

output_dir = 'C:\Projects\Thesis_EyeTracking\data\results';
output_file = fullfile(output_dir, 'behavior_wa_scores.csv');
writetable(results_table, output_file);