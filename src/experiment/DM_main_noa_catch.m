% Variable Attribute Decision-Making Task.
% Edited version:
% 1. Each block has 103 experimental trials:
%    - 100 regular trials
%    - 3 predefined dominance trials
% 2. Dominance trials appear around thirds of the block using:
%    round(linspace(1, numRegularTrials, numDominanceTrials+2))
% 3. Dominance trials are saved together with the other trials.
% 4. Dominance trials are excluded from regression-weight analysis.

%% ---------- Basic housekeeping --------------------------------
clear;
clc;

rng('shuffle');
% Screen('Preference','SkipSyncTests', 1);

KbName('UnifyKeyNames');
escapeKey = KbName('q');
Calibrate = KbName('c');
spaceKey = KbName('space');

%% ---------- Collect participant information --------------------
subjectDemograph = Demographics;
Subject_Number = str2double(string(subjectDemograph.Subject));

SaveResults = ['Subject_' num2str(Subject_Number) '_Demographics.mat'];
save(SaveResults, 'subjectDemograph');

%% ---------- Psychtoolbox window setup --------------------------
screenNum = 0;
HideCursor;

[wPtr, rect] = Screen('OpenWindow', screenNum, 0);

Black = BlackIndex(wPtr);
White = WhiteIndex(wPtr);

LightGrey = White .* 0.8;
DarkGrey = White .* 0.2;
Grey = [182 182 170];
Red = [White, Black, Black];
Yellow = [White, White, Black];
Green = [Black, White, Black];
Blue = [Black, Black, White];
fontSize = 26;

CenterX = rect(3)/2;
CenterY = rect(4)/2;
Screen('TextFont', wPtr, 'David');
Screen('TextSize', wPtr, 35);

%% ---------- Experiment parameters ------------------------------
numOfSets = 2;
numRegularTrials = 100;
numDominanceTrials = 3;
numOfTrials = numRegularTrials + numDominanceTrials; % 103 experimental trials per block
numOfPractice = 10;
breakTime = 20;
numOfPoints = 0;
imageDuration = 0.5;

% Dominance trial positions, around thirds of the regular-trial range.
% For 100 regular trials and 3 dominance trials this gives [26 51 75].
domExpTrials = round(linspace(1, numRegularTrials, numDominanceTrials + 2));
domExpTrials = domExpTrials(2:end-1);

DominanceTrial = false(numOfSets, numOfTrials);
DominanceTrial(:, domExpTrials) = true;

% Predefined dominance stimuli.
% Each matrix is attributes x alternatives [A B].
DominanceStimuli = cell(numOfSets, numDominanceTrials);

% 3-attribute block
DominanceStimuli{1,1} = [9 1; 8 2; 7 3];       % A dominates B
DominanceStimuli{1,2} = [2 8; 3 9; 1 7];       % B dominates A
DominanceStimuli{1,3} = [9 4; 7 2; 8 5];       % A dominates B

% 4-attribute block
DominanceStimuli{2,1} = [9 1; 9 3; 7 3; 6 4]; % A dominates B
DominanceStimuli{2,2} = [4 9; 3 9; 1 7; 4 6]; % B dominates A
DominanceStimuli{2,3} = [4 9; 2 7; 2 6; 1 6]; % B dominates B

% Response mapping
rightKey = 'k';
leftKey = 'd';

%% ---------- EyeLink initialisation -----------------------------
dummymode = 0; % 0 = real tracker, 1 = dummy mode
el = EyelinkInitDefaults(wPtr);

if ~EyelinkInit(dummymode)
    fprintf('Eyelink Init aborted.\n');
    Screen('CloseAll');
    return
end

if ~dummymode
    edfFile = sprintf('sub_%d.EDF', Subject_Number);
    status = Eyelink('Openfile', edfFile);

    Eyelink('command', 'screen_pixel_coords = 0, 0, 1919, 1079');
    Eyelink('message', 'DISPLAY_COORDS 0 0 1919 1079');
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = YES');

    if status ~= 0
        fprintf('Cannot create EDF file %s\n', edfFile);
        Eyelink('Shutdown');
        Screen('CloseAll');
        return
    end

    EyelinkDoTrackerSetup(el);
    eye_used = Eyelink('EyeAvailable');
end

