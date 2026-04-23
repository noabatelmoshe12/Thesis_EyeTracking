% merge_rt_transitions_aoi_summary.m
%
% Creates one subject-level table with:
% - mean RT block 1 / block 2
% - mean valid transitions per trial block 1 / block 2
% - mean valid AOI looks per trial block 1 / block 2
%
% AOI looks are computed from detailed fixation files BEFORE transition classification,
% using valid AOIs only (excluding NaN / F / A / B).

clear; clc

% -----------------------
% paths
% -----------------------
results_dir   = 'C:\Projects\Thesis_EyeTracking\data\results';
fixations_dir = 'C:\Projects\Thesis_EyeTracking\data\processed\fixations';

behavior_file  = fullfile(results_dir, 'behavior_subject_summary.csv');
transitions_file = fullfile(results_dir, 'trial_results_summary.csv');

% -----------------------
% read behavior table
% -----------------------
behavior_table = readtable(behavior_file);
behavior_table = behavior_table(:, {'subject_id', 'mean_rt_block1', 'mean_rt_block2'});

% -----------------------
% read transitions table and summarize
% -----------------------
transitions_table = readtable(transitions_file);
transitions_table = transitions_table(:, {'Subject', 'Block', 'Total'});
transitions_table.Properties.VariableNames{'Subject'} = 'subject_id';

transitions_table = transitions_table(~isnan(transitions_table.Total), :);

G_mean_trans = groupsummary(transitions_table, {'subject_id','Block'}, 'mean', 'Total');
G_std_trans  = groupsummary(transitions_table, {'subject_id','Block'}, 'std',  'Total');

trans_long = outerjoin(G_mean_trans, G_std_trans, ...
    'Keys', {'subject_id','Block'}, ...
    'MergeKeys', true, ...
    'Type', 'left');

trans_long = trans_long(:, {'subject_id','Block','GroupCount','mean_Total','std_Total'});

trans_b1 = trans_long(trans_long.Block == 1, {'subject_id','GroupCount','mean_Total','std_Total'});
trans_b2 = trans_long(trans_long.Block == 2, {'subject_id','GroupCount','mean_Total','std_Total'});

trans_b1.Properties.VariableNames = { ...
    'subject_id', ...
    'valid_trials_trans_block1', ...
    'mean_valid_transitions_block1', ...
    'std_valid_transitions_block1'};

trans_b2.Properties.VariableNames = { ...
    'subject_id', ...
    'valid_trials_trans_block2', ...
    'mean_valid_transitions_block2', ...
    'std_valid_transitions_block2'};

trans_summary = outerjoin(trans_b1, trans_b2, ...
    'Keys', 'subject_id', ...
    'MergeKeys', true, ...
    'Type', 'full');

% keep only behavior subjects
trans_summary = innerjoin(behavior_table(:, {'subject_id'}), trans_summary, ...
    'Keys', 'subject_id');

% -----------------------
% read detailed fixation files and compute AOI-look summaries
% -----------------------
fixation_files = dir(fullfile(fixations_dir, '*_detailed.csv'));

aoi_summary_all = table();

