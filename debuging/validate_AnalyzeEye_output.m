function report = validate_AnalyzeEye_output(matInput, subject_code, output_directory)
% validate_AnalyzeEye_output
% Produces a diagnostic report verifying that Analyze_eye_func output
% represents trials consistently and without silent loss/misalignment.

    % ---------- 1) Load edfStruct ----------
    if ischar(matInput) || isstring(matInput)
        S = load(matInput);
        assert(isfield(S,'edfStruct'), 'MAT file does not contain edfStruct');
        edfStruct = S.edfStruct;
    elseif isstruct(matInput)
        edfStruct = matInput;
    else
        error('matInput must be path or struct');
    end

    % ---------- 2) Read Fixations CSV ----------
    csvPath = fullfile(output_directory, 'function', [char(string(subject_code)) '.csv']);
    if ~exist(csvPath, 'file')
        error('CSV not found: %s', csvPath);
    end
    Fixations = readcell(csvPath);
    % Normalize empties to NaN for counting
    Fixations(cellfun(@(x) isempty(x) || (isnumeric(x)&&isnan(x)), Fixations)) = {NaN};

    nRows = size(Fixations,1);
    nCols = size(Fixations,2);

    % ---------- 3) Parse FEVENT messages ----------
    msgs = {edfStruct.FEVENT.message};
    stt  = [edfStruct.FEVENT.sttime];

    isTrialMsg = false(size(msgs));
    trialNums  = nan(size(msgs));
    setNums    = nan(size(msgs));

    for i = 1:numel(msgs)
        m = msgs{i};
        if ischar(m) || isstring(m)
            m = char(m);
            if strncmp(m,'TRIAL',5) && ~strcmp(m,'TRIAL END')
                nums = sscanf(m,'TRIAL %d SET %d');
                if numel(nums) >= 2
                    isTrialMsg(i) = true;
                    trialNums(i)  = nums(1);
                    setNums(i)    = nums(2);
                end
            end
        end
    end

    nTrialMsgs = sum(isTrialMsg);

    % Identify Stim/RESP/TIME events (robust startsWith instead of message(1:4))
    isStim = false(size(msgs));
    isRespOrTime = false(size(msgs));
    for i = 1:numel(msgs)
        m = msgs{i};
        if ~(ischar(m) || isstring(m)), continue; end
        m = char(m);
        isStim(i) = strncmp(m,'Stim',4) || strncmp(m,'STIM',4);
        isRespOrTime(i) = strncmp(m,'RESP',4) || strncmp(m,'TIME',4);
    end

    stimIdx = find(isStim);
    endIdx  = find(isRespOrTime);

    % ---------- 4) Check Start/End matchability to FSAMPLE.time ----------
    sampleTime = double(edfStruct.FSAMPLE.time);

    % For each end event, see if there was a stim before it (since last trial boundary)
    % We'll do a simple pairing: most recent Stim before End.
    missingStartBeforeEnd = 0;
    startNotFoundInSamples = 0;
    endNotFoundInSamples   = 0;

    nWindows = 0;
    for k = 1:numel(endIdx)
        iEnd = endIdx(k);
        % most recent stim before this end
        prevStim = stimIdx(stimIdx < iEnd);
        if isempty(prevStim)
            missingStartBeforeEnd = missingStartBeforeEnd + 1;
            continue;
        end
        iStart = prevStim(end);
        nWindows = nWindows + 1;

        stStart = double(stt(iStart));
        stEnd   = double(stt(iEnd));

        % exact match checks (mirrors your code's behavior)
        if ~any(sampleTime == stStart), startNotFoundInSamples = startNotFoundInSamples + 1; end
        if ~any(sampleTime == stEnd),   endNotFoundInSamples   = endNotFoundInSamples + 1; end
    end

    % ---------- 5) Fixations content diagnostics ----------
    % Count non-NaN per row
    nonNanCounts = zeros(nRows,1);
    for r = 1:nRows
        row = Fixations(r,:);
        nonNanCounts(r) = sum(~cellfun(@(x) (isnumeric(x)&&isnan(x)), row));
    end

    nEmptyRows = sum(nonNanCounts == 0);
    nFull20    = sum(nonNanCounts >= 20); % indicates possible truncation if cap is 20

    % Presence of A4/B4
    hasA4 = false(nRows,1);
    hasB4 = false(nRows,1);
    for r = 1:nRows
        row = Fixations(r,:);
        hasA4(r) = any(cellfun(@(x) ischar(x)&&strcmp(x,'A4'), row));
        hasB4(r) = any(cellfun(@(x) ischar(x)&&strcmp(x,'B4'), row));
    end
    nRowsWithA4orB4 = sum(hasA4 | hasB4);

    % ---------- 6) Pack report ----------
    report = struct();
    report.csvPath = csvPath;
    report.nTrialMessages = nTrialMsgs;
    report.nStimEvents = numel(stimIdx);
    report.nRespOrTimeEvents = numel(endIdx);
    report.nStimToEndWindowsApprox = nWindows;

    report.csv_nRows = nRows;
    report.csv_nCols = nCols;

    report.missingStartBeforeEnd = missingStartBeforeEnd;
    report.startNotFoundInSamples_exactMatch = startNotFoundInSamples;
    report.endNotFoundInSamples_exactMatch   = endNotFoundInSamples;

    report.emptyRows = nEmptyRows;
    report.rowsWith20FixationsOrMore = nFull20;
    report.rowsWithA4orB4 = nRowsWithA4orB4;

    % ---------- 7) Print summary ----------
    fprintf('\n=== Analyze_eye_func Validation Report ===\n');
    fprintf('CSV: %s\n', report.csvPath);
    fprintf('TRIAL messages parsed: %d\n', report.nTrialMessages);
    fprintf('Stim events: %d | RESP/TIME events: %d | Approx windows (Stim->End): %d\n', ...
        report.nStimEvents, report.nRespOrTimeEvents, report.nStimToEndWindowsApprox);
    fprintf('CSV rows: %d | cols: %d\n', report.csv_nRows, report.csv_nCols);

    fprintf('\nPotential silent loss / mismatch causes:\n');
    fprintf('- End events without any previous Stim: %d\n', report.missingStartBeforeEnd);
    fprintf('- Start time not found in FSAMPLE.time (exact ==): %d\n', report.startNotFoundInSamples_exactMatch);
    fprintf('- End time not found in FSAMPLE.time (exact ==): %d\n', report.endNotFoundInSamples_exactMatch);

    fprintf('\nFixations output quality:\n');
    fprintf('- Empty rows (no AOI labels at all): %d\n', report.emptyRows);
    fprintf('- Rows hitting cap (>=20 non-NaN) [possible truncation]: %d\n', report.rowsWith20FixationsOrMore);
    fprintf('- Rows containing A4/B4 (indicates Block2/SET2 or mislabel): %d\n', report.rowsWithA4orB4);

    fprintf('=========================================\n\n');
end