%% ---------- Pre-allocate major data structures -----------------
Matrix = cell(numOfSets, numOfTrials + numOfPractice);
Correct = nan(numOfSets * (numOfTrials + numOfPractice), 1);
Differences = cell(numOfSets, numOfTrials);
Screen_IDs = nan(numOfSets * (numOfTrials + numOfPractice), 1);
Sub_Acc = nan(numOfSets * numOfTrials, 1);
Time = nan(numOfSets * numOfTrials, 1);
Sub_Choice = nan(numOfSets * numOfTrials, 1);
Trial_Type = strings(numOfSets * numOfTrials, 1); % regular / dominance

Data = cell(1,12);

%% ---------- Generate all stimuli --------------------------------
for setIdx = 1:numOfSets
    nAttr = setIdx + 2;

    for trialIdx = 1:numOfTrials + numOfPractice

        isPractice = trialIdx <= numOfPractice;

        if isPractice
            isDominance = false;
        else
            expTrialIdx = trialIdx - numOfPractice;
            isDominance = DominanceTrial(setIdx, expTrialIdx);
        end

        if isDominance
            domNumber = find(domExpTrials == expTrialIdx);
            Matrix{setIdx, trialIdx} = DominanceStimuli{setIdx, domNumber};
        else
            % Regular trials: exclude equal weighted sums and accidental dominance.
            isInvalid = true;
            while isInvalid
                Matrix{setIdx, trialIdx} = randi(9, nAttr, 2);

                A = Matrix{setIdx, trialIdx}(:,1);
                B = Matrix{setIdx, trialIdx}(:,2);

                weights = (nAttr:-1:1)';
                sums = weights' * Matrix{setIdx, trialIdx};

                equalSums = sums(1) == sums(2);
                accidentalDominance = all(A > B) || all(B > A);

                isInvalid = equalSums || accidentalDominance;
            end
        end

        weights = (nAttr:-1:1)';
        sums = weights' * Matrix{setIdx, trialIdx};

        globalStimIdx = trialIdx + (numOfTrials + numOfPractice) * (setIdx - 1);

        if sums(1) > sums(2)
            Correct(globalStimIdx) = 1;
        else
            Correct(globalStimIdx) = 2;
        end
    end
end

% Pre-compute A-minus-B differences for all experimental trials.
for setIdx = 1:numOfSets
    for trialIdx = 1:numOfTrials
        Differences{setIdx, trialIdx} = ...
            Matrix{setIdx, trialIdx + numOfPractice}(:,1) - ...
            Matrix{setIdx, trialIdx + numOfPractice}(:,2);
    end
end

%% ---------- Table layout and coordinate setup -------------------
TableFrame = [rect(3)/4 rect(4)/4 rect(3)*3/4 rect(4)*3/4];
TableSize = [TableFrame(3)-TableFrame(1) TableFrame(4)-TableFrame(2)];

for setIdx = 1:numOfSets
    nAttr = setIdx + 2;
    CellSize = TableSize ./ [3 nAttr+1];

    for col = 1:3
        for row = 1:nAttr+1
            if nAttr == 3
                ThreeAttCells{row,col} = [TableFrame(1:2) + CellSize.*[col-1 row-1], ...
                    TableFrame(1:2) + CellSize.*[col-1 row-1] + CellSize];
            elseif nAttr == 4
                FourAttCells{row,col} = [TableFrame(1:2) + CellSize.*[col-1 row-1], ...
                    TableFrame(1:2) + CellSize.*[col-1 row-1] + CellSize];
            end
        end
    end
end

feedbackY = rect(4) - 80;
continueY = rect(4) - 40;

