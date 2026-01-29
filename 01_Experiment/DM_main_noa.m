
% Variable Attribute Decision-Making Task.
% Presents paired alternative "candidates" (A vs. B) described on
% 3/4 subjective attributes:
% block 1 (intelligence, work ethic, easy to work with)
% block 2 (intelligence, work ethic, easy to work with, creativity).
% Each attribute has a different importance weight,
%   influencing the participant's decision-making strategy.
% Participant selects the alternative they prefer on each trial.
% Implements practice and experimental blocks, variable set size,
% adaptive timing, performance feedback, and EyeLink recording.
% Saves demographic data, trial-level behavio ur, accuracy,
% reaction times, and fitted logistic regression weights that
% approximate each participant's attribute importance.
%
% Major Dependencies
% 
% - Psychtoolbox 3 for stimulus presentation and response collection
% - EyeLink Toolbox for eye-tracking integration:Eyelink II 5.12 EyeLink 1000 Plus

% - Author: noa moshe
% - Version: (Updated 26 / 1 2026)
% This version does not have yellow dot trace debugging - this is commented out by %
 

%% ---------- Basic housekeeping --------------------------------
% Skip sync tests **ONLY** when precise timing is not required
% (e.g., debugging on non-lab laptops). Remove for final data
% collection on lab machines that have been properly calibrated.
clear; % clear workspace
clc; % clear command window

rng('shuffle'); % randomise the seed based on system clock
%Screen('Preference','SkipSyncTests', 1);

% Disable accidental termination via Ctrl-C (ASCII decimal 46 = '.')
% DisableKeysForKbCheck(46);

% Set up escape key 'q' for emergency exit
KbName('UnifyKeyNames');
escapeKey = KbName('q');

%% ---------- Collect participant information --------------------
% Call a custom function that collects and returns a struct with
% demographic fields (participant number, age, gender, handedness, etc.)
subjectDemograph = Demographics;
Subject_Number = str2double(string(subjectDemograph.Subject));
% Save demographics immediately to guard against data loss later
SaveResults = ['Subject_' num2str(Subject_Number) '_Demographics.mat'];
save(SaveResults, 'subjectDemograph');

%% ---------- Psychtoolbox window setup --------------------------
screenNum = 0; % 0 = main display
HideCursor; % hide mouse pointer

%  Open full-screen BLACK window (0 = black)
 [wPtr, rect] = Screen('OpenWindow', screenNum, 0); % 0 = black background

% for debbug :  
%[wPtr, rect] = Screen('OpenWindow', screenNum, 0, [100 100 1400 900]);

% Store some convenience values
Black = BlackIndex(wPtr);
White = WhiteIndex(wPtr);
% Custom colors (RGB)

LightGrey = White.*0.8;
DarkGrey = White.*0.2;
Grey=[182 182 170];
Red=[White, Black, Black];
Yellow=[White, White, Black];
Green=[Black, White, Black];
Blue=[Black, Black, White];
fontSize = 26;
% rect=[0 0 1920 1080];

CenterX = rect(3)/2;
CenterY = rect(4)/2;
Screen('TextFont', wPtr, 'David'); % default font used in Hebrew labs
Screen('TextSize', wPtr, 35);

%% ---------- Experiment parameters ------------------------------
numOfSets = 2; % 3-attribute and 4-attribute blocks
numOfTrials = 8; % trials per block = 100
numOfPractice = 1; % warm-up trials per block = 10
breakTime = 2; % trials between mandatory breaks = 25
numOfPoints = 0;
imageDuration = 0.5; % minimum exposure for static images (sec)

% Response mapping (customise to your keyboard layout)
rightKey = 'k';
leftKey = 'd';



%% ---------- EyeLink initialisation -----------------------------
dummymode = 0; % 0 = real tracker; 1 = keyboard-only dummy mode
el = EyelinkInitDefaults(wPtr); % configure default colours, keys, etc.

if ~EyelinkInit(dummymode)
    fprintf('Eyelink Init aborted.\n');
    Screen('CloseAll');
    return
end

