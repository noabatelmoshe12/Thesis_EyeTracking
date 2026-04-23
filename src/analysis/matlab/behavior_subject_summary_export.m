% behavior_subject_summary_export.m
%
% Purpose:
% Extract subject-level behavioral summary measures from the decision-making task,
% create a summary table, save it as CSV, and generate two bar plots:
% one for Block 1 mean RT across subjects and one for Block 2 mean RT across subjects.
%
% Input folder:
% C:\Projects\Thesis_EyeTracking\data\raw
%
% Output folder:
% C:\Projects\Thesis_EyeTracking\data\results
%
% Assumed data structure inside each file:
% - Accuracy vector: Data{1,3}{1,2}
% - RT vector:       Data{1,4}{1,2}

%% extract data
clear; clc

% -----------------------
% paths
% -----------------------
input_dir  = 'C:\Projects\Thesis_EyeTracking\data\raw';
output_dir = 'C:\Projects\Thesis_EyeTracking\data\results';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% -----------------------
% file naming
% -----------------------
a1 = 'subject_';   % change to 'Subject_' if needed
a2 = '_Results_Decision_Strategy_Experiment.mat';

numOfSubjects = 31;
firstSubjectID = 101;
numOfTrialsPerBlock = 100;

% -----------------------
% QC thresholds
% -----------------------
fastRTthreshold      = 0.30;  % RT below this is considered very fast
accuracyThreshold    = 0.75;
missingPctThreshold  = 0.05;
fastPctThreshold     = 0.02;
lowSdThreshold       = 0.25;

% initialize result vectors
subject_id = nan(numOfSubjects,1);

mean_rt_block1   = nan(numOfSubjects,1);
mean_rt_block2   = nan(numOfSubjects,1);

median_rt_block1 = nan(numOfSubjects,1);
median_rt_block2 = nan(numOfSubjects,1);

sd_rt_block1     = nan(numOfSubjects,1);
sd_rt_block2     = nan(numOfSubjects,1);

min_rt_block1    = nan(numOfSubjects,1);
min_rt_block2    = nan(numOfSubjects,1);

max_rt_block1    = nan(numOfSubjects,1);
max_rt_block2    = nan(numOfSubjects,1);

accuracy_block1  = nan(numOfSubjects,1);
accuracy_block2  = nan(numOfSubjects,1);

missing_n_block1 = nan(numOfSubjects,1);
missing_n_block2 = nan(numOfSubjects,1);

missing_pct_block1 = nan(numOfSubjects,1);
missing_pct_block2 = nan(numOfSubjects,1);

fast_n_block1    = nan(numOfSubjects,1);
fast_n_block2    = nan(numOfSubjects,1);

fast_pct_block1  = nan(numOfSubjects,1);
fast_pct_block2  = nan(numOfSubjects,1);

flag_low_accuracy   = nan(numOfSubjects,1);
flag_many_missings  = nan(numOfSubjects,1);
flag_many_fast_rt   = nan(numOfSubjects,1);
flag_low_rt_sd      = nan(numOfSubjects,1);
flag_suspect_any    = nan(numOfSubjects,1);

suspect_reason = strings(numOfSubjects,1);