%% ---------- Pre-render off-screen stimuli screens ---------------
for setIdx = 1:numOfSets
    nAttr = setIdx + 2;

    if nAttr == 3
        layout = ThreeAttCells;
    else
        layout = FourAttCells;
    end

    frameRectX1 = layout{1,1}(1);
    frameRectY1 = layout{1,1}(2);
    frameRectX2 = layout{end,end}(3);
    frameRectY2 = layout{end,end}(4);

    verticalLine1X1 = layout{1,1}(3);
    verticalLine1Y1 = layout{1,1}(2);
    verticalLine1X2 = layout{1,1}(3);
    verticalLine1Y2 = layout{end,1}(4);

    verticalLine2X1 = layout{1,2}(3);
    verticalLine2Y1 = layout{1,2}(2);
    verticalLine2X2 = layout{1,2}(3);
    verticalLine2Y2 = layout{end,2}(4);

    for trialIdx = 1:numOfTrials + numOfPractice
        listIdx = trialIdx + (numOfTrials + numOfPractice) * (setIdx - 1);

        offPtr = Screen('OpenOffscreenWindow', wPtr, 0);
        Screen_IDs(listIdx) = offPtr;

        Screen('FrameRect', offPtr, Yellow, [frameRectX1 frameRectY1 frameRectX2 frameRectY2], 3);

        for row = 1:nAttr
            horizontalLineX1 = layout{row,1}(1);
            horizontalLineY1 = layout{row,1}(4);
            horizontalLineX2 = layout{row,end}(3);
            horizontalLineY2 = layout{row,end}(4);
            Screen('DrawLine', offPtr, Yellow, horizontalLineX1, horizontalLineY1, horizontalLineX2, horizontalLineY2, 5);
        end

        Screen('DrawLine', offPtr, Yellow, verticalLine1X1, verticalLine1Y1, verticalLine1X2, verticalLine1Y2, 5);
        Screen('DrawLine', offPtr, Yellow, verticalLine2X1, verticalLine2Y1, verticalLine2X2, verticalLine2Y2, 5);

        Screen('TextFont', offPtr, 'Times New Roman');
        Screen('TextSize', offPtr, fontSize);

        if setIdx == 1
            labelTxt = {'intelligence - 3'; 'work ethic - 2'; 'easy to work with - 1'};
        elseif setIdx == 2
            labelTxt = {'intelligence - 4'; 'work ethic - 3'; 'easy to work with - 2'; 'creativity - 1'};
        end

        for row = 1:numel(labelTxt)
            textBounds = Screen('TextBounds', offPtr, labelTxt{row});
            textWidth = textBounds(3) - textBounds(1);
            textX = layout{row+1,1}(1) + CellSize(1)/2 - textWidth/2;
            textY = layout{row+1,1}(2) + CellSize(2)/2;
            DrawFormattedText(offPtr, labelTxt{row}, textX, textY, Green);
        end

        Screen('TextSize', offPtr, fontSize + 10);

        textBounds = Screen('TextBounds', offPtr, 'A');
        textWidth = textBounds(3) - textBounds(1);
        textX = layout{1,2}(1) + CellSize(1)/2 - textWidth/2;
        textY = layout{1,2}(2) + CellSize(2)/2;
        DrawFormattedText(offPtr, 'A', textX, textY, Red);

        textBounds = Screen('TextBounds', offPtr, 'B');
        textWidth = textBounds(3) - textBounds(1);
        textX = layout{1,3}(1) + CellSize(1)/2 - textWidth/2;
        textY = layout{1,3}(2) + CellSize(2)/2;
        DrawFormattedText(offPtr, 'B', textX, textY, Red);

        vals = Matrix{setIdx, trialIdx};
        for row = 1:nAttr
            valStr = num2str(vals(row,1));
            textBounds = Screen('TextBounds', offPtr, valStr);
            textWidth = textBounds(3) - textBounds(1);
            textX = layout{row+1,2}(1) + CellSize(1)/2 - textWidth/2;
            textY = layout{row+1,2}(2) + CellSize(2)/2;
            DrawFormattedText(offPtr, valStr, textX, textY, Green);

            valStr = num2str(vals(row,2));
            textBounds = Screen('TextBounds', offPtr, valStr);
            textWidth = textBounds(3) - textBounds(1);
            textX = layout{row+1,3}(1) + CellSize(1)/2 - textWidth/2;
            textY = layout{row+1,3}(2) + CellSize(2)/2;
            DrawFormattedText(offPtr, valStr, textX, textY, Green);
        end
    end
end

%% ---------- Instruction screens --------------------------------
Screen('FillRect', wPtr, 0);

Screen1 = imread('instructions/Instruction1.png');
tex1 = Screen('MakeTexture', wPtr, Screen1);
Screen('DrawTexture', wPtr, tex1);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

Screen2 = imread('instructions/Instruction2.png');
tex2 = Screen('MakeTexture', wPtr, Screen2);
Screen('DrawTexture', wPtr, tex2);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

Screen3 = imread('instructions/Instruction3.png');
tex3 = Screen('MakeTexture', wPtr, Screen3);
Screen('DrawTexture', wPtr, tex3);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

%% ---------- Pre-defined feedback strings -----------------------
msgCorrect = 'Correct';
msgIncorrect = 'Incorrect';
msgTooSlow = 'Too slow!';
msgContinue = 'Press SPACE to continue';