% Open an EDF file on the host PC to store gaze data
if ~dummymode
    edfFile = sprintf('sub_%d.EDF', Subject_Number);
    status = Eyelink('Openfile', edfFile);
    % Immediately after opening the link:
    %% I add
    % ---  I ADD THESE LINES: Define screen coordinate system ---
    Eyelink('command', 'screen_pixel_coords = 0, 0, 1919, 1079');
    Eyelink('message', 'DISPLAY_COORDS 0 0 1919 1079');

    % Optional I ADD : set calibration target style (for clarity)
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = YES');
%%
    if status ~= 0
        fprintf('Cannot create EDF file %s\n', edfFile);
        Eyelink('Shutdown');
        Screen('CloseAll');
        return
    end

    % Run automatic calibration/validation UI
    EyelinkDoTrackerSetup(el);
    eye_used = Eyelink('EyeAvailable'); %#ok<NASGU>
end

%% Pre-allocate major data structures
Matrix = cell(numOfSets, numOfTrials+numOfPractice); % raw stimuli
Correct = nan(numOfSets*(numOfTrials+numOfPractice),1); % 1 = A, 2 = B
Differences = cell(numOfSets, numOfTrials); % A-B attribute diff
Screen_IDs = nan(numOfSets*(numOfTrials+numOfPractice),1); % off-screen ptrs
Sub_Acc = nan(numOfSets*numOfTrials,1); % accuracy (0/1)
Time = nan(numOfSets*numOfTrials,1); % RTs (sec)
Sub_Choice = nan(numOfSets*numOfTrials,1); % 1 = A, 2 = B

% Cell array "Data" progressively collects everything to be saved
% Indexing: {row}{column}. Each row = one "sheet".
Data = cell(1,11);

%% ---------- Generate all stimuli (practice + trials) -----------
% Each stimulus is a matrix of size (attributes ֳ— 2 alternatives)
% with integers [1 9]. Attribute weights descend 3-1 (block 1)
% or 4-1 (block 2). 
% The *higher* weighted sum is the objectively correct choice.

for setIdx = 1:numOfSets
    nAttr = setIdx + 2; % 3 or 4 attributes
    for trialIdx = 1:numOfTrials+numOfPractice
        % Keep sampling until weighted sums differ
        isEqual = true;
        while isEqual
            Matrix{setIdx, trialIdx} = randi(9, nAttr, 2);
            weights = (nAttr:-1:1)'; % column vector [3;2;1] or [4;3;2;1]
            sums = weights' * Matrix{setIdx, trialIdx}; % Fix size mismatch
            isEqual = sums(1) == sums(2);
        end
        
        % Store correct side (1 = left/A, 2 = right/B)
        if sums(1) > sums(2)
            Correct(trialIdx + (numOfTrials+numOfPractice)*(setIdx-1)) = 1;
        else
            Correct(trialIdx + (numOfTrials+numOfPractice)*(setIdx-1)) = 2;
        end
    end
end

% Pre-compute A-minus-B difference vectors for later logistic fit
for setIdx = 1:numOfSets
    for trialIdx = 1:numOfTrials
        Differences{setIdx, trialIdx} = ...
            Matrix{setIdx, trialIdx+numOfPractice}(:,1) - ...
            Matrix{setIdx, trialIdx+numOfPractice}(:,2);
    end
end

%% ---------- Table layout and coordinate setup (dynamic centering) ----------

TableFrame= [rect(3)/4 rect(4)/4 rect(3)*3/4 rect(4)*3/4];
TableSize = [TableFrame(3)-TableFrame(1) TableFrame(4)-TableFrame(2)];
for setIdx = 1:numOfSets
    nAttr = setIdx + 2; % 3 or 4 attributes
    CellSize = TableSize./[3 nAttr+1];
    for col=1:3
        for row=1:nAttr+1
            if nAttr==3
                ThreeAttCells{row,col} = [TableFrame(1:2)+CellSize.*[col-1 row-1], TableFrame(1:2)+CellSize.*[col-1 row-1]+CellSize]; 
            elseif nAttr==4
                FourAttCells{row,col} = [TableFrame(1:2)+CellSize.*[col-1 row-1], TableFrame(1:2)+CellSize.*[col-1 row-1]+CellSize];          
            end
        end
    end
end
feedbackY = rect(4) - 80;  
continueY = rect(4) - 40;

