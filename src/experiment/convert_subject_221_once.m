%% Convert subject 221 EDF to MAT - one time script

Subject_Number = 221;

edfFile = fullfile('Eyedata', sprintf('sub_%d.EDF', Subject_Number));
SaveEDF = fullfile('Eyedata', sprintf('Subject_%d_eyeData.mat', Subject_Number));

if ~exist('Eyedata', 'dir')
    mkdir('Eyedata');
end

% Check that EDF exists
if ~exist(edfFile, 'file')
    error('EDF file not found: %s', edfFile);
end

fprintf('Converting %s to MAT structure...\n', edfFile);

edfStruct = edfmex(edfFile);

save(SaveEDF, 'edfStruct');

fprintf('EDF successfully converted and saved: %s\n', SaveEDF);