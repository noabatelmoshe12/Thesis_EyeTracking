% Batch Analysis Script
% This script runs Convert_eye_data on all files in data/processed without needing Python loop
% Usage: matlab -batch "run_batch_analysis"

% Determine paths
script_path = fileparts(mfilename('fullpath'));
project_root = fullfile(script_path, '..', '..', '..');
processed_dir = fullfile(project_root, 'data', 'processed');

fprintf('Starting Batch Analysis...\n');
fprintf('Project Root: %s\n', project_root);
fprintf('Processed Data: %s\n', processed_dir);

% Add script folder to path
addpath(script_path);

% Find .mat files
files = dir(fullfile(processed_dir, '*.mat'));

if isempty(files)
    fprintf('No .mat files found in processed directory.\n');
else
    for i = 1:length(files)
        filename = files(i).name;
        full_path = fullfile(files(i).folder, filename);
        
        % Extract Subject ID
        % Expected: Subject_XXX_eyeData.mat or sub_XXX.mat
        [~, name, ~] = fileparts(filename);
        parts = split(name, '_');
        
        subject_code = '';
        % Look for number
        for j = 1:length(parts)
            if ~isnan(str2double(parts{j}))
                subject_code = parts{j};
                break;
            end
        end
        
        if isempty(subject_code)
             fprintf('Skipping %s: Could not extract subject ID.\n', filename);
             continue;
        end
        
        fprintf('Processing Subject %s (%s)...\n', subject_code, filename);
        
        try
            % Call analysis function
            % Convert_eye_data(mat_path, subject_code, output_dir)
            Convert_eye_data(full_path, subject_code, project_root);
        catch ME
            fprintf('Error processing %s: %s\n', filename, ME.message);
        end
    end
end

fprintf('Batch Analysis Complete.\n');
exit;