%% ---------- Pre-render off-screen stimuli screens --------------
% Rendering once greatly reduces per-trial drawing overhead.
for setIdx = 1:numOfSets
    nAttr = setIdx + 2;
    if nAttr==3
        layout = ThreeAttCells;
    else layout = FourAttCells;
    end

    frameRectX1=layout{1,1}(1);  
    frameRectY1=layout{1,1}(2);
    frameRectX2=layout{end,end}(3);  
    frameRectY2=layout{end,end}(4);  

    verticalLine1X1=layout{1,1}(3);
    verticalLine1Y1=layout{1,1}(2);
    verticalLine1X2=layout{1,1}(3);
    verticalLine1Y2=layout{end,1}(4);
    
     verticalLine2X1=layout{1,2}(3);
    verticalLine2Y1=layout{1,2}(2);
    verticalLine2X2=layout{1,2}(3);
    verticalLine2Y2=layout{end,2}(4);

    for trialIdx = 1:numOfTrials+numOfPractice
        listIdx = trialIdx + (numOfTrials+numOfPractice)*(setIdx-1);
        
        % Black background for offscreen windows
        offPtr = Screen('OpenOffscreenWindow', wPtr, 0); % 0 = black
        Screen_IDs(listIdx) = offPtr;
        
      
        
        % Outer rectangle - properly sized for number of attributes
        Screen('FrameRect', offPtr, Yellow, ...
            [frameRectX1 frameRectY1 frameRectX2 frameRectY2], 3);
        
        
        % Horizontal lines (one per attribute row)
        for row = 1:nAttr
            horizontalLineX1 = layout{row,1}(1);
            horizontalLineY1 = layout{row,1}(4);
            horizontalLineX2 = layout{row,end}(3);
            horizontalLineY2 = layout{row,end}(4);
            Screen('DrawLine', offPtr, Yellow, ...
                horizontalLineX1,horizontalLineY1, horizontalLineX2, horizontalLineY2, 5);
        end
        
        % Two vertical dividers
        Screen('DrawLine', offPtr, Yellow, ...
            verticalLine1X1, verticalLine1Y1, verticalLine1X2,verticalLine1Y2, 5);
        Screen('DrawLine', offPtr, Yellow, ...
            verticalLine2X1, verticalLine2Y1, verticalLine2X2,verticalLine2Y2, 5);
        
        %% Attribute labels (left column) - CENTERED
        Screen('TextFont', offPtr, 'Times New Roman');
        Screen('TextSize', offPtr, fontSize);
        
        if setIdx == 1 % 3 attributes
            labelTxt = {'intelligence - 3' ; ...
                'work ethic - 2' ; ...
                'easy to work with - 1'};
        elseif setIdx == 2 % 4 attributes
            labelTxt = {'intelligence - 4' ; ...
                'work ethic - 3' ; ...
                'easy to work with - 2' ; ...
                'creativity - 1'};
        end
        
        for row = 1:numel(labelTxt)
            % Center text in cells
            textBounds = Screen('TextBounds', offPtr, labelTxt{row});
            textWidth = textBounds(3) - textBounds(1);
            textX = layout{row+1,1}(1) + CellSize(1)/2 - textWidth/2;
            textY = layout{row+1,1}(2) +CellSize(2)/2 ;%- fontSize/2;
            DrawFormattedText(offPtr, labelTxt{row}, textX, textY, Green);
        end
        
        %% Column headers "A" and "B" - CENTERED
        Screen('TextSize', offPtr, fontSize+10);
        
        % Center "A"
        textBounds = Screen('TextBounds', offPtr, 'A');
        textWidth = textBounds(3) - textBounds(1);
         textX = layout{1,2}(1) + CellSize(1)/2 - textWidth/2;
         textY = layout{1,2}(2) +CellSize(2)/2 ;%- fontSize/2;
        DrawFormattedText(offPtr, 'A', textX, textY, Red);
        
        % Center "B"
        textBounds = Screen('TextBounds', offPtr, 'B');
        textWidth = textBounds(3) - textBounds(1);
        textX = layout{1,3}(1) + CellSize(1)/2 - textWidth/2;
        textY = layout{1,3}(2) +CellSize(2)/2 ;%- fontSize/2;
        DrawFormattedText(offPtr, 'B', textX, textY, Red);        
        
        %% Numeric attribute ratings - CENTERED
        vals = Matrix{setIdx, trialIdx};
        for row = 1:nAttr
            % Center value A
            valStr = num2str(vals(row,1));
            textBounds = Screen('TextBounds', offPtr, valStr);
            textWidth = textBounds(3) - textBounds(1);
             textX = layout{row+1,2}(1) + CellSize(1)/2 - textWidth/2;
             textY = layout{row+1,2}(2) +CellSize(2)/2 ;%- fontSize/2;
             DrawFormattedText(offPtr, valStr, textX, textY, Green);
            
            % Center value B
            valStr = num2str(vals(row,2));
            textBounds = Screen('TextBounds', offPtr, valStr);
            textWidth = textBounds(3) - textBounds(1);
            textX = layout{row+1,3}(1) + CellSize(1)/2 - textWidth/2;
         textY = layout{row+1,3}(2) +CellSize(2)/2 ;%- fontSize/2;
        DrawFormattedText(offPtr, valStr, textX, textY, Green);        
        end
    end