for i = 1:numOfSubjects
    
    subjNum = firstSubjectID + i - 1;
    subject_id(i) = subjNum;
    
    file_madm = [a1, num2str(subjNum), a2];
    full_input_path = fullfile(input_dir, file_madm);
    
    if ~isfile(full_input_path)
        warning('File not found: %s', full_input_path);
        continue
    end
    
    S = load(full_input_path);
    Data = S.Data;
    
    acc_all = Data{1,3}{1,2};
    rt_all  = Data{1,4}{1,2};
    
    acc_all = acc_all(:);
    rt_all  = rt_all(:);
    
    acc_block1 = acc_all(1:numOfTrialsPerBlock);
    acc_block2 = acc_all(numOfTrialsPerBlock+1 : 2*numOfTrialsPerBlock);
    
    rt_block1  = rt_all(1:numOfTrialsPerBlock);
    rt_block2  = rt_all(numOfTrialsPerBlock+1 : 2*numOfTrialsPerBlock);
    
    % -----------------------
    % responded trials only
    % -----------------------
    valid_rt_block1 = rt_block1(~isnan(rt_block1));
    valid_rt_block2 = rt_block2(~isnan(rt_block2));

    % -----------------------
    % summary measures: RT
    % -----------------------
    mean_rt_block1(i)   = mean(rt_block1, 'omitnan');
    mean_rt_block2(i)   = mean(rt_block2, 'omitnan');
    
    median_rt_block1(i) = median(rt_block1, 'omitnan');
    median_rt_block2(i) = median(rt_block2, 'omitnan');
    
    sd_rt_block1(i)     = std(rt_block1, 'omitnan');
    sd_rt_block2(i)     = std(rt_block2, 'omitnan');
    
    if ~isempty(valid_rt_block1)
        min_rt_block1(i) = min(valid_rt_block1);
        max_rt_block1(i) = max(valid_rt_block1);
    end
    
    if ~isempty(valid_rt_block2)
        min_rt_block2(i) = min(valid_rt_block2);
        max_rt_block2(i) = max(valid_rt_block2);
    end
    
    % -----------------------
    % summary measures: accuracy
    % -----------------------
    accuracy_block1(i) = mean(acc_block1, 'omitnan');
    accuracy_block2(i) = mean(acc_block2, 'omitnan');
    
    % -----------------------
    % missing responses
    % -----------------------
    missing_n_block1(i) = sum(isnan(rt_block1));
    missing_n_block2(i) = sum(isnan(rt_block2));
    
    missing_pct_block1(i) = missing_n_block1(i) / numOfTrialsPerBlock;
    missing_pct_block2(i) = missing_n_block2(i) / numOfTrialsPerBlock;
    
    % -----------------------
    % suspiciously fast RTs
    % -----------------------
    fast_n_block1(i) = sum(rt_block1 < fastRTthreshold, 'omitnan');
    fast_n_block2(i) = sum(rt_block2 < fastRTthreshold, 'omitnan');
    
    fast_pct_block1(i) = fast_n_block1(i) / numOfTrialsPerBlock;
    fast_pct_block2(i) = fast_n_block2(i) / numOfTrialsPerBlock;
    
    % -----------------------
    % simple QC flags
    % -----------------------
    low_accuracy_this  = (accuracy_block1(i) < accuracyThreshold) || (accuracy_block2(i) < accuracyThreshold);
    many_missings_this = (missing_pct_block1(i) > missingPctThreshold) || (missing_pct_block2(i) > missingPctThreshold);
    many_fast_this     = (fast_pct_block1(i) > fastPctThreshold) || (fast_pct_block2(i) > fastPctThreshold);
    low_rt_sd_this     = (sd_rt_block1(i) < lowSdThreshold) || (sd_rt_block2(i) < lowSdThreshold);
    
    flag_low_accuracy(i)  = low_accuracy_this;
    flag_many_missings(i) = many_missings_this;
    flag_many_fast_rt(i)  = many_fast_this;
    flag_low_rt_sd(i)     = low_rt_sd_this;
    
    flag_suspect_any(i) = low_accuracy_this || many_missings_this || ...
                          many_fast_this || low_rt_sd_this;
    
    reasons = strings(0,1);
    
    if low_accuracy_this
        reasons(end+1) = "low accuracy";
    end
    if many_missings_this
        reasons(end+1) = "many missing responses";
    end
    if many_fast_this
        reasons(end+1) = "many very fast RTs";
    end
    if low_rt_sd_this
        reasons(end+1) = "low RT variability";
    end
    
    if isempty(reasons)
        suspect_reason(i) = "";
    else
        suspect_reason(i) = strjoin(reasons, ", ");
    end
end