%% ============================================================== 
% Start main experiment loop
try
    for setIdx = 1:numOfSets

        switch setIdx
            case 1
                stoper = 3;
                instrImg = 'instructions/Instruction4.png';
            case 2
                stoper = 4;
                instrImg = 'instructions/Instruction5.png';
        end

        tex = Screen('MakeTexture', wPtr, imread(instrImg));
        Screen('FillRect', wPtr, 0);
        Screen('DrawTexture', wPtr, tex);
        Screen('Flip', wPtr);
        KbWait; WaitSecs(imageDuration);

        %% Practice trials
        for pracIdx = 1:numOfPractice
            trialGlobal = pracIdx + (numOfTrials + numOfPractice) * (setIdx - 1);

            Eyelink('message','Fix Cross Practice');
            fixationShown = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White, Calibrate, el);
            Screen('TextSize', wPtr, 30);

            logic = false;

            Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
            [~, stimOnset] = Screen('Flip', wPtr);
            FlushEvents('keyDown');

            while ~logic
                [~, ~, keyCode] = KbCheck;
                if keyCode(escapeKey)
                    if ~dummymode
                        Eyelink('CloseFile');
                        Eyelink('Shutdown');
                    end
                    Screen('CloseAll');
                    ShowCursor;
                    return;
                end

                if (GetSecs - stimOnset) > stoper
                    Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                    DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]);
                    Screen('Flip', wPtr);
                    WaitSecs(1);
                    break;
                end

                [~, keyTime, keyCode] = KbCheck;
                Practice_RT = keyTime - stimOnset;
                keyNameCell = KbName(keyCode);
                isSingleKey = ischar(keyNameCell);

                if isSingleKey
                    keyName = keyNameCell;
                    logic = strcmp(keyName, leftKey) || strcmp(keyName, rightKey);
                end

                if logic
                    if strcmp(keyName, leftKey)
                        resp = 1;
                    else
                        resp = 2;
                    end

                    Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                    if Correct(trialGlobal) == resp
                        DrawFormattedText(wPtr, msgCorrect, 'center', feedbackY, [0 255 0]);
                    else
                        DrawFormattedText(wPtr, msgIncorrect, 'center', feedbackY, [255 0 0]);
                    end
                    DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                    Screen('Flip', wPtr);

                    while 1
                        [~, ~, keyCode] = KbCheck;
                        if keyCode(spaceKey)
                            break;
                        elseif keyCode(Calibrate)
                            if ~dummymode
                                EyelinkDoTrackerSetup(el);
                            end
                        elseif keyCode(escapeKey)
                            if ~dummymode
                                Eyelink('CloseFile');
                                Eyelink('Shutdown');
                            end
                            Screen('CloseAll');
                            ShowCursor;
                            return;
                        end
                    end
                    WaitSecs(0.2);
                end
            end

            if ~logic
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]);
                DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                Screen('Flip', wPtr);

                while 1
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(spaceKey)
                        break;
                    elseif keyCode(Calibrate)
                        if ~dummymode
                            EyelinkDoTrackerSetup(el);
                        end
                    end
                end
                WaitSecs(0.2);
            end

            Screen('Close', Screen_IDs(trialGlobal));
        end

        %% Transition screen before experimental trials
        texPracEnd = Screen('MakeTexture', wPtr, imread('instructions/exp.jpg'));
        Screen('FillRect', wPtr, 0);
        Screen('DrawTexture', wPtr, texPracEnd);
        Screen('Flip', wPtr);
        KbWait; WaitSecs(imageDuration);

        %% Experimental trials: 100 regular + 3 dominance
        for trial = 1:numOfTrials
            trialGlobal = numOfPractice + trial + (numOfTrials + numOfPractice) * (setIdx - 1);
            trialIdxLinear = trial + numOfTrials * (setIdx - 1);

            if DominanceTrial(setIdx, trial)
                Trial_Type(trialIdxLinear) = "dominance";
            else
                Trial_Type(trialIdxLinear) = "regular";
            end

            Eyelink('message','Fix Cross Experimental');
            fixationShown = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White, Calibrate, el);
            Screen('TextSize', wPtr, 30);

            logic = false;

            if ~dummymode
                Eyelink('message', sprintf('TRIAL %d SET %d START', trial, setIdx));
            end

            Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
            if ~dummymode
                Eyelink('StartRecording');
                Eyelink('message','Stimulus ON');
            end

            [~, stimOnset] = Screen('Flip', wPtr);
            FlushEvents('keyDown');

            while ~logic
                [~, ~, keyCode] = KbCheck;
                if keyCode(escapeKey)
                    if ~dummymode
                        Eyelink('StopRecording');
                        Eyelink('CloseFile');
                        Eyelink('Shutdown');
                    end
                    Screen('CloseAll');
                    ShowCursor;
                    return;
                end

                % Keep the stimulus visible while collecting response.
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                Screen('Flip', wPtr);

                if (GetSecs - stimOnset) > stoper
                    if ~dummymode
                        Eyelink('message','TIMEOUT');
                        Eyelink('message','TRIAL END');
                        Eyelink('StopRecording');
                    end

                    Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                    DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]);
                    DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                    Screen('Flip', wPtr);

                    while 1
                        [~, ~, keyCode] = KbCheck;
                        if keyCode(spaceKey)
                            break;
                        elseif keyCode(Calibrate)
                            if ~dummymode
                                EyelinkDoTrackerSetup(el);
                            end
                        end
                    end
                    WaitSecs(0.2);
                    break;
                end

                [~, keyTime, keyCode] = KbCheck;
                RT = keyTime - stimOnset;
                keyNameCell = KbName(keyCode);
                isSingleKey = ischar(keyNameCell);

                if isSingleKey
                    keyName = keyNameCell;
                    logic = strcmp(keyName, leftKey) || strcmp(keyName, rightKey);
                end

                if logic
                    if strcmp(keyName, leftKey)
                        resp = 1;
                        if ~dummymode
                            Eyelink('message','RESPONSE LEFT');
                        end
                    else
                        resp = 2;
                        if ~dummymode
                            Eyelink('message','RESPONSE RIGHT');
                        end
                    end

                    if ~dummymode
                        Eyelink('message', sprintf('RT %.3f', RT));
                        Eyelink('message','TRIAL END');
                        Eyelink('StopRecording');
                    end

                    Sub_Choice(trialIdxLinear) = resp;
                    Sub_Acc(trialIdxLinear) = Correct(trialGlobal) == resp;
                    Time(trialIdxLinear) = RT;

                    Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                    if Sub_Acc(trialIdxLinear)
                        DrawFormattedText(wPtr, msgCorrect, 'center', feedbackY, [0 255 0]);
                        numOfPoints = numOfPoints + 1;
                    else
                        DrawFormattedText(wPtr, msgIncorrect, 'center', feedbackY, [255 0 0]);
                    end

                    DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                    Screen('Flip', wPtr);

                    while 1
                        [~, ~, keyCode] = KbCheck;
                        if keyCode(spaceKey)
                            break;
                        elseif keyCode(Calibrate)
                            if ~dummymode
                                EyelinkDoTrackerSetup(el);
                            end
                        end
                    end
                    WaitSecs(0.2);
                end
            end

            Screen('Close', Screen_IDs(trialGlobal));

            if mod(trial, breakTime) == 0 && trial ~= numOfTrials
                texBreak = Screen('MakeTexture', wPtr, imread('instructions/break.jpg'));
                Screen('FillRect', wPtr, 0);
                Screen('DrawTexture', wPtr, texBreak);
                Screen('Flip', wPtr);
                KbWait; WaitSecs(2 * imageDuration);
                if ~dummymode
                    EyelinkDoDriftCorrection(el, CenterX, CenterY);
                end
            end

            % Incremental save. This saves all experimental trials, including dominance trials.
            Data{1}{1} = 'The correct alternatives';
            Data{1}{2} = Correct(1:trialGlobal);

            Data{2}{1} = 'Subject''s response pattern';
            Data{2}{2} = Sub_Choice(1:trialIdxLinear);

            Data{3}{1} = 'Subject''s accuracy on each trial';
            Data{3}{2} = Sub_Acc(1:trialIdxLinear);

            Data{4}{1} = 'Subject''s RT on each trial';
            Data{4}{2} = Time(1:trialIdxLinear);

            Data{5}{1} = 'The stimuli presented on each trial, including practice and dominance trials';
            for s = 1:setIdx
                if s < setIdx
                    lastTrialInSet = numOfTrials + numOfPractice;
                else
                    lastTrialInSet = trial + numOfPractice;
                end

                for t = 1:lastTrialInSet
                    Data{5}{t + 1 + (numOfTrials + numOfPractice) * (s - 1)} = Matrix{s,t};
                end
            end

            Data{12}{1} = 'Trial type for experimental trials only: regular or dominance';
            Data{12}{2} = Trial_Type(1:trialIdxLinear);

            save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat', Subject_Number), 'Data', ...
                'Trial_Type', 'DominanceTrial', 'DominanceStimuli', 'domExpTrials', ...
                'numRegularTrials', 'numDominanceTrials', 'numOfTrials');
        end

        %% Block-level summaries: regular trials only
        regularIdxThisSet = find(~DominanceTrial(setIdx, :));
        trialsThisSet = regularIdxThisSet + numOfTrials * (setIdx - 1);
        valid = ~isnan(Sub_Acc(trialsThisSet));

        switch setIdx
            case 1
                Data{6}{1} = 'Subject''s accuracy for 3 attributes, regular trials only';
                Data{6}{2} = mean(Sub_Acc(trialsThisSet(valid)));
                Data{7}{1} = 'Subject''s average RT, 3 attributes, regular trials only';
                Data{7}{2} = mean(Time(trialsThisSet(valid)));
            case 2
                Data{8}{1} = 'Subject''s accuracy for 4 attributes, regular trials only';
                Data{8}{2} = mean(Sub_Acc(trialsThisSet(valid)));
                Data{9}{1} = 'Subject''s average RT, 4 attributes, regular trials only';
                Data{9}{2} = mean(Time(trialsThisSet(valid)));
        end

        save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat', Subject_Number), 'Data', ...
            'Trial_Type', 'DominanceTrial', 'DominanceStimuli', 'domExpTrials', ...
            'numRegularTrials', 'numDominanceTrials', 'numOfTrials');
    end

    try
        fprintf('Calculating decision weights for supervisor report...\n');

        %% ---------- Post-experiment model fit --------------------
        Subject_Choice = Sub_Choice;
        Subject_Choice(Subject_Choice == 2) = 0;

        % Logistic weights for 3-attribute block: exclude dominance trials.
        Data{10}{1} = 'The weights for 3 attributes, regular trials only';
        regularIdx3 = find(~DominanceTrial(1, :));
        linearIdx3 = regularIdx3;
        ok3 = ~isnan(Sub_Acc(linearIdx3));

        Diff_3 = cell2mat(Differences(1, regularIdx3(ok3)))';
        [weights3, ~, ~] = glmfit(Diff_3, Subject_Choice(linearIdx3(ok3)), 'binomial');

        for k = 1:3
            Data{10}{k+1} = weights3(k+1);
        end

        % Logistic weights for 4-attribute block: exclude dominance trials.
        Data{11}{1} = 'The weights for 4 attributes, regular trials only';
        regularIdx4 = find(~DominanceTrial(2, :));
        linearIdx4 = numOfTrials + regularIdx4;
        ok4 = ~isnan(Sub_Acc(linearIdx4));

        Diff_4 = cell2mat(Differences(2, regularIdx4(ok4)))';
        [weights4, ~, ~] = glmfit(Diff_4, Subject_Choice(linearIdx4(ok4)), 'binomial');

        for k = 1:4
            Data{11}{k+1} = weights4(k+1);
        end

        save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat', Subject_Number), 'Data', ...
            'Trial_Type', 'DominanceTrial', 'DominanceStimuli', 'domExpTrials', ...
            'numRegularTrials', 'numDominanceTrials', 'numOfTrials');
    catch
        fprintf('There was an error with the weighting analysis.\n')
    end

    %% ---------- Goodbye screen -------------------------------------
    texEnd = Screen('MakeTexture', wPtr, imread('instructions/end.jpg'));
    Screen('FillRect', wPtr, 0);
    Screen('DrawTexture', wPtr, texEnd);
    Screen('Flip', wPtr);
    KbWait; WaitSecs(2 * imageDuration);