end

%% ---------- Instruction screens --------------------------------
Screen('FillRect', wPtr, 0); % Black background
% Instruction 1
Screen1 = imread('Instruction1.png');
tex1 = Screen('MakeTexture', wPtr, Screen1);
Screen('DrawTexture', wPtr, tex1);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

% Instruction 2
Screen2 = imread('Instruction2.png');
tex2 = Screen('MakeTexture', wPtr, Screen2);
Screen('DrawTexture', wPtr, tex2);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

% Instruction 3
Screen3 = imread('Instruction3.png');
tex3 = Screen('MakeTexture', wPtr, Screen3);
Screen('DrawTexture', wPtr, tex3);
Screen('Flip', wPtr);
KbWait; WaitSecs(imageDuration);

%% ---------- Pre-defined feedback strings -----------------------
msgCorrect = 'Correct';
msgIncorrect = 'Incorrect';
msgTooSlow = 'Too slow!';
msgScore = 'Your score is: ';
msgContinue = 'Press SPACE to continue';

%% ==============================================================
% **Start main experiment loop**

for setIdx = 1:numOfSets
    % ------------------------------------------------------------
    % 1. Show block-specific instructions.
    % ------------------------------------------------------------
    switch setIdx
        case 1, stoper = 3; instrImg = 'Instruction4.png'; % 3 attributes
        case 2, stoper = 4; instrImg = 'Instruction5.png'; % 4 attributes
    end
    
    tex = Screen('MakeTexture', wPtr, imread(instrImg));
    Screen('FillRect', wPtr, 0); % Black background
    Screen('DrawTexture', wPtr, tex);
    Screen('Flip', wPtr);
    KbWait; WaitSecs(imageDuration);
    
    %% Practice trials (immediate feedback, *no scoring, *NO RECORDING)
    % ------------------------------------------------------------
    for pracIdx = 1:numOfPractice
        trialGlobal = pracIdx + (numOfTrials+numOfPractice)*(setIdx-1);
        
        % Show fixation cross with eye tracking check
        Eyelink('message','Fix Cross Practice');
        fixationShown = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White);
        Screen('TextSize', wPtr, 30); % Reset text size
        
        logic = false; % until a valid key is pressed
        StartSecs = GetSecs;
        
        % NO EyeLink recording for practice

        Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr); %%% Is this the stimuli display? %%%
        [~, stimOnset] = Screen('Flip', wPtr);  % stimOnset = time stimulus first appears
        FlushEvents('keyDown');  % clear any previous keypresses

        while ~logic
            % Check for emergency exit
            [~, ~, keyCode] = KbCheck;
            if keyCode(escapeKey)
                if ~dummymode
                    % Eyelink('StopRecording'); %%% why is there "stop recording" here? where is the "start recording"? %%%

                    Eyelink('CloseFile');
                    Eyelink('Shutdown');
                end
                Screen('CloseAll');
                ShowCursor;
                return;
            end
            
            
            
            % Check for timeout
            if (GetSecs - stimOnset) > stoper
                % Show feedback on same screen with table
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]); % Red text
                Screen('Flip', wPtr);
                WaitSecs(1);
                break;
            end
            
            % --- Poll keyboard ---
            [~, keyTime, keyCode] = KbCheck;
            Practice_RT = keyTime - stimOnset; %  FIXED RT: measured from real stimulus onset
            isSingleKey = (isscalar(KbName(keyCode)));
            
            if isSingleKey
                keyName = KbName(keyCode);
                logic = strcmp(keyName,leftKey) || strcmp(keyName,rightKey);
            end
            
            if logic % ----- valid response registered -----
                if strcmp(keyName,leftKey)
                    resp = 1;
                else
                    resp = 2;
                end
                
                % Feedback on same screen with table
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                if Correct(trialGlobal) == resp
                    DrawFormattedText(wPtr, msgCorrect, 'center', feedbackY, [0 255 0]); % Green
                else
                    DrawFormattedText(wPtr, msgIncorrect, 'center', feedbackY, [255 0 0]); % Red
                end
                DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                Screen('Flip', wPtr);
                
                % Wait for ENTER key
                while 1
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(KbName('space'))
                        break;
                    elseif keyCode(escapeKey)
                        % Emergency exit
                        if ~dummymode
                            % Eyelink('StopRecording'); %%% again another stop recording without start recording before %%%
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
        
        % Handle timeout case
        if ~logic
            % Already showed "Too slow!" feedback
            Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
            DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]); % Red text
            DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
            Screen('Flip', wPtr);
            
            % Wait for key
            while 1
                [~, ~, keyCode] = KbCheck;
                if keyCode(KbName('space'))
                    break;
                end
            end
            WaitSecs(0.2);
        end
        
        % Free this off-screen buffer (saves VRAM)
        Screen('Close', Screen_IDs(trialGlobal));
    end % practice loop
    
    %% ------------------------------------------------------------
    % 3. Transition screen before True trials
    texPracEnd = Screen('MakeTexture', wPtr, imread('exp.jpg'));
    Screen('FillRect', wPtr, 0); % Black background
    Screen('DrawTexture', wPtr, texPracEnd);
    Screen('Flip', wPtr);
    KbWait; WaitSecs(imageDuration);
    
    %% ------------------------------------------------------------
    % 4. Experimental trials (scored + logged)

    for trial = 1:numOfTrials
        trialGlobal = numOfPractice + trial + ...
            (numOfTrials+numOfPractice)*(setIdx-1);
        
        % Calculate linear index for this trial (needed for data saving)
        trialIdxLinear = trial + numOfTrials*(setIdx-1);
        
        %  Show fixation cross with eye tracking check
        
        Eyelink('message','Fix Cross Experimental');
      
        fixationShown = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White);

        Screen('TextSize', wPtr, 30); % Reset text size
        
        logic = false;
        StartSecs = GetSecs;
        

        %  Start recording for this trial
        if ~dummymode
            Eyelink('message', sprintf('TRIAL %d SET %d START', trial, setIdx));
        end
        
        % === Show stimulus ONCE before response loop ===
        Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
         if ~dummymode
          Eyelink('StartRecording'); % Start only after fixation verified %%% why you have start recording here and in the CheckFixation function?%%%
          Eyelink('message','Stimulus ON'); %%% this shoould come before your flip command, also you didnt start recording %%%
         end

        [~, stimOnset] = Screen('Flip', wPtr);

 

        FlushEvents('keyDown');  % clear any previous key presses

        % === Start timing and key collection loop ===

        while ~logic
            % Check for emergency exit
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
            