%% create summary table
results_table = table( ...
    subject_id, ...
    mean_rt_block1, mean_rt_block2, ...
    median_rt_block1, median_rt_block2, ...
    sd_rt_block1, sd_rt_block2, ...
    min_rt_block1, min_rt_block2, ...
    max_rt_block1, max_rt_block2, ...
    accuracy_block1, accuracy_block2, ...
    missing_n_block1, missing_n_block2, ...
    missing_pct_block1, missing_pct_block2, ...
    fast_n_block1, fast_n_block2, ...
    fast_pct_block1, fast_pct_block2, ...
    flag_low_accuracy, ...
    flag_many_missings, ...
    flag_many_fast_rt, ...
    flag_low_rt_sd, ...
    flag_suspect_any, ...
    suspect_reason, ...
    'VariableNames', { ...
        'subject_id', ...
        'mean_rt_block1', 'mean_rt_block2', ...
        'median_rt_block1', 'median_rt_block2', ...
        'sd_rt_block1', 'sd_rt_block2', ...
        'min_rt_block1', 'min_rt_block2', ...
        'max_rt_block1', 'max_rt_block2', ...
        'accuracy_block1', 'accuracy_block2', ...
        'missing_n_block1', 'missing_n_block2', ...
        'missing_pct_block1', 'missing_pct_block2', ...
        'fast_n_block1', 'fast_n_block2', ...
        'fast_pct_block1', 'fast_pct_block2', ...
        'flag_low_accuracy', ...
        'flag_many_missings', ...
        'flag_many_fast_rt', ...
        'flag_low_rt_sd', ...
        'flag_suspect_any', ...
        'suspect_reason'} ...
);

disp(results_table)

%% save summary table
output_file = fullfile(output_dir, 'behavior_subject_summary.csv');
writetable(results_table, output_file);

fprintf('Summary table saved to:\n%s\n', output_file);

%% print suspicious subjects with reasons
suspect_rows = results_table(results_table.flag_suspect_any == 1, {'subject_id','suspect_reason'});

fprintf('\nSuspicious subjects based on QC criteria:\n');
if isempty(suspect_rows)
    fprintf('None\n');
else
    disp(suspect_rows)
end

%% bar plot for mean RT per subject - block 1
valid_idx_block1 = ~isnan(mean_rt_block1);
subjects_block1 = subject_id(valid_idx_block1);
values_block1 = mean_rt_block1(valid_idx_block1);
flags_block1 = flag_suspect_any(valid_idx_block1);

figure;
bar(subjects_block1, values_block1);
hold on;
yline(mean(values_block1, 'omitnan'), '--', 'Mean', 'LineWidth', 1.5);
yline(median(values_block1, 'omitnan'), '--', 'Median', 'LineWidth', 1.5);

suspect_subjects_block1 = subjects_block1(flags_block1 == 1);
suspect_values_block1 = values_block1(flags_block1 == 1);
if ~isempty(suspect_subjects_block1)
    scatter(suspect_subjects_block1, suspect_values_block1, 50, 'filled');
end

title('Mean RT per Subject - Block 1');
xlabel('Subject ID');
ylabel('Mean RT (s)');
xticks(subjects_block1);
xtickangle(45);
hold off;

plot_file_block1 = fullfile(output_dir, 'mean_rt_per_subject_block1.png');
saveas(gcf, plot_file_block1);

%% bar plot for mean RT per subject - block 2
valid_idx_block2 = ~isnan(mean_rt_block2);
subjects_block2 = subject_id(valid_idx_block2);
values_block2 = mean_rt_block2(valid_idx_block2);
flags_block2 = flag_suspect_any(valid_idx_block2);

figure;
bar(subjects_block2, values_block2);
hold on;
yline(mean(values_block2, 'omitnan'), '--', 'Mean', 'LineWidth', 1.5);
yline(median(values_block2, 'omitnan'), '--', 'Median', 'LineWidth', 1.5);

suspect_subjects_block2 = subjects_block2(flags_block2 == 1);
suspect_values_block2 = values_block2(flags_block2 == 1);
if ~isempty(suspect_subjects_block2)
    scatter(suspect_subjects_block2, suspect_values_block2, 50, 'filled');
end

title('Mean RT per Subject - Block 2');
xlabel('Subject ID');
ylabel('Mean RT (s)');
xticks(subjects_block2);
xtickangle(45);
hold off;

plot_file_block2 = fullfile(output_dir, 'mean_rt_per_subject_block2.png');
saveas(gcf, plot_file_block2);

fprintf('Block 1 plot saved to:\n%s\n', plot_file_block1);
fprintf('Block 2 plot saved to:\n%s\n', plot_file_block2);