catch ME
    fprintf('\n----------------------------------------\n');
    fprintf('CRASH DETECTED! Attempting to rescue data...\n');
    fprintf('Error Message: %s\n', ME.message);

    try
        CrashSaveName = sprintf('Subject_%d_CRASH_BACKUP.mat', Subject_Number);
        save(CrashSaveName, 'Data', 'Trial_Type', 'DominanceTrial', 'DominanceStimuli', 'domExpTrials', ...
            'numRegularTrials', 'numDominanceTrials', 'numOfTrials');
        fprintf('>> SUCCESS: Behavioral data saved to: %s\n', CrashSaveName);
    catch
        fprintf('>> FAILED to save behavioral data.\n');
    end

    if ~dummymode
        try
            Eyelink('StopRecording');
            Eyelink('CloseFile');
            fprintf('>> Retrieving EDF file from EyeLink Host PC...\n');
            status = Eyelink('ReceiveFile');
            if status > 0
                fprintf('>> SUCCESS: EDF file rescued!\n');
            else
                fprintf('>> WARNING: EDF file transfer failed (status=%d).\n', status);
            end
            Eyelink('Shutdown');
        catch
            fprintf('>> FAILED to communicate with EyeLink during crash.\n');
        end
    end

    Screen('CloseAll');
    ShowCursor;
    fprintf('----------------------------------------\n');
    rethrow(ME);