% NEW  --- Draw stimulus + gaze point ---
Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);

if ~dummymode
    % ׳§׳'׳?׳× ׳"׳'׳™׳?׳" ׳—׳"׳©׳" ׳?׳?׳¢׳¨׳›׳× ׳"׳¢׳™׳ ׳™׳™׳?
    evt = Eyelink('newestfloatsample');

    % ׳?׳? ׳?׳™׳? ׳"׳'׳™׳?׳" ׳×׳§׳™׳ ׳" ג€" ׳?׳"׳?׳'׳™׳? ׳¢׳? ׳¦׳™׳•׳¨ ׳"׳ ׳§׳•׳"׳"
    if isempty(evt) || ~isstruct(evt) || ...
       ~isfield(evt,'gx') || ~isfield(evt,'gy')
       
        % ׳?׳'׳¦׳¢׳™׳? Flip ׳¨׳§ ׳?׳"׳¦׳'׳× ׳"׳'׳™׳¨׳•׳™
        Screen('Flip', wPtr);
        continue;
    end

    gazeX = evt.gx(1);
    gazeY = evt.gy(1);

    % ׳¦׳™׳•׳¨ ׳"׳ ׳§׳•׳"׳" ׳"׳¦׳"׳•׳'׳"
    dotSize = 20;
    Yellow = [255 255 0];

    gazeRect = [gazeX - dotSize/2, ...
                gazeY - dotSize/2, ...
                gazeX + dotSize/2, ...
                gazeY + dotSize/2];

    %Screen('FillOval', wPtr, Yellow, gazeRect);
end