for k = 1:length(fixation_files)
    
    file_path = fullfile(fixations_dir, fixation_files(k).name);
    T = readtable(file_path);
    
    % expected columns include:
    % Subject, Block, Trial, AOI, ...
    if ~all(ismember({'Subject','Block','Trial','AOI'}, T.Properties.VariableNames))
        warning('Skipping file (missing required columns): %s', fixation_files(k).name);
        continue
    end
    
    % convert AOI to string for safer comparisons
    AOI = string(T.AOI);
    
    % valid AOIs only: exclude missing and header cells
    valid_rows = ~ismissing(AOI) & AOI ~= "" & AOI ~= "F" & AOI ~= "A" & AOI ~= "B";
    T_valid = T(valid_rows, {'Subject','Block','Trial'});
    
    if isempty(T_valid)
        continue
    end
    
    % count valid AOI looks per trial
    trial_counts = groupsummary(T_valid, {'Subject','Block','Trial'});
    trial_counts = trial_counts(:, {'Subject','Block','Trial','GroupCount'});
    trial_counts.Properties.VariableNames{'GroupCount'} = 'valid_aoi_looks';
    
    % summarize per subject x block
    aoi_mean = groupsummary(trial_counts, {'Subject','Block'}, 'mean', 'valid_aoi_looks');
    aoi_std  = groupsummary(trial_counts, {'Subject','Block'}, 'std',  'valid_aoi_looks');
    
    aoi_long = outerjoin(aoi_mean, aoi_std, ...
        'Keys', {'Subject','Block'}, ...
        'MergeKeys', true, ...
        'Type', 'left');
    
    aoi_long = aoi_long(:, {'Subject','Block','GroupCount','mean_valid_aoi_looks','std_valid_aoi_looks'});
    aoi_long.Properties.VariableNames{'Subject'} = 'subject_id';
    
    aoi_summary_all = [aoi_summary_all; aoi_long];
end

% in case there is one file per subject, this is already one row per subject/block.
% still, remove any accidental duplicates by taking the mean again:
aoi_summary_all = groupsummary(aoi_summary_all, {'subject_id','Block'}, ...
    {'mean'}, {'GroupCount','mean_valid_aoi_looks','std_valid_aoi_looks'});

% rename grouped columns
aoi_summary_all = aoi_summary_all(:, {'subject_id','Block', ...
    'mean_GroupCount', ...
    'mean_mean_valid_aoi_looks', ...
    'mean_std_valid_aoi_looks'});

aoi_summary_all.Properties.VariableNames = { ...
    'subject_id', ...
    'Block', ...
    'valid_trials_aoi', ...
    'mean_valid_aoi_looks', ...
    'std_valid_aoi_looks'};

% split by block
aoi_b1 = aoi_summary_all(aoi_summary_all.Block == 1, :);
aoi_b2 = aoi_summary_all(aoi_summary_all.Block == 2, :);

aoi_b1 = aoi_b1(:, {'subject_id','valid_trials_aoi','mean_valid_aoi_looks','std_valid_aoi_looks'});
aoi_b2 = aoi_b2(:, {'subject_id','valid_trials_aoi','mean_valid_aoi_looks','std_valid_aoi_looks'});

aoi_b1.Properties.VariableNames = { ...
    'subject_id', ...
    'valid_trials_aoi_block1', ...
    'mean_valid_aoi_looks_block1', ...
    'std_valid_aoi_looks_block1'};

aoi_b2.Properties.VariableNames = { ...
    'subject_id', ...
    'valid_trials_aoi_block2', ...
    'mean_valid_aoi_looks_block2', ...
    'std_valid_aoi_looks_block2'};

aoi_summary = outerjoin(aoi_b1, aoi_b2, ...
    'Keys', 'subject_id', ...
    'MergeKeys', true, ...
    'Type', 'full');

% keep only behavior subjects
aoi_summary = innerjoin(behavior_table(:, {'subject_id'}), aoi_summary, ...
    'Keys', 'subject_id');

% -----------------------
% final merge
% -----------------------
final_table = outerjoin(behavior_table, trans_summary, ...
    'Keys', 'subject_id', ...
    'MergeKeys', true, ...
    'Type', 'left');

final_table = outerjoin(final_table, aoi_summary, ...
    'Keys', 'subject_id', ...
    'MergeKeys', true, ...
    'Type', 'left');

final_table = sortrows(final_table, 'subject_id');

% -----------------------
% display and save
% -----------------------
disp(final_table)

output_file = fullfile(results_dir, 'rt_transitions_aoi_summary.csv');
writetable(final_table, output_file);

fprintf('Merged table saved to:\n%s\n', output_file);