end

%% ---------- EyeLink shutdown & file transfer -------------------
if ~dummymode
    Eyelink('CloseFile');
    status = Eyelink('ReceiveFile');
    if status > 0
        fprintf('Data file received: %s\n', edfFile);
    else
        fprintf('Error receiving data file.\n');
    end
    Eyelink('Shutdown');
end

%% ---------- Convert EDF to MAT and save eye-tracking data -------
edfFile = sprintf('sub_%d.EDF', Subject_Number);
SaveEDF = fullfile('Eyedata', sprintf('Subject_%d_eyeData', Subject_Number));

if ~exist('Eyedata', 'dir')
    mkdir('Eyedata');
end

fprintf('Converting %s to MAT structure...\n', edfFile);
edfStruct = edfmex(edfFile);
save(SaveEDF, 'edfStruct');
fprintf(' EDF successfully converted and saved: %s.mat\n', SaveEDF);

%% ---------- Clean up and restore desktop -----------------------
Screen('CloseAll');
ShowCursor;

%% ---------- Fixation Verification Function --------------------
function fixationVerified = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White, Calibrate, el)

    fixationVerified = false;
    radius = 100;
    requiredDuration = 0.3;
    startFix = NaN;
    feedbackShown = false;

    fixX = CenterX;
    fixY = rect(4) * 0.15;

    if ~dummymode
        Eyelink('StartRecording');
        WaitSecs(0.1);
    end

    while ~fixationVerified

        Screen('FillRect', wPtr, 0);
        Screen('TextSize', wPtr, 75);
        DrawFormattedText(wPtr, '+', fixX, fixY, White);

        if feedbackShown
            Screen('TextSize', wPtr, 30);
            DrawFormattedText(wPtr, 'Please look at the cross', 'center', rect(4)-150, White);
        end

        Screen('Flip', wPtr);

        if ~dummymode
            if Eyelink('NewFloatSampleAvailable') > 0
                evt = Eyelink('NewestFloatSample');
                eye_used = Eyelink('EyeAvailable');

                if eye_used == 2
                    eye_idx = 2;
                else
                    eye_idx = eye_used + 1;
                end

                gx = evt.gx(eye_idx);
                gy = evt.gy(eye_idx);

                if gx > 0 && gy > 0 && gx ~= -32768 && gy ~= -32768
                    dist = sqrt((gx - fixX)^2 + (gy - fixY)^2);

                    if dist < radius
                        if isnan(startFix)
                            startFix = GetSecs;
                        elseif (GetSecs - startFix) >= requiredDuration
                            fixationVerified = true;
                            feedbackShown = false;
                            Eyelink('message','FIXATION VERIFIED');
                        end
                    else
                        startFix = NaN;
                        feedbackShown = true;
                    end
                end
            end
        else
            WaitSecs(requiredDuration);
            fixationVerified = true;
        end

        [~, ~, keyCode] = KbCheck;
        if keyCode(escapeKey)
            if ~dummymode
                Eyelink('StopRecording');
                Eyelink('CloseFile');
                Eyelink('Shutdown');
            end
            Screen('CloseAll');
            ShowCursor;
            fixationVerified = -1;
            return;
        elseif keyCode(Calibrate)
            if ~dummymode
                Eyelink('StopRecording');
                EyelinkDoTrackerSetup(el);
                Eyelink('StartRecording');
                WaitSecs(0.1);
                startFix = NaN;
            end
        end
    end

    if ~dummymode
        Eyelink('StopRecording');
    end
end