Screen('Flip', wPtr);

            % Timeout
            if (GetSecs - stimOnset) > stoper
                % Stop recording before feedback
                if ~dummymode
                    Eyelink('message','TIMEOUT');
                    Eyelink('message','TRIAL END');
                    Eyelink('StopRecording');
                end
                
                %  Show feedback on same screen with continue prompt
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                DrawFormattedText(wPtr, msgTooSlow, 'center', feedbackY, [255 0 0]);
                DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                Screen('Flip', wPtr);
                
                % Wait for space key
                while 1
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(KbName('space'))
                        break;
                    end
                end
                WaitSecs(0.2);
                break;
            end
            
            % --- Poll keyboard ---
            [~, keyTime, keyCode] = KbCheck;
            RT = keyTime - stimOnset; %  FIXED RT: measured from real stimulus onset
            isSingleKey = (length(KbName(keyCode))==1);
            
            if isSingleKey
                keyName = KbName(keyCode);
                logic = strcmp(keyName,leftKey) || strcmp(keyName,rightKey);
            end
            
            if logic
                % Determine response
                 if strcmp(keyName,leftKey)
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
                    % STOP RECORDING IMMEDIATELY AFTER RESPONSE
                    Eyelink('message','TRIAL END');
                    Eyelink('StopRecording');
                 end
                
                  
                
                % Save per-trial data
                trialIdxLinear = trial + numOfTrials*(setIdx-1);
                Sub_Choice(trialIdxLinear) = resp;
                Sub_Acc(trialIdxLinear) = Correct(trialGlobal) == resp;
                Time(trialIdxLinear) = RT;
                
                % Feedback on same screen (NO SCORE DISPLAY)
                Screen('CopyWindow', Screen_IDs(trialGlobal), wPtr);
                if Sub_Acc(trialIdxLinear)
                    DrawFormattedText(wPtr, msgCorrect, 'center', feedbackY, [0 255 0]);
                    numOfPoints = numOfPoints + 1;
                else
                    DrawFormattedText(wPtr, msgIncorrect, 'center', feedbackY, [255 0 0]);
                end
                
                % Show continue prompt together with feedback
                DrawFormattedText(wPtr, msgContinue, 'center', continueY, White);
                Screen('Flip', wPtr);
                
                % Wait for space key
                while 1
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(KbName('space'))
                        break;
                    end
                end
                WaitSecs(0.2);
            end
        end % response loop
        
        % Close rendered stimulus to free memory
        Screen('Close', Screen_IDs(trialGlobal));
        
        % -------------------- Scheduled break ------------------
        if mod(trial, breakTime)==0 && trial~=numOfTrials
            % No recording during break
            texBreak = Screen('MakeTexture', wPtr, imread('break.jpg'));
            Screen('FillRect', wPtr, 0); % Black background
            Screen('DrawTexture', wPtr, texBreak);
            Screen('Flip', wPtr);
            KbWait; WaitSecs(2*imageDuration);
        end
        
        % -------------------- Incremental save -----------------
        % Build cell array "Data" for safety
        Data{1}{1} = 'The correct alternatives';
        Data{1}{2} = Correct(1:trialGlobal);
        
        Data{2}{1} = 'Subject''s response pattern';
        Data{2}{2} = Sub_Choice(1:trialIdxLinear);
        
        Data{3}{1} = 'Subject''s accuracy on each trial';
        Data{3}{2} = Sub_Acc(1:trialIdxLinear);
        
        Data{4}{1} = 'Subject''s RT on each trial';
        Data{4}{2} = Time(1:trialIdxLinear);
        
        Data{5}{1} = 'The stimuli presented on each trial';
        for s = 1:setIdx
            lastTrialInSet = (s<setIdx) * (numOfTrials+numOfPractice) + ...
                (s==setIdx) * (trial+numOfPractice);
            for t = 1:lastTrialInSet
                Data{5}{t+1+(numOfTrials+numOfPractice)*(s-1)} = Matrix{s,t};
            end
        end
        
        % Write to disk
        save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat',...
            Subject_Number), 'Data');
    end % experimental trial loop
    
    
    % ------------------------------------------------------------
    % 5. Compute block-level summary (mean ACC, mean RT)
    % ------------------------------------------------------------
    trialsThisSet = (1:numOfTrials) + numOfTrials*(setIdx-1);
    valid = ~isnan(Sub_Acc(trialsThisSet));
    
    switch setIdx
        case 1
            Data{6}{1} = 'Subject''s accuracy for 3 attributes';
            Data{6}{2} = mean(Sub_Acc(trialsThisSet(valid)));
            Data{7}{1} = 'Subject''s average RT, 3 attributes';
            Data{7}{2} = mean(Time(trialsThisSet(valid)));
        case 2
            Data{8}{1} = 'Subject''s accuracy for 4 attributes';
            Data{8}{2} = mean(Sub_Acc(trialsThisSet(valid)));
            Data{9}{1} = 'Subject''s average RT, 4 attributes';
            Data{9}{2} = mean(Time(trialsThisSet(valid)));
    end
    
    % Re-save file with updated block summary
    save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat',...
        Subject_Number), 'Data');
    
