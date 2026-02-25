function [trialResults, blockResults, movementTable, trialSummaryTable, blockSummaryTable] = ...
    classifyScanHV_updated(fixationSequences, trialsPerBlock, numberOfBlocks, saveMatPath)

if nargin < 3
    error('Usage:classifyScanHV(fixationSequences, trialsPerBlock, numberOfBlocks)');
end
if nargin < 4
    saveMatPath = '';
end
if ~iscell(fixationSequences)
    error('fixationSequences must be a cell array.');
end

totalTrialsAvailable = size(fixationSequences, 1);
totalTrialsRequired  = trialsPerBlock * numberOfBlocks;
totalTrialsUsed      = min(totalTrialsAvailable, totalTrialsRequired);

trialResults = nan(totalTrialsUsed, 4);
blockResults = nan(numberOfBlocks, 1);
trialTransitions = nan(totalTrialsUsed, 1);
blockTransitions = nan(numberOfBlocks, 1);

% -------- LONG TABLE ACCUMULATORS --------
mov_Block   = [];
mov_Trial   = [];
mov_MoveIdx = [];
mov_From    = {};
mov_To      = {};
mov_Class   = {};
mov_FromPos = [];
mov_ToPos   = [];
mov_Skipped = [];

globalTrialIndex = 0;

for blockIndex = 1:numberOfBlocks

    horizontalCount_block = 0;
    verticalCount_block   = 0;

    for trialIndexWithinBlock = 1:trialsPerBlock

        globalTrialIndex = globalTrialIndex + 1;
        if globalTrialIndex > totalTrialsUsed
            break;
        end

        horizontalCount_trial = 0;
        verticalCount_trial   = 0;
        currentSequence = fixationSequences(globalTrialIndex, :);

        lastAOI   = '';
        lastPos   = NaN;
        skipped   = 0;
        moveIndex = 0;

        for pos = 1:numel(currentSequence)

            aoi = currentSequence{pos};

            if isnumeric(aoi) && isscalar(aoi) && isnan(aoi)
                skipped = skipped + 1;
                continue;
            end

            if ~(ischar(aoi) || (isstring(aoi) && isscalar(aoi)))
                continue;
            end
            aoi = char(aoi);

            tokens = regexp(aoi, '^([AB])(\d+)?$', 'tokens', 'once');
            if isempty(tokens)
                continue;
            end

            col = tokens{1};
            if numel(tokens)>=2 && ~isempty(tokens{2})
                row = str2double(tokens{2});
            else
                row = NaN;
            end

            if isempty(lastAOI)
                lastAOI = aoi;
                lastPos = pos;
                skipped = 0;
                continue;
            end

            fromAOI = lastAOI;
            toAOI   = aoi;

            fromTokens = regexp(fromAOI, '^([AB])(\d+)?$', 'tokens', 'once');
            fcol = fromTokens{1};
            if numel(fromTokens)>=2 && ~isempty(fromTokens{2})
                frow = str2double(fromTokens{2});
            else
                frow = NaN;
            end

            classLabel = 'Ignored';

            if strcmp(fcol,col)
                if ~(~isnan(frow) && ~isnan(row) && frow==row)
                    classLabel='Vertical';
                    verticalCount_trial=verticalCount_trial+1;
                    verticalCount_block=verticalCount_block+1;
                end
            elseif ~strcmp(fcol,col) && ~isnan(frow) && ~isnan(row) && frow==row
                classLabel='Horizontal';
                horizontalCount_trial=horizontalCount_trial+1;
                horizontalCount_block=horizontalCount_block+1;
            end

            % ----- SAVE LONG ROW -----
            moveIndex=moveIndex+1;
            mov_Block(end+1,1)=blockIndex;
            mov_Trial(end+1,1)=trialIndexWithinBlock;
            mov_MoveIdx(end+1,1)=moveIndex;
            mov_From{end+1,1}=fromAOI;
            mov_To{end+1,1}=toAOI;
            mov_Class{end+1,1}=classLabel;
            mov_FromPos(end+1,1)=lastPos;
            mov_ToPos(end+1,1)=pos;
            mov_Skipped(end+1,1)=skipped;

            lastAOI = toAOI;
            lastPos = pos;
            skipped = 0;
        end

        if horizontalCount_trial + verticalCount_trial > 0
            trialScanIndex = horizontalCount_trial / ...
                (horizontalCount_trial + verticalCount_trial);
        else
            trialScanIndex = NaN;
        end

        trialResults(globalTrialIndex,:) = ...
            [blockIndex, trialIndexWithinBlock, trialScanIndex,...
             (horizontalCount_trial + verticalCount_trial)];

        trialTransitions(globalTrialIndex)=horizontalCount_trial+verticalCount_trial;
    end

    if horizontalCount_block + verticalCount_block > 0
        blockResults(blockIndex) = horizontalCount_block / ...
            (horizontalCount_block + verticalCount_block);
    else
        blockResults(blockIndex) = NaN;
    end

    blockTransitions(blockIndex)=horizontalCount_block+verticalCount_block;

    fprintf('Block %d: scanIndex = %.5f | #Transitions = %d\n',...
        blockIndex,blockResults(blockIndex),blockTransitions(blockIndex));
end

% ============================================================
% BUILD TABLES
% ============================================================
movementTable = table( ...
    mov_Block,mov_Trial,mov_MoveIdx,...
    string(mov_From),string(mov_To),string(mov_Class),...
    mov_FromPos,mov_ToPos,mov_Skipped,...
    'VariableNames',{'Block','Trial','Move_Index',...
    'From_AOI_Raw','To_AOI_Raw','Classification',...
    'From_Pos_Raw','To_Pos_Raw','Skipped_NaN_Count'});

trialSummaryTable = array2table(trialResults,...
    'VariableNames',{'Block','Trial','ScanIndex','TotalTransitions'});

blockSummaryTable = table((1:numberOfBlocks)',blockResults,blockTransitions,...
    'VariableNames',{'Block','ScanIndex','TotalTransitions'});

% ============================================================
% SAVE
% ============================================================
if ~isempty(saveMatPath)
    save(saveMatPath,'trialResults','blockResults',...
        'movementTable','trialSummaryTable','blockSummaryTable',...
        'trialTransitions','blockTransitions');
end

% ============================================================
% EXPORT CSV
% ============================================================
try
    if ~isempty(saveMatPath)
        [outFolder,~,~] = fileparts(saveMatPath);
        if isempty(outFolder), outFolder = pwd; end
    else
        outFolder = pwd;
    end

    writetable(movementTable,fullfile(outFolder,'movementTable.csv'));
    writetable(trialSummaryTable,fullfile(outFolder,'trialSummaryTable.csv'));
    writetable(blockSummaryTable,fullfile(outFolder,'blockSummaryTable.csv'));

    fprintf('CSV export completed in %s\n',outFolder);
catch ME
    warning('CSV export failed: %s',ME.message);
end

end