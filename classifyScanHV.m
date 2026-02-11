%%%
function [trialResults, blockResults] = classifyScanHV( ...
    fixationSequences, trialsPerBlock, numberOfBlocks, saveMatPath)
% classifyScanHV
% Offline scanpath classification (horizontal vs vertical)
% using AOI-labeled fixation sequences from Analyze_eye (formerly Analyze_eyeV3).
%
% INPUTS:
%   fixationSequences : cell array (numTrials x maxLen)
%                       Each row = one trial
%                       Each cell = AOI label ('A1','B3',...) or NaN
%
%   trialsPerBlock    : number of trials in each block (e.g., 8 or 100)
%   numberOfBlocks    : number of blocks in the experiment (e.g., 2)
%   saveMatPath       : (optional) file name to save results (.mat)
%
% OUTPUTS:
%   trialResults : matrix [numTrialsUsed x 3]
%                  Columns:
%                   1) blockIndex
%                   2) trialIndexWithinBlock
%                   3) trialScanIndex = horizontal / (horizontal + vertical)
%
%   blockResults : vector [numberOfBlocks x 1]
%                  blockScanIndex = horizontal / (horizontal + vertical)

%% ADDED COMMENT -----------------------------------------------------------
% ScanIndex definition:
%   trialScanIndex = hl / (hl + vl)
% where:
%   hl = #horizontal transitions within the trial (A# <-> B# same row)
%   vl = #vertical transitions within the trial   (A#->A# or B#->B# row change)
%
% IMPORTANT (ignored cases by design):
%   - NaN values represent gaze outside the defined AOIs (e.g., fixation cross) -> ignored
%   - Non A/B labels (e.g., F, A, B, AT*) -> ignored
%   - Repeats (A1->A1) -> ignored
%   - Diagonal transitions (A1->B2) -> ignored
%% ------------------------------------------------------------------------
if nargin < 3
    error('Usage: classifyScanHV(fixationSequences, trialsPerBlock, numberOfBlocks)');
end
if nargin < 4
    saveMatPath = '';
end
if ~iscell(fixationSequences)
    error('fixationSequences must be a cell array (output of Analyze_eye).');
end

% ------------------------------------------------------------
% Determine how many trials will be analyzed
% ------------------------------------------------------------
totalTrialsAvailable = size(fixationSequences, 1);
totalTrialsRequired  = trialsPerBlock * numberOfBlocks;
totalTrialsUsed      = min(totalTrialsAvailable, totalTrialsRequired);

% ------------------------------------------------------------
% Preallocate outputs
% ------------------------------------------------------------
trialResults = nan(totalTrialsUsed, 4);
% columns:
% 1 = blockIndex
% 2 = trialIndexWithinBlock
% 3 = scanIndex
% 4 = nTransitions (hl+vl)blockResults = nan(numberOfBlocks, 1);

%store number of valid transitions
trialTransitions = nan(totalTrialsUsed, 1);   % hl+vl per trial
blockTransitions = nan(numberOfBlocks, 1);    % H+V per block


globalTrialIndex = 0;  % counts trials across the whole experiment 
% globalTrialIndex maps the sequential rows in fixationSequences to
% (blockIndex, trialIndexWithinBlock). This assumes trials are stored in
% order: Block1 trials first, then Block2, etc.

% ------------------------------------------------------------
% Loop over blocks
% ------------------------------------------------------------
for blockIndex = 1:numberOfBlocks

    % Global counters for this block
    % Global counters are per-block (reset here), as required:
    % they accumulate across all trials within the current block only.

    horizontalCount_block = 0;
    verticalCount_block   = 0;

    % --------------------------------------------------------
    % Loop over trials within this block
    % --------------------------------------------------------
    for trialIndexWithinBlock = 1:trialsPerBlock

        globalTrialIndex = globalTrialIndex + 1;
        if globalTrialIndex > totalTrialsUsed
            break;
        end

        % Local counters for this trial
        horizontalCount_trial = 0;
        verticalCount_trial   = 0;

        % Get fixation sequence for this trial
        currentSequence = fixationSequences(globalTrialIndex, :);
        % currentSequence is the AOI label sequence for ONE trial (fixed max length).
        % Many entries may be NaN (e.g., at trial start before gaze enters the table).


        % ----------------------------------------------------
        % Loop over consecutive AOI pairs in the sequence
        % ----------------------------------------------------
        for positionInSequence = 1:(numel(currentSequence) - 1)

            previousAOI = currentSequence{positionInSequence};
            nextAOI     = currentSequence{positionInSequence + 1};

            % Skip if either AOI is NaN:
            % NaN represents gaze outside AOIs (e.g., fixation cross location).

            % Ignore NaN (out-of-AOI, e.g. fixation cross)
            if (isnumeric(previousAOI) && isscalar(previousAOI) && isnan(previousAOI)) || ...
               (isnumeric(nextAOI)     && isscalar(nextAOI)     && isnan(nextAOI))
                continue;
            end


            %Defensive programming:
            % Skip entries that are not text labels (not char/string scalar).
            % Must be text labels
            if ~(ischar(previousAOI) || (isstring(previousAOI) && isscalar(previousAOI))) || ...
               ~(ischar(nextAOI)     || (isstring(nextAOI)     && isscalar(nextAOI)))
                continue;
            end

            previousAOI = char(previousAOI);
            nextAOI     = char(nextAOI);

           
            % Keep only AOIs of the form A# or B# to match the algorithm definition.
            % This automatically ignores headers (F, A, B) and attribute labels (AT*).
            % (\d+) supports multi-digit rows if ever needed (e.g., A10).
            prevTokens = regexp(previousAOI, '^([AB])(\d+)$', 'tokens', 'once');
            nextTokens = regexp(nextAOI,     '^([AB])(\d+)$', 'tokens', 'once');
            if isempty(prevTokens) || isempty(nextTokens)
                continue;
            end

            prevColumn = prevTokens{1};
            prevRow    = str2double(prevTokens{2});
            nextColumn = nextTokens{1};
            nextRow    = str2double(nextTokens{2});

            % Ignore repeated AOI (e.g., A1 -> A1)
            if strcmp(prevColumn, nextColumn) && prevRow == nextRow
                continue;
            end

            % Vertical transition: same column, different row
            if strcmp(prevColumn, nextColumn) && prevRow ~= nextRow
                verticalCount_trial = verticalCount_trial + 1;
                verticalCount_block = verticalCount_block + 1;

            % Horizontal transition: different column, same row
            elseif ~strcmp(prevColumn, nextColumn) && prevRow == nextRow
                horizontalCount_trial = horizontalCount_trial + 1;
                horizontalCount_block = horizontalCount_block + 1;

            % Diagonal or other transitions are ignored
            end
        end

        % ----------------------------------------------------
        % Compute trial scan index
        % ----------------------------------------------------
        if (horizontalCount_trial + verticalCount_trial) > 0
            trialScanIndex = horizontalCount_trial / ...
                            (horizontalCount_trial + verticalCount_trial);
        else
            trialScanIndex = NaN;
        end

        % Store trial result
        trialResults(globalTrialIndex, :) = ...
        [blockIndex, trialIndexWithinBlock, trialScanIndex, ...
        (horizontalCount_trial + verticalCount_trial)];

    
        trialTransitions(globalTrialIndex) = horizontalCount_trial + verticalCount_trial;

    end

    % --------------------------------------------------------
    % Compute block scan index
    % --------------------------------------------------------
    if (horizontalCount_block + verticalCount_block) > 0
        blockResults(blockIndex) = horizontalCount_block / ...
                                  (horizontalCount_block + verticalCount_block);
    else
        blockResults(blockIndex) = NaN;
    end

    blockTransitions(blockIndex) = horizontalCount_block + verticalCount_block;

    fprintf('Block %d: scanIndex = %.5f | #Transitions = %d\n', ...
    blockIndex, blockResults(blockIndex), blockTransitions(blockIndex));



    % --------------------------------------------------------
    % Plot per-trial scan index for this block
    % --------------------------------------------------------

        % --------------------------------------------------------
    % Plot per-trial STRATEGY for this block (separate figure per block)
    % Strategy categories (3):
    %   - No scan     : no valid transitions in trial  (trialTransitions==0 OR scanIndex is NaN)
    %   - Vertical    : scanIndex < 0.5
    %   - Horizontal  : scanIndex > 0.5
    %
    % Visual encoding:
    %   - Each point = one trial (no connecting lines)
    %   - Dot size   ∝ number of valid transitions (evidence strength)
    %   - Dot alpha  ∝ confidence = |scanIndex-0.5| * sqrt(nTransitions)
    % --------------------------------------------------------

    % collect trials of this block (already written into trialResults rows)
    idxBlock = (trialResults(:,1) == blockIndex);

    x = trialResults(idxBlock, 2);          % trial index within block
    p = trialResults(idxBlock, 3);          % scanIndex (NaN possible)
    n = trialTransitions(idxBlock);         % #valid transitions (hl+vl)

    % if no trials were processed for this block (data ended early)
    if isempty(x)
        continue;
    end

    % sort by trial order for clean x-axis
    [x, ord] = sort(x);
    p = p(ord);
    n = n(ord);

    % --- Categorize strategy ---
    % No scan: no evidence (0 transitions) or undefined scanIndex
    noScanMask = (n == 0) | isnan(p);

    % Vertical vs Horizontal (simple split at 0.5)
    isVertical   = (~noScanMask) & (p < 0.5);
    isHorizontal = (~noScanMask) & (p > 0.5);

    % handle exact 0.5 (rare): treat as No scan / ambiguous
    isAmbiguous = (~noScanMask) & (p == 0.5);

    % Create y positions: 1=No scan, 2=Vertical, 3=Horizontal
    y = nan(size(p));
    y(noScanMask | isAmbiguous) = 1;
    y(isVertical)   = 2;
    y(isHorizontal) = 3;

    % --- Dot size encodes evidence strength (#transitions) ---
    % sqrt scaling prevents huge sizes for large n
    dotSize = 40 + 25*sqrt(n);

    % --- Alpha encodes confidence: |p-0.5| weighted by sqrt(n) ---
    conf = abs(p - 0.5) .* sqrt(n);
    conf(noScanMask | isAmbiguous) = 0;

    if max(conf) > 0
        alphaVals = 0.25 + 0.75*(conf / max(conf));  % range [0.25..1]
    else
        alphaVals = 0.25*ones(size(conf));
    end

    % --- Plot ---
    figure; hold on; grid on;

    for i = 1:numel(x)
        h = scatter(x(i), y(i), dotSize(i), 'filled');
        % Alpha reflects confidence (if supported)
        try
            h.MarkerFaceAlpha = alphaVals(i);
            h.MarkerEdgeAlpha = 1;
        catch
            % If MATLAB version doesn't support alpha on scatter, ignore gracefully
        end
    end

    yticks([1 2 3]);
    yticklabels({'No scan','Vertical','Horizontal'});
    xticks(x);
    xlabel(sprintf('Trial index within Block %d', blockIndex));
    title(sprintf('Block %d: Strategy per trial (size=#transitions, alpha=confidence)', blockIndex));

    % Useful block-level info in subtitle
    if ~isnan(blockResults(blockIndex))
        subtitle(sprintf('blockScanIndex = %.3f | blockTransitions = %d', ...
            blockResults(blockIndex), blockTransitions(blockIndex)));
    else
        subtitle(sprintf('blockScanIndex = NaN | blockTransitions = %d', ...
            blockTransitions(blockIndex)));
    end

    xlim([min(x)-0.5, max(x)+0.5]);

    
end

% ------------------------------------------------------------
% Optional saving of results
% ------------------------------------------------------------
if ~isempty(saveMatPath)
    save(saveMatPath, 'trialResults', 'blockResults', ...
         'trialTransitions', 'blockTransitions', ...
         'trialsPerBlock', 'numberOfBlocks');
end

end