end

%% ---------- Post-experiment model fit --------------------------
% Convert choices into binary (1 = choose A, 0 = choose B)
Subject_Choice = Sub_Choice;
Subject_Choice(Subject_Choice==2) = 0;

% ----------- Logistic weights for 3-attribute block -------------
Data{10}{1} = 'The weights for 3 attributes';
trials3 = 1:numOfTrials;
ok3 = ~isnan(Sub_Acc(trials3));
Diff_3 = cell2mat(Differences(1, ok3))'; % n ֳ— 3
[weights3, ~, ~] = glmfit(Diff_3, Subject_Choice(trials3(ok3)), 'binomial');
for k = 1:3, Data{10}{k+1} = weights3(k+1); end % omit intercept

% ----------- Logistic weights for 4-attribute block -------------
Data{11}{1} = 'The weights for 4 attributes';
trials4 = (numOfTrials+1):(2*numOfTrials);
ok4 = ~isnan(Sub_Acc(trials4));
Diff_4 = cell2mat(Differences(2, ok4))'; % n ֳ— 4
[weights4,~,~] = glmfit(Diff_4, Subject_Choice(trials4(ok4)), 'binomial');
for k = 1:4, Data{11}{k+1} = weights4(k+1); end

% Save final dataset (overwriting earlier incremental versions)
save(sprintf('Subject_%d_Results_Decision_Strategy_Experiment.mat',...
    Subject_Number), 'Data');

%% ---------- Goodbye screen -------------------------------------
texEnd = Screen('MakeTexture', wPtr, imread('end.jpg'));
Screen('FillRect', wPtr, 0); % Black background
Screen('DrawTexture', wPtr, texEnd);
Screen('Flip', wPtr);
KbWait; WaitSecs(2*imageDuration);

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

%% ---------- Convert EDF to MAT and save eye-tracking data ----------
edfFile = sprintf('sub_%d.EDF', Subject_Number);
SaveEDF = fullfile('Eyedata', sprintf('Subject_%d_eyeData', Subject_Number));

% Ensure the destination folder exists
if ~exist('Eyedata', 'dir')
    mkdir('Eyedata');
end

fprintf('Converting %s to MAT structure...\n', edfFile);
edfStruct = edfmex(edfFile);
save(SaveEDF, 'edfStruct');
fprintf(['' ...
    ' EDF successfully converted and saved: %s.mat\n'], SaveEDF);


%% ---------- Clean up and restore desktop -----------------------
Screen('CloseAll');
ShowCursor;


%% ---------- Fixation Verification Function --------------------

function fixationVerified = CheckFixation(wPtr, rect, dummymode, escapeKey, CenterX, CenterY, White)

    fixationVerified = false;
    radius = 100;
    requiredDuration = 0.3;
    startFix = NaN;
    feedbackShown = false;

    % === NEW: fixation location (top-center) ===
    fixX = CenterX;
    fixY = rect(4) * 0.15;     % 15% from top of screen

    if ~dummymode
        Eyelink('StartRecording');
        WaitSecs(0.1);
    end

    while ~fixationVerified

        Screen('FillRect', wPtr, 0);

        % === NEW: smaller fixation cross ===
        Screen('TextSize', wPtr, 75);    % reduced by 50%
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
                if eye_used == 2, eye_idx = 2; else, eye_idx = eye_used + 1; end

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

        [~,~,keyCode] = KbCheck;
        if keyCode(escapeKey)
            if ~dummymode 
                Eyelink('StopRecording'); Eyelink('CloseFile'); Eyelink('Shutdown');
            end
            Screen('CloseAll'); ShowCursor;
            fixationVerified = -1;
            return;
        end
    end

    if ~dummymode
        Eyelink('StopRecording');
    end
end
