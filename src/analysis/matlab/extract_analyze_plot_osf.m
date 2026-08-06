% Behavioral and eye-tracking analyses for Experiments 1 and 2
%
% Required inputs:
%   Subject_<ID>_Results_Decision_Strategy_Experiment.mat
%   trial_results_summary_exp1.csv
%   trial_results_summary_exp2.csv
%   Exp1_2_detailed/*.csv
%
% Block 1 contains three attributes; Block 2 contains four.

%% 1. Behavioral data and decision-strategy classification
clear; clc

dataDir = pwd;
behavioralDataDir = fullfile(dataDir,'jc data');
detailedDataDir = fullfile(dataDir,'Exp1_2_detailed');

filePrefix = 'Subject_';
fileSuffix = '_Results_Decision_Strategy_Experiment.mat';

subjects = setdiff([101:140, 201:244], [205, 208, 221, 240]);
isExp1 = subjects < 200;
isExp2 = subjects >= 200;

numOfSubjects = numel(subjects);
numTrialsExp1 = 100;
numTrialsExp2 = 103;
numOfPractice = 10;
data_strategy_class_3 = [];
data_strategy_class_4 = [];
accuracy_3_trial_long = [];
accuracy_4_trial_long = [];
consistency_long_3 = [];
consistency_long_4 = [];
stimuli_differences_3_long = [];
stimuli_differences_4_long = [];
sub_response_3_long = [];
sub_response_4_long = [];
md_RT3 = nan(numOfSubjects,1);
md_RT4 = nan(numOfSubjects,1);
md_ic_RT3 = nan(numOfSubjects,1);
md_ic_RT4 = nan(numOfSubjects,1);
acc3 = nan(numOfSubjects,1);
acc4 = nan(numOfSubjects,1);
weights_3 = nan(numOfSubjects,4);
weights_4 = nan(numOfSubjects,5);

for i = 1:numOfSubjects
    subjNum = subjects(i);
    if isExp1(i)
        numOfTrials = numTrialsExp1;
    else
        numOfTrials = numTrialsExp2;
    end

    file_madm = fullfile(behavioralDataDir, ...
        [filePrefix, num2str(subjNum), fileSuffix]);
    load(file_madm);

    stimuli_differences_3 = nan(numOfTrials,3);
    stimuli_differences_4 = nan(numOfTrials,4);
    for j = 1:numOfTrials
        stimuli_differences_3(j,:) = (Data{1,5}{1,j+numOfPractice+1}(:,1)...
            -Data{1,5}{1,j+numOfPractice+1}(:,2))';
        stimuli_differences_4(j,:) = (Data{1,5}{1,j+2*numOfPractice+numOfTrials+1}(:,1)...
            -Data{1,5}{1,j+2*numOfPractice+numOfTrials+1}(:,2))';
    end
    stimuli_differences_3_long = [stimuli_differences_3_long;stimuli_differences_3];
    stimuli_differences_4_long = [stimuli_differences_4_long;stimuli_differences_4];
    subject_response_3 = Data{1,2}{1,2}(1:numOfTrials);
    subject_response_4 = Data{1,2}{1,2}(numOfTrials+1:2*numOfTrials);
    response_3 = subject_response_3;
    response_4 = subject_response_4;
    sub_response_3_long = [sub_response_3_long;response_3];
    sub_response_4_long = [sub_response_4_long;response_4];

    accuracy_3_trial = Data{1,3}{1,2}(1:numOfTrials);
    accuracy_4_trial = Data{1,3}{1,2}(numOfTrials+1:2*numOfTrials);

    RT_trial_3 = Data{1,4}{1,2}(1:numOfTrials);
    RT_trial_4 = Data{1,4}{1,2}(numOfTrials+1:2*numOfTrials);

    % Exclude trials without corresponding eye-tracking data.
    accuracy_4_trial_d = accuracy_4_trial;
    if subjNum == 217
        accuracy_4_trial(33) = [];
    end
    if subjNum == 229
        accuracy_4_trial(53) = [];
    end
    accuracy_3_trial_long = [accuracy_3_trial_long;accuracy_3_trial];
    accuracy_4_trial_long = [accuracy_4_trial_long;accuracy_4_trial];
    accuracy_4_trial = accuracy_4_trial_d;

    slowTrials_3 = isnan(subject_response_3);
    slowTrials_4 = isnan(subject_response_4);

    subject_response_3 = subject_response_3(~slowTrials_3);
    subject_response_4 = subject_response_4(~slowTrials_4);
    accuracy_3_trial = accuracy_3_trial(~slowTrials_3);
    accuracy_4_trial = accuracy_4_trial(~slowTrials_4);
    RT_trial_3 = RT_trial_3(~slowTrials_3);
    RT_trial_4 = RT_trial_4(~slowTrials_4);

    md_RT3(i) = median(RT_trial_3);
    md_RT4(i) = median(RT_trial_4);
    acc3(i) = mean(accuracy_3_trial);
    acc4(i) = mean(accuracy_4_trial);

    % Build trial-level arrays for strategy classification.
    subs3 = i*ones(sum(~slowTrials_3),1);
    subs4 = i*ones(sum(~slowTrials_4),1);
    dummy_WApredictions3 = Data{1,1}{1,2}(numOfPractice+1:numOfTrials+numOfPractice);
    wav_prediction_3 = dummy_WApredictions3;
    dummy_WApredictions3 = dummy_WApredictions3(~slowTrials_3);
    dummy_WApredictions4 = Data{1,1}{1,2}(numOfTrials+2*numOfPractice+1:end);
    wav_prediction_4 = dummy_WApredictions4;
    dummy_WApredictions4 = dummy_WApredictions4(~slowTrials_4);
    
    % TTB selects according to the first nonzero attribute difference.
    dummy_TTBpredictions3 = nan(numOfTrials,1);
    for c = 1:numOfTrials
        k = 1;
        while k <= 3
            if stimuli_differences_3(c,k) > 0
                dummy_TTBpredictions3(c) = 1;
                k = 6;
            elseif stimuli_differences_3(c,k) < 0
                dummy_TTBpredictions3(c) = 2;
                k = 6;
            else
                k = k + 1;
            end
        end
    end
    ttb_prediction_3 = dummy_TTBpredictions3;
    dummy_TTBpredictions3 = dummy_TTBpredictions3(~slowTrials_3);

    dummy_TTBpredictions4 = nan(numOfTrials,1);
    for c = 1:numOfTrials
        k = 1;
        while k <= 4
            if stimuli_differences_4(c,k) > 0
                dummy_TTBpredictions4(c) = 1;
                k = 6;
            elseif stimuli_differences_4(c,k) < 0
                dummy_TTBpredictions4(c) = 2;
                k = 6;
            else
                k = k + 1;
            end
        end
    end
    ttb_prediction_4 = dummy_TTBpredictions4;
    dummy_TTBpredictions4 = dummy_TTBpredictions4(~slowTrials_4);

    consistency_3 = ttb_prediction_3 == wav_prediction_3;
    consistency_4 = ttb_prediction_4 == wav_prediction_4;

    % Apply the same trial exclusions to all variables merged with eye-tracking data.
    if subjNum == 217
        consistency_4(33) = [];
        response_4(33) = [];
        ttb_prediction_4(33) = [];
        wav_prediction_4(33) = [];
    end
    if subjNum == 229
        consistency_4(53) = [];
        response_4(53) = [];
        ttb_prediction_4(53) = [];
        wav_prediction_4(53) = [];
    end

    consistency_long_3 = [consistency_long_3;consistency_3];
    consistency_long_4 = [consistency_long_4;consistency_4];

    consistent_trials_3 = dummy_TTBpredictions3 == dummy_WApredictions3;
    data_strategy_class_3 = [data_strategy_class_3;subs3,consistent_trials_3,...
        accuracy_3_trial];
    consistent_trials_4 = dummy_TTBpredictions4 == dummy_WApredictions4;
    data_strategy_class_4 = [data_strategy_class_4;subs4,consistent_trials_4,...
        accuracy_4_trial];

    md_ic_RT3(i) = median(RT_trial_3(~consistent_trials_3));
    md_ic_RT4(i) = median(RT_trial_4(~consistent_trials_4));

    % Estimate participant-specific attribute weights using logistic regression.
    subject_response_3(subject_response_3 == 2) = 0;
    subject_response_4(subject_response_4 == 2) = 0;
    stimuli_differences_3 = stimuli_differences_3(~slowTrials_3,:);
    stimuli_differences_4 = stimuli_differences_4(~slowTrials_4,:);
    weights_3(i,:) = glmfit(stimuli_differences_3,...
        subject_response_3, 'binomial')';
    weights_4(i,:) = glmfit(stimuli_differences_4,...
        subject_response_4, 'binomial')';
end

NW_3 = weights_3(:,2:end)./sum(weights_3(:,2:end),2);
NW_4 = weights_4(:,2:end)./sum(weights_4(:,2:end),2);

% WAV score is the proportion of choices matching WAV on trials where
% WAV and TTB make different predictions; scores >= .5 define WAV users.
subjects_strategy_3 = nan(numOfSubjects,1);
wav_scores_3 = nan(numOfSubjects,1);
for i = 1:numOfSubjects
    wav_scores_3(i) = mean(data_strategy_class_3(data_strategy_class_3(:,1) == i & ~data_strategy_class_3(:,2),3));
    subjects_strategy_3(i) = wav_scores_3(i)>=0.5;
end

subjects_strategy_4 = nan(numOfSubjects,1);
wav_scores_4 = nan(numOfSubjects,1);
for i = 1:numOfSubjects
    wav_scores_4(i) = mean(data_strategy_class_4(data_strategy_class_4(:,1) == i & ~data_strategy_class_4(:,2),3));
    subjects_strategy_4(i) = wav_scores_4(i)>=0.5;
end

data_pooled = [data_strategy_class_3;data_strategy_class_4];
subjects_strategy_pooled = nan(numOfSubjects,1);
wav_scores_pooled = nan(numOfSubjects,1);
for i = 1:numOfSubjects
    wav_scores_pooled(i) = mean(data_pooled(data_pooled(:,1) == i & ~data_pooled(:,2),3));
    subjects_strategy_pooled(i) = wav_scores_pooled(i)>=0.5;
end

%% 2. Import trial-level eye-tracking data
T_eye_exp1 = readtable(fullfile(dataDir,'trial_results_summary_exp1.csv'));
T_eye_exp2 = readtable(fullfile(dataDir,'trial_results_summary_exp2.csv'));
T_eye = [T_eye_exp1;T_eye_exp2];
T_eye(T_eye{:,1} == 1 | T_eye{:,1} == 205, :) = []; % Exclude Exp. 1 subject 1 and Exp. 2 subject 205
block_type = T_eye{:,2};
sub_eye_3 = T_eye{block_type == 1,1};
% Convert the horizontal-scan proportion to a vertical (1-horizontal = vertical) index ranging from -1 to 1.
vertical_index_3 = 2*(1 - T_eye{block_type == 1,7}) - 1;
sub_eye_4 = T_eye{block_type == 2,1};
vertical_index_4 = 2*(1 - T_eye{block_type == 2,7}) - 1;

t_3_eye = table( ...
    sub_eye_3, vertical_index_3, accuracy_3_trial_long, consistency_long_3, ...
    'VariableNames',{'subject','vertical_index','acc','consistency'});

t_4_eye = table( ...
    sub_eye_4, vertical_index_4, accuracy_4_trial_long, consistency_long_4, ...
    'VariableNames',{'subject','vertical_index','acc','consistency'});

T_eye_pooled = [t_3_eye; t_4_eye];

%% 3. Compute participant-level vertical index
% Calculate the proportion of vertical transitions and rescale it to [-1, 1].
for i = 1:numOfSubjects
    VI_pooled(i) = sum(T_eye{ T_eye{:,1} == subjects(i),5})/sum(T_eye{ T_eye{:,1} == subjects(i),6});
    VI_3(i) = sum(T_eye{ T_eye{:,1} == subjects(i) & T_eye{:,2} == 1 ,5})/...
        sum(T_eye{ T_eye{:,1} == subjects(i) & T_eye{:,2} == 1,6});
    VI_4(i) = sum(T_eye{ T_eye{:,1} == subjects(i) & T_eye{:,2} == 2 ,5})/...
        sum(T_eye{ T_eye{:,1} == subjects(i) & T_eye{:,2} == 2,6});
end
VI_pooled = 2*VI_pooled-1;
VI_3 = 2*VI_3-1;%Block 1
VI_4 = 2*VI_4-1;%Block 2

%% 4. Figure 2: Strategy consistency and vertical-index associations
% Panels A-B show cross-block consistency; Panels C-D show the association between vertical index and WAV score.

figure( ...
    'Color','w', ...
    'Position',[100 100 850 750]);

tiledlayout(2,2, ...
    'TileSpacing','tight', ...
    'Padding','compact');

% A. Behavioral compensatory tendency

ax1 = nexttile;
hold(ax1,'on');

x = wav_scores_3(isExp1);
y = wav_scores_4(isExp1);

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

[r1,p1] = corr(x,y);

mdl1 = fitlm(x,y);

xFit1 = linspace(min(x),max(x),100)';
[yFit1,yCI1] = predict(mdl1,xFit1);

fill(ax1, ...
    [xFit1; flipud(xFit1)], ...
    [yCI1(:,1); flipud(yCI1(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax1,x,y,45,'filled', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax1,xFit1,yFit1, ...
    'k-', ...
    'LineWidth',1.8);

text(ax1,0.05,0.93, ...
    sprintf('r = %.2f**',r1), ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax1,'WAV score (3 attributes)');
ylabel(ax1,'WAV score (4 attributes)');

xlim(ax1,[0 1]);
ylim(ax1,[0 1]);

set(ax1, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(ax1,-0.15,1.06,'A', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

% B. Eye-scan vertical-index consistency

ax2 = nexttile;
hold(ax2,'on');

x = VI_3(isExp1)';
y = VI_4(isExp1)';

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

[r2,p2] = corr(x,y);

mdl2 = fitlm(x,y);

xFit2 = linspace(min(x),max(x),100)';
[yFit2,yCI2] = predict(mdl2,xFit2);

fill(ax2, ...
    [xFit2; flipud(xFit2)], ...
    [yCI2(:,1); flipud(yCI2(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax2,x,y,45,'filled', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax2,xFit2,yFit2, ...
    'k-', ...
    'LineWidth',1.8);

text(ax2,0.05,0.93, ...
    sprintf('r = %.2f**',r2), ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax2,'Vertical index (3 attributes)');
ylabel(ax2,'Vertical index (4 attributes)');


xlim(ax2,[-.9 0.4]);
ylim(ax2,[-.9 0.4]);

set(ax2, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(ax2,-0.15,1.06,'B', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

% C. Vertical index and WAV score: Experiment 1

ax3 = nexttile;
hold(ax3,'on');

x = VI_pooled(isExp1)';
y = wav_scores_pooled(isExp1);

x = x(:);
y = y(:);

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

[r3,p3] = corr(x,y);

mdl3 = fitlm(x,y);

xFit3 = linspace(min(x),max(x),100)';
[yFit3,yCI3] = predict(mdl3,xFit3);

fill(ax3, ...
    [xFit3; flipud(xFit3)], ...
    [yCI3(:,1); flipud(yCI3(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax3,x,y,45,'filled', ...
    'MarkerFaceColor','r', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax3,xFit3,yFit3, ...
    'k-', ...
    'LineWidth',1.8);

text(ax3,0.05,0.93, ...
    sprintf('r = %.2f**',r3), ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax3,'Vertical index');
ylabel(ax3,'WAV score');

xlim(ax3,[-0.9 0.3]);
ylim(ax3,[0 1]);

set(ax3, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(ax3,-0.15,1.06,'C', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

% D. Vertical index and WAV score: Experiment 2

ax4 = nexttile;
hold(ax4,'on');

x = VI_pooled(isExp2)';
y = wav_scores_pooled(isExp2);

x = x(:);
y = y(:);

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

[r4,p4] = corr(x,y);

mdl4 = fitlm(x,y);

xFit4 = linspace(min(x),max(x),100)';
[yFit4,yCI4] = predict(mdl4,xFit4);

fill(ax4, ...
    [xFit4; flipud(xFit4)], ...
    [yCI4(:,1); flipud(yCI4(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax4,x,y,45,'filled', ...
    'MarkerFaceColor','r', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax4,xFit4,yFit4, ...
    'k-', ...
    'LineWidth',1.8);

text(ax4,0.05,0.93, ...
    sprintf('r = %.2f**',r4), ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax4,'Vertical index');
ylabel(ax4,'WAV score');

xlim(ax4,[-0.9 0.3]);
ylim(ax4,[0 1]);

set(ax4, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(ax4,-0.15,1.06,'D', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

%% 5. Extract trial-level number of fixations
folderPath = detailedDataDir;
files = dir(fullfile(folderPath, '*.csv'));

allData = table();

for i = 1:numel(files)
    T = readtable(fullfile(files(i).folder, files(i).name));

    requiredVars = {'Subject','Block','Trial','FixationSeq'};

    assert(all(ismember(requiredVars, T.Properties.VariableNames)), ...
        'Missing required variables in file: %s', files(i).name);

    allData = [allData; T(:, requiredVars)];

end

% Exclude the two Block 2 trials missing from the eye-tracking records.
remove_rows = ...
    (allData.Subject == 217 & allData.Block == 2 & allData.Trial == 33) | ...
    (allData.Subject == 229 & allData.Block == 2 & allData.Trial == 53);

allData(remove_rows,:) = [];

[G, Subject, Block, Trial] = findgroups( ...
    allData.Subject, ...
    allData.Block, ...
    allData.Trial);

% The maximum FixationSeq value gives the number of fixations in a trial.
num_fix = splitapply( ...
    @(x) max(x, [], 'omitnan'), ...
    allData.FixationSeq, G);

num_fixations = table( ...
    Subject, Block, Trial, num_fix, ...
    'VariableNames', ...
    {'Subject','Block','Trial','num_fixations'});

% Sort by block, participant, and trial to match the trial-level eye-tracking table.
num_fixations = sortrows( ...
    num_fixations, ...
    {'Block','Subject','Trial'});

%% 6. Compute mean #fixations by participant and block
[G, Subject, Block] = findgroups( ...
    num_fixations.Subject, ...
    num_fixations.Block);

TF = splitapply( ...
    @(x) mean(x, 'omitnan'), ...
    num_fixations.num_fixations, G);

TF_table = table(Subject, Block, TF);

TF_table = sortrows(TF_table, {'Block','Subject'});

% Compare mean fixation counts between WAV- and TTB-classified participants.
TF_mean = mean(reshape(TF_table.TF, numOfSubjects, 2), 2, 'omitnan');
isWAV_pooled = logical(subjects_strategy_pooled);

mean(TF_mean(~isWAV_pooled))
mean(TF_mean(isWAV_pooled))
std(TF_mean(~isWAV_pooled))
std(TF_mean(isWAV_pooled))
[~,sig,~,t_stat] = ttest2(TF_mean(isWAV_pooled), TF_mean(~isWAV_pooled));

%% 7. Linear mixed model: Vertical index as a function of fixation count
t = T_eye_pooled;

t.total_fixations = num_fixations.num_fixations;
ok = isfinite(t.subject) & ...
     isfinite(t.vertical_index);

t = t(ok,:);

glme_both = fitglme(t, ...
    'vertical_index ~ total_fixations + (1|subject)', ...
    'Distribution', 'Normal');

disp(glme_both)

%% 8. Figure 3: Vertical index as a function of #fixation

fixGrid = linspace( ...
    prctile(t.total_fixations,5), ...
    prctile(t.total_fixations,95), ...
    100)';

% Predictions are population-level (random intercept excluded).
sub0 = t.subject(find(isfinite(t.subject),1));

newData = table( ...
    repmat(sub0,numel(fixGrid),1), ...
    fixGrid, ...
    'VariableNames',{'subject','total_fixations'});

[pFix,ciFix] = predict(glme_both,newData,'Conditional',false);


figure; hold on

cFix = [0.2 0.4 0.9];

fill([fixGrid; flipud(fixGrid)], ...
     [ciFix(:,1); flipud(ciFix(:,2))], ...
     cFix, ...
     'FaceAlpha',0.15, ...
     'EdgeColor','none', ...
     'HandleVisibility','off');

% Binned points are descriptive and are not used to fit the model.

nBins = 6;

fixS = t.total_fixations;
viS  = t.vertical_index;

[fixS,ord] = sort(fixS);
viS = viS(ord);

n = numel(fixS);
binID = ceil((1:n)' / n * nBins);
binID(binID > nBins) = nBins;

xBin = nan(nBins,1);
yBin = nan(nBins,1);

for b = 1:nBins
    idxB = binID == b;

    xBin(b) = mean(fixS(idxB),'omitnan');
    yBin(b) = mean(viS(idxB),'omitnan');
end

hPoints = scatter(xBin,yBin,80,cFix,'filled', ...
    'MarkerFaceAlpha',0.75, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.8);


hLine = plot(fixGrid,pFix, ...
    'LineWidth',3, ...
    'Color',cFix);


xlabel('Total fixations','FontSize',14)
ylabel('Predicted vertical index','FontSize',14)

set(gca,'FontSize',14)
box off

legend([hLine hPoints], ...
    {'Model prediction','Binned data'}, ...
    'Location','best', ...
    'FontSize',12)
xlim([2 11])
text(-0.14,1.10,'A', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

%% 9. Logistic mixed model: Accuracy as a function of bloce-wise strategy and trial-wise scan pattern
t = T_eye_pooled;
subjects_strategy_pooled_long = nan(height(t),1);

for i = 1:numOfSubjects
    subjects_strategy_pooled_long(t.subject == subjects(i)) = ones(sum(...
t.subject == subjects(i)),1)*wav_scores_pooled(i);
end
t.subjects_strategy = subjects_strategy_pooled_long;

ok = isfinite(t.subject) & ...
     isfinite(t.vertical_index) & ...
     isfinite(t.acc) & ...
     ~t.consistency;

t = t(ok,:);

% Standardize vertical index within participant to isolate trial-wise variation.
t.VI_mean = nan(height(t),1);
t.VI_sd = nan(height(t),1);

subject_list = unique(t.subject);

for i = 1:numel(subject_list)
    idx = t.subject == subject_list(i);
    t.VI_mean(idx) = mean(t.vertical_index(idx));
    t.VI_sd(idx) = std(t.vertical_index(idx));
end

t.VI_within = (t.vertical_index - t.VI_mean)./t.VI_sd;

glme_centered = fitglme(t, ...
    'acc ~ subjects_strategy + VI_within + (1|subject)', ...
    'Distribution','Binomial', ...
    'Link','logit');

disp(glme_centered)

%% 10. Figure 4: Model-predicted accuracy
% The model uses continuous WAV score; binary WAV/TTB groups are used only for visualization.

Strategy_binary_plot = double(t.subjects_strategy >= .5);  % 0 = TTB, 1 = WAV

% Generate group lines at the mean WAV score within each visualization group.
wav_TTB = mean(t.subjects_strategy(Strategy_binary_plot == 0),'omitnan');
wav_WAV = mean(t.subjects_strategy(Strategy_binary_plot == 1),'omitnan');

viGrid = linspace( ...
    prctile(t.VI_within,5), ...
    prctile(t.VI_within,95), ...
    100)';

% Predictions are population-level (random intercept excluded).
sub0 = t.subject(find(isfinite(t.subject),1));

newTTB = table( ...
    repmat(sub0,numel(viGrid),1), ...
    repmat(wav_TTB,numel(viGrid),1), ...
    viGrid, ...
    'VariableNames',{'subject','subjects_strategy','VI_within'});

newWAV = table( ...
    repmat(sub0,numel(viGrid),1), ...
    repmat(wav_WAV,numel(viGrid),1), ...
    viGrid, ...
    'VariableNames',{'subject','subjects_strategy','VI_within'});

[pTTB,ciTTB] = predict(glme_centered,newTTB,'Conditional',false);
[pWAV,ciWAV] = predict(glme_centered,newWAV,'Conditional',false);

figure; hold on

cTTB = [0.9 0.3 0.2];
cWAV = [0.2 0.4 0.9];

fill([viGrid; flipud(viGrid)], ...
     [ciTTB(:,1); flipud(ciTTB(:,2))], ...
     cTTB, ...
     'FaceAlpha',0.15, ...
     'EdgeColor','none', ...
     'HandleVisibility','off');

fill([viGrid; flipud(viGrid)], ...
     [ciWAV(:,1); flipud(ciWAV(:,2))], ...
     cWAV, ...
     'FaceAlpha',0.15, ...
     'EdgeColor','none', ...
     'HandleVisibility','off');

% Binned points are descriptive and are not used to fit the model.

nBins = 6;

for s = 0:1

    idxS = Strategy_binary_plot == s;

    viS  = t.VI_within(idxS);
    accS = t.acc(idxS);

    [viS,ord] = sort(viS);
    accS = accS(ord);

    n = numel(viS);
    binID = ceil((1:n)' / n * nBins);
    binID(binID > nBins) = nBins;

    xBin = nan(nBins,1);
    yBin = nan(nBins,1);

    for b = 1:nBins
        idxB = binID == b;

        xBin(b) = mean(viS(idxB),'omitnan');
        yBin(b) = mean(accS(idxB),'omitnan');
    end

    if s == 0
        scatter(xBin,yBin,80,cTTB,'filled', ...
            'MarkerFaceAlpha',0.75, ...
            'MarkerEdgeColor','w', ...
            'LineWidth',0.8, ...
            'HandleVisibility','off');
    else
        scatter(xBin,yBin,80,cWAV,'filled', ...
            'MarkerFaceAlpha',0.75, ...
            'MarkerEdgeColor','w', ...
            'LineWidth',0.8, ...
            'HandleVisibility','off');
    end
end

plot(viGrid,pTTB, ...
    'LineWidth',3, ...
    'Color',cTTB);

plot(viGrid,pWAV, ...
    'LineWidth',3, ...
    'Color',cWAV);

xlabel('Vertical index (z-score)','FontSize',14)
ylabel('Predicted accuracy','FontSize',14)

legend({'TTB','WAV'}, ...
    'Location','best', ...
    'FontSize',12)

set(gca,'FontSize',14)
box off
ylim([0.25 .75])
xlim([-1.55,1.95])

% ========================== SUPPLEMENT ==========================
% ================================================================

%% A1. Additional behavioral analyses: Experiment 1

exp1 = isExp1;

%% 1. Difference in WAV scores between blocks

WAV_3 = wav_scores_3(exp1);
WAV_4 = wav_scores_4(exp1);

[~,p_WAV,~,stats_WAV] = ttest(WAV_3,WAV_4);

fprintf('\nWAV scores between blocks:\n')
fprintf('3 attributes: M = %.2f, SD = %.2f\n', ...
    mean(WAV_3,'omitnan'),std(WAV_3,'omitnan'))
fprintf('4 attributes: M = %.2f, SD = %.2f\n', ...
    mean(WAV_4,'omitnan'),std(WAV_4,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_WAV.df,stats_WAV.tstat,p_WAV)


%% 2. Manipulation check: accuracy between blocks

accuracy_3 = acc3(exp1);
accuracy_4 = acc4(exp1);

[~,p_acc,~,stats_acc] = ttest(accuracy_3,accuracy_4);

fprintf('\nAccuracy between blocks:\n')
fprintf('3 attributes: M = %.2f, SD = %.2f\n', ...
    mean(accuracy_3,'omitnan'),std(accuracy_3,'omitnan'))
fprintf('4 attributes: M = %.2f, SD = %.2f\n', ...
    mean(accuracy_4,'omitnan'),std(accuracy_4,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_acc.df,stats_acc.tstat,p_acc)


%% 3. Correlations between median RT and WAV score

RT_3 = md_ic_RT3(exp1);
RT_4 = md_ic_RT4(exp1);

valid3 = isfinite(RT_3) & isfinite(WAV_3);
valid4 = isfinite(RT_4) & isfinite(WAV_4);

[r_RT3,p_RT3] = corr(RT_3(valid3),WAV_3(valid3), ...
    'Type','Pearson');

[r_RT4,p_RT4] = corr(RT_4(valid4),WAV_4(valid4), ...
    'Type','Pearson');

fprintf('\nMedian RT and WAV score correlations:\n')
fprintf('3 attributes: r = %.2f, p = %.4f\n',r_RT3,p_RT3)
fprintf('4 attributes: r = %.2f, p = %.4f\n',r_RT4,p_RT4)


%% 4. RT differences between strategy groups

isWAV_3 = logical(subjects_strategy_3(exp1));
isWAV_4 = logical(subjects_strategy_4(exp1));

RT_WAV_3 = RT_3(isWAV_3);
RT_TTB_3 = RT_3(~isWAV_3);

RT_WAV_4 = RT_4(isWAV_4);
RT_TTB_4 = RT_4(~isWAV_4);

% Default ttest2 uses the equal-variance test, producing df = 38.
[~,p_group3,~,stats_group3] = ttest2(RT_WAV_3,RT_TTB_3);
[~,p_group4,~,stats_group4] = ttest2(RT_WAV_4,RT_TTB_4);

fprintf('\nMedian RT by strategy group:\n')

fprintf('\n3 attributes:\n')
fprintf('WAV: M = %.2f, SD = %.2f\n', ...
    mean(RT_WAV_3,'omitnan'),std(RT_WAV_3,'omitnan'))
fprintf('TTB: M = %.2f, SD = %.2f\n', ...
    mean(RT_TTB_3,'omitnan'),std(RT_TTB_3,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_group3.df,stats_group3.tstat,p_group3)

fprintf('\n4 attributes:\n')
fprintf('WAV: M = %.2f, SD = %.2f\n', ...
    mean(RT_WAV_4,'omitnan'),std(RT_WAV_4,'omitnan'))
fprintf('TTB: M = %.2f, SD = %.2f\n', ...
    mean(RT_TTB_4,'omitnan'),std(RT_TTB_4,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_group4.df,stats_group4.tstat,p_group4)


%% 5. Strategy-group comparisons using log-transformed median RT

logRT_WAV_3 = log(RT_WAV_3);
logRT_TTB_3 = log(RT_TTB_3);

logRT_WAV_4 = log(RT_WAV_4);
logRT_TTB_4 = log(RT_TTB_4);

[~,p_log3,~,stats_log3] = ttest2(logRT_WAV_3,logRT_TTB_3);
[~,p_log4,~,stats_log4] = ttest2(logRT_WAV_4,logRT_TTB_4);

fprintf('\nLog-transformed median RT by strategy group:\n')
fprintf('3 attributes: t(%d) = %.2f, p = %.4f\n', ...
    stats_log3.df,stats_log3.tstat,p_log3)
fprintf('4 attributes: t(%d) = %.2f, p = %.4f\n', ...
    stats_log4.df,stats_log4.tstat,p_log4)

%% A2. Additional behavioral analyses: Experiment 2

exp2 = isExp2;

%% 1. Difference in WAV scores between blocks

WAV_3_exp2 = wav_scores_3(exp2);
WAV_4_exp2 = wav_scores_4(exp2);

[~,p_WAV_exp2,~,stats_WAV_exp2] = ...
    ttest(WAV_3_exp2,WAV_4_exp2);

fprintf('\nEXPERIMENT 2\n')
fprintf('\nWAV scores between blocks:\n')
fprintf('3 attributes: M = %.2f, SD = %.2f\n', ...
    mean(WAV_3_exp2,'omitnan'), ...
    std(WAV_3_exp2,'omitnan'))
fprintf('4 attributes: M = %.2f, SD = %.2f\n', ...
    mean(WAV_4_exp2,'omitnan'), ...
    std(WAV_4_exp2,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_WAV_exp2.df, ...
    stats_WAV_exp2.tstat, ...
    p_WAV_exp2)


%% 2. Manipulation check: accuracy between blocks

accuracy_3_exp2 = acc3(exp2);
accuracy_4_exp2 = acc4(exp2);

[~,p_acc_exp2,~,stats_acc_exp2] = ...
    ttest(accuracy_3_exp2,accuracy_4_exp2);

fprintf('\nAccuracy between blocks:\n')
fprintf('3 attributes: M = %.2f, SD = %.2f\n', ...
    mean(accuracy_3_exp2,'omitnan'), ...
    std(accuracy_3_exp2,'omitnan'))
fprintf('4 attributes: M = %.2f, SD = %.2f\n', ...
    mean(accuracy_4_exp2,'omitnan'), ...
    std(accuracy_4_exp2,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_acc_exp2.df, ...
    stats_acc_exp2.tstat, ...
    p_acc_exp2)


%% 3. Correlations between median RT and WAV score

RT_3_exp2 = md_ic_RT3(exp2);
RT_4_exp2 = md_ic_RT4(exp2);

valid3 = isfinite(RT_3_exp2) & isfinite(WAV_3_exp2);
valid4 = isfinite(RT_4_exp2) & isfinite(WAV_4_exp2);

[r_RT3_exp2,p_RT3_exp2] = corr( ...
    RT_3_exp2(valid3), ...
    WAV_3_exp2(valid3), ...
    'Type','Pearson');

[r_RT4_exp2,p_RT4_exp2] = corr( ...
    RT_4_exp2(valid4), ...
    WAV_4_exp2(valid4), ...
    'Type','Pearson');

fprintf('\nMedian RT and WAV score correlations:\n')
fprintf('3 attributes: r = %.2f, p = %.4f\n', ...
    r_RT3_exp2,p_RT3_exp2)
fprintf('4 attributes: r = %.2f, p = %.4f\n', ...
    r_RT4_exp2,p_RT4_exp2)


%% 4. RT differences between strategy groups

isWAV_3_exp2 = logical(subjects_strategy_3(exp2));
isWAV_4_exp2 = logical(subjects_strategy_4(exp2));

RT_WAV_3_exp2 = RT_3_exp2(isWAV_3_exp2);
RT_TTB_3_exp2 = RT_3_exp2(~isWAV_3_exp2);

RT_WAV_4_exp2 = RT_4_exp2(isWAV_4_exp2);
RT_TTB_4_exp2 = RT_4_exp2(~isWAV_4_exp2);

[~,p_group3_exp2,~,stats_group3_exp2] = ...
    ttest2(RT_WAV_3_exp2,RT_TTB_3_exp2);

[~,p_group4_exp2,~,stats_group4_exp2] = ...
    ttest2(RT_WAV_4_exp2,RT_TTB_4_exp2);

fprintf('\nMedian RT by strategy group:\n')

fprintf('\n3 attributes:\n')
fprintf('WAV: M = %.2f, SD = %.2f\n', ...
    mean(RT_WAV_3_exp2,'omitnan'), ...
    std(RT_WAV_3_exp2,'omitnan'))
fprintf('TTB: M = %.2f, SD = %.2f\n', ...
    mean(RT_TTB_3_exp2,'omitnan'), ...
    std(RT_TTB_3_exp2,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_group3_exp2.df, ...
    stats_group3_exp2.tstat, ...
    p_group3_exp2)

fprintf('\n4 attributes:\n')
fprintf('WAV: M = %.2f, SD = %.2f\n', ...
    mean(RT_WAV_4_exp2,'omitnan'), ...
    std(RT_WAV_4_exp2,'omitnan'))
fprintf('TTB: M = %.2f, SD = %.2f\n', ...
    mean(RT_TTB_4_exp2,'omitnan'), ...
    std(RT_TTB_4_exp2,'omitnan'))
fprintf('t(%d) = %.2f, p = %.4f\n', ...
    stats_group4_exp2.df, ...
    stats_group4_exp2.tstat, ...
    p_group4_exp2)


%% 5. Strategy-group comparisons using log-transformed median RT

logRT_WAV_3_exp2 = log(RT_WAV_3_exp2);
logRT_TTB_3_exp2 = log(RT_TTB_3_exp2);

logRT_WAV_4_exp2 = log(RT_WAV_4_exp2);
logRT_TTB_4_exp2 = log(RT_TTB_4_exp2);

[~,p_log3_exp2,~,stats_log3_exp2] = ...
    ttest2(logRT_WAV_3_exp2,logRT_TTB_3_exp2);

[~,p_log4_exp2,~,stats_log4_exp2] = ...
    ttest2(logRT_WAV_4_exp2,logRT_TTB_4_exp2);

fprintf('\nLog-transformed median RT by strategy group:\n')
fprintf('3 attributes: t(%d) = %.2f, p = %.4f\n', ...
    stats_log3_exp2.df, ...
    stats_log3_exp2.tstat, ...
    p_log3_exp2)
fprintf('4 attributes: t(%d) = %.2f, p = %.4f\n', ...
    stats_log4_exp2.df, ...
    stats_log4_exp2.tstat, ...
    p_log4_exp2)


%% 6. Average total number of fixations

exp2Subjects = subjects(exp2);

TF_3_exp2 = TF_table.TF( ...
    TF_table.Block == 1 & ...
    ismember(TF_table.Subject,exp2Subjects));

TF_4_exp2 = TF_table.TF( ...
    TF_table.Block == 2 & ...
    ismember(TF_table.Subject,exp2Subjects));

fprintf('\nAverage total number of fixations:\n')
fprintf('3 attributes: M = %.2f, SD = %.2f\n', ...
    mean(TF_3_exp2,'omitnan'), ...
    std(TF_3_exp2,'omitnan'))
fprintf('4 attributes: M = %.2f, SD = %.2f\n', ...
    mean(TF_4_exp2,'omitnan'), ...
    std(TF_4_exp2,'omitnan'))

%% S2. Figure S1: Cross-block consistency in Experiment 2
figure('Color','w');

tiledlayout(1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

ax1 = nexttile;
hold(ax1,'on');

x = wav_scores_3(isExp2);
y = wav_scores_4(isExp2);

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

r3 = corr(x,y);

mdl = fitlm(x,y);
xFit = linspace(min(x),max(x),100)';
[yFit,yCI] = predict(mdl,xFit);

fill(ax1, ...
    [xFit; flipud(xFit)], ...
    [yCI(:,1); flipud(yCI(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax1,x,y,45,'filled', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax1,xFit,yFit,'k-','LineWidth',1.8);


statText = sprintf('r = %.2f**',r3);


text(ax1,0.1,0.93,statText, ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax1,'WAV score (3 attributes)');
ylabel(ax1,'WAV score (4 attributes)');
title(ax1,'Behavioral compensatory tendency','FontWeight','normal');

ylim(ax1,[0 1]);
xlim(ax1,[0 1]);

set(ax1,'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

axis(ax1,'square');

text(ax1,-0.14,1.10,'A', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');


ax2 = nexttile;
hold(ax2,'on');

x = VI_3(isExp2)';
y = VI_4(isExp2)';

ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);

r4 = corr(x,y);

mdl = fitlm(x,y);
xFit = linspace(min(x),max(x),100)';
[yFit,yCI] = predict(mdl,xFit);

fill(ax2, ...
    [xFit; flipud(xFit)], ...
    [yCI(:,1); flipud(yCI(:,2))], ...
    [0.75 0.75 0.75], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.35);

scatter(ax2,x,y,45,'filled', ...
    'MarkerFaceAlpha',0.7, ...
    'MarkerEdgeColor','w', ...
    'LineWidth',0.5);

plot(ax2,xFit,yFit,'k-','LineWidth',1.8);

statText = sprintf('r = %.2f**',r4);

text(ax2,0.1,0.93,statText, ...
    'Units','normalized', ...
    'FontSize',13, ...
    'VerticalAlignment','top');

xlabel(ax2,'Vertical index (3 attributes)');
ylabel(ax2,'Vertical index (4 attributes)');
title(ax2,'Eye-scan vertical index','FontWeight','normal');

ylim(ax2,[-.9 .35]);
xlim(ax2,[-.9 .35]);

set(ax2,'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

axis(ax2,'square');

text(ax2,-0.14,1.10,'B', ...
    'Units','normalized', ...
    'FontSize',18, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'Clipping','off');

%% B. Effects of gaze duration on choice

%% Mean fixation duration by attribute

folder = detailedDataDir;
files = dir(fullfile(folder,'*.csv'));

nSubjects = numel(files);

subjectID = nan(nSubjects,1);
duration_3 = nan(nSubjects,3);
duration_4 = nan(nSubjects,4);

for s = 1:nSubjects

    T = readtable(fullfile(files(s).folder,files(s).name));

    numbers = regexp(files(s).name,'\d+','match');
    subjectID(s) = str2double(numbers{end});

    % AOI labels A1/B1, A2/B2, and so forth identify attribute rows.
    attribute = str2double( ...
        regexp(string(T.AOI),'\d+$','match','once'));

    duration = T.Duration_ms;
    trial = T.Trial;
    block = T.Block;


    blockTrials = unique(trial(block == 1));

    valid = block == 1 & ...
            ismember(attribute,1:3) & ...
            isfinite(duration);

    [~,trialIndex] = ismember(trial(valid),blockTrials);

    trialDuration = accumarray( ...
        [trialIndex attribute(valid)], ...
        duration(valid), ...
        [numel(blockTrials) 3], ...
        @sum,0);

    duration_3(s,:) = mean(trialDuration,1);


    blockTrials = unique(trial(block == 2));

    valid = block == 2 & ...
            ismember(attribute,1:4) & ...
            isfinite(duration);

    [~,trialIndex] = ismember(trial(valid),blockTrials);

    trialDuration = accumarray( ...
        [trialIndex attribute(valid)], ...
        duration(valid), ...
        [numel(blockTrials) 4], ...
        @sum,0);

    duration_4(s,:) = mean(trialDuration,1);
end


[subjectID,order] = sort(subjectID);
duration_3 = duration_3(order,:);
duration_4 = duration_4(order,:);

% Store participant IDs as row names.

duration_3_table = array2table(duration_3, ...
    'VariableNames',{'Attribute1','Attribute2','Attribute3'}, ...
    'RowNames',cellstr("S" + subjectID));

duration_4_table = array2table(duration_4, ...
    'VariableNames',{'Attribute1','Attribute2', ...
                     'Attribute3','Attribute4'}, ...
    'RowNames',cellstr("S" + subjectID));

disp(duration_3_table)
disp(duration_4_table)

%% Trial-wise viewing-time difference between alternatives

folder = detailedDataDir;
files = dir(fullfile(folder,'*.csv'));

duration_trial_table = table();

for s = 1:numel(files)

    T = readtable(fullfile(files(s).folder,files(s).name));

    numbers = regexp(files(s).name,'\d+','match');
    subjectID = str2double(numbers{end});

    AOI = string(T.AOI);
    duration = T.Duration_ms;
    duration(~isfinite(duration)) = 0;

    isA = startsWith(AOI,"A");
    isB = startsWith(AOI,"B");

    [G,Block,Trial] = findgroups(T.Block,T.Trial);

    % Sum fixation duration separately across all AOIs for alternatives A and B.
    A_duration = splitapply(@sum,duration .* isA,G);
    B_duration = splitapply(@sum,duration .* isB,G);

    AminusB = A_duration - B_duration;
    Subject = repmat(subjectID,numel(Trial),1);

    subjectData = table( ...
        Subject,Block,Trial,A_duration,B_duration,AminusB);

    duration_trial_table = [duration_trial_table; subjectData];
end


duration_trial_table = sortrows(duration_trial_table,{'Block','Subject','Trial'});

disp(duration_trial_table)

%% Combine viewing-time and attribute-value predictors
t_3 = duration_trial_table(duration_trial_table.Block == 1,[1,6]);
t_3.d1 = stimuli_differences_3_long(:,1);
t_3.d2 = stimuli_differences_3_long(:,2);
t_3.d3 = stimuli_differences_3_long(:,3);
sub_response_3_long(sub_response_3_long == 2) = 0;
t_3.response = sub_response_3_long;

t_4 = duration_trial_table(duration_trial_table.Block == 2,[1,6]);
t_4.d1 = stimuli_differences_4_long(:,1);
t_4.d2 = stimuli_differences_4_long(:,2);
t_4.d3 = stimuli_differences_4_long(:,3);
t_4.d4 = stimuli_differences_4_long(:,4);
sub_response_4_long(sub_response_4_long == 2) = 0;
t_4.response = sub_response_4_long;

%% Logistic mixed models of choice
t_3.Subject = categorical(t_3.Subject);

ok3 = isfinite(t_3.response) & ...
      isfinite(t_3.AminusB) & ...
      isfinite(t_3.d1) & ...
      isfinite(t_3.d2) & ...
      isfinite(t_3.d3);

t3_model = t_3(ok3,:);

glme_3 = fitglme(t3_model, ...
    'response ~ d1 + d2 + d3 + AminusB + (1|Subject)', ...
    'Distribution','Binomial', ...
    'Link','logit', ...
    'FitMethod','Laplace');

disp(glme_3)
disp(anova(glme_3))

t_4.Subject = categorical(t_4.Subject);

ok4 = isfinite(t_4.response) & ...
      isfinite(t_4.AminusB) & ...
      isfinite(t_4.d1) & ...
      isfinite(t_4.d2) & ...
      isfinite(t_4.d3) & ...
      isfinite(t_4.d4);

t4_model = t_4(ok4,:);

glme_4 = fitglme(t4_model, ...
    'response ~ d1 + d2 + d3 + d4 + AminusB + (1|Subject)', ...
    'Distribution','Binomial', ...
    'Link','logit', ...
    'FitMethod','Laplace');

disp(glme_4)
disp(anova(glme_4))

%% Figure S2: Viewing duration, choice, and attribute weights
% Panels A-B compare observed choice proportions with model predictions; Panels C-D compare model-estimated choice weights with fixation duration.

% Panels A-B: viewing-duration effect on choice

conditions = [-1 1];


ok3 = isfinite(t_3.AminusB) & ...
      ismember(t_3.response,[0 1]) & ...
      t_3.AminusB ~= 0;

t3_plot = t_3(ok3,:);

% Viewing-time condition: -1 indicates longer viewing of B; +1 indicates longer viewing of A.
durationCondition3 = sign(t3_plot.AminusB);

subjects3 = unique(t3_plot.Subject);
subjectMeans3 = nan(numel(subjects3),2);

for s = 1:numel(subjects3)
    for c = 1:2

        rows = t3_plot.Subject == subjects3(s) & ...
               durationCondition3 == conditions(c);

        if any(rows)
            subjectMeans3(s,c) = ...
                mean(t3_plot.response(rows),'omitnan');
        end
    end
end

meanChoice3 = mean(subjectMeans3,1,'omitnan');

n3 = sum(isfinite(subjectMeans3),1);

sem3 = std(subjectMeans3,0,1,'omitnan') ./ sqrt(n3);

ciObserved3 = tinv(0.975,n3-1) .* sem3;


AB_model3 = [ ...
    median(t3_plot.AminusB(durationCondition3 == -1),'omitnan');
    median(t3_plot.AminusB(durationCondition3 ==  1),'omitnan')];

newData3 = t3_model(repmat(1,2,1),:);

newData3.AminusB = AB_model3;

% Hold attribute-value differences at their sample means for prediction.
newData3.d1(:) = mean(t3_model.d1,'omitnan');
newData3.d2(:) = mean(t3_model.d2,'omitnan');
newData3.d3(:) = mean(t3_model.d3,'omitnan');

[pModel3,ciModel3] = predict( ...
    glme_3,newData3, ...
    'Conditional',false);

lowerModel3 = pModel3 - ciModel3(:,1);
upperModel3 = ciModel3(:,2) - pModel3;


ok4 = isfinite(t_4.AminusB) & ...
      ismember(t_4.response,[0 1]) & ...
      t_4.AminusB ~= 0;

t4_plot = t_4(ok4,:);

% Viewing-time condition: -1 indicates longer viewing of B; +1 indicates longer viewing of A.
durationCondition4 = sign(t4_plot.AminusB);

subjects4 = unique(t4_plot.Subject);
subjectMeans4 = nan(numel(subjects4),2);

for s = 1:numel(subjects4)
    for c = 1:2

        rows = t4_plot.Subject == subjects4(s) & ...
               durationCondition4 == conditions(c);

        if any(rows)
            subjectMeans4(s,c) = ...
                mean(t4_plot.response(rows),'omitnan');
        end
    end
end

meanChoice4 = mean(subjectMeans4,1,'omitnan');

n4 = sum(isfinite(subjectMeans4),1);

sem4 = std(subjectMeans4,0,1,'omitnan') ./ sqrt(n4);

ciObserved4 = tinv(0.975,n4-1) .* sem4;


AB_model4 = [ ...
    median(t4_plot.AminusB(durationCondition4 == -1),'omitnan');
    median(t4_plot.AminusB(durationCondition4 ==  1),'omitnan')];

newData4 = t4_model(repmat(1,2,1),:);

newData4.AminusB = AB_model4;

% Hold attribute-value differences at their sample means for prediction.
newData4.d1(:) = mean(t4_model.d1,'omitnan');
newData4.d2(:) = mean(t4_model.d2,'omitnan');
newData4.d3(:) = mean(t4_model.d3,'omitnan');
newData4.d4(:) = mean(t4_model.d4,'omitnan');

[pModel4,ciModel4] = predict( ...
    glme_4,newData4, ...
    'Conditional',false);

lowerModel4 = pModel4 - ciModel4(:,1);
upperModel4 = ciModel4(:,2) - pModel4;

% Panels C-D: choice weights and fixation duration

% Extract choice coefficients and normalize them to sum to one.

coefNames3 = string(glme_3.CoefficientNames);
weightNames3 = ["d1","d2","d3"];

[found3,idx3] = ismember(weightNames3,coefNames3);

assert(all(found3), ...
    'Could not find all d1-d3 coefficients in glme_3.');

beta3 = glme_3.Coefficients.Estimate(idx3);

betaCI3 = coefCI(glme_3);
betaCI3 = betaCI3(idx3,:);

sumBeta3 = sum(beta3);
choiceWeights3_N = beta3 ./ sumBeta3;

choiceCI3_N = betaCI3 ./ sumBeta3;

choiceCI3_lower = min(choiceCI3_N,[],2);
choiceCI3_upper = max(choiceCI3_N,[],2);

choiceLower3 = choiceWeights3_N - choiceCI3_lower;
choiceUpper3 = choiceCI3_upper - choiceWeights3_N;


% Extract choice coefficients and normalize them to sum to one.

coefNames4 = string(glme_4.CoefficientNames);
weightNames4 = ["d1","d2","d3","d4"];

[found4,idx4] = ismember(weightNames4,coefNames4);

assert(all(found4), ...
    'Could not find all d1-d4 coefficients in glme_4.');

beta4 = glme_4.Coefficients.Estimate(idx4);

betaCI4 = coefCI(glme_4);
betaCI4 = betaCI4(idx4,:);

sumBeta4 = sum(beta4);
choiceWeights4_N = beta4 ./ sumBeta4;

choiceCI4_N = betaCI4 ./ sumBeta4;

choiceCI4_lower = min(choiceCI4_N,[],2);
choiceCI4_upper = max(choiceCI4_N,[],2);

choiceLower4 = choiceWeights4_N - choiceCI4_lower;
choiceUpper4 = choiceCI4_upper - choiceWeights4_N;


duration_3_N = duration_3 ./ sum(duration_3,2);
duration_4_N = duration_4 ./ sum(duration_4,2);

validDuration3 = all(isfinite(duration_3_N),2);
validDuration4 = all(isfinite(duration_4_N),2);

meanDuration3 = mean(duration_3_N(validDuration3,:),1);
meanDuration4 = mean(duration_4_N(validDuration4,:),1);

nDuration3 = sum(validDuration3);
nDuration4 = sum(validDuration4);

seDuration3 = ...
    std(duration_3_N(validDuration3,:),0,1) ./ sqrt(nDuration3);

seDuration4 = ...
    std(duration_4_N(validDuration4,:),0,1) ./ sqrt(nDuration4);


figure('Position',[100 100 1000 800])

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


nexttile
hold on

b3 = bar(1:2,meanChoice3,0.65, ...
    'FaceColor',[0.35 0.55 0.80]);

errorbar(1:2,meanChoice3,ciObserved3, ...
    'k', ...
    'LineStyle','none', ...
    'LineWidth',1.3);

plot(1:2,pModel3, ...
    'k-', ...
    'LineWidth',1.5);

m3 = errorbar(1:2,pModel3,lowerModel3,upperModel3, ...
    'kd', ...
    'MarkerFaceColor','k', ...
    'MarkerSize',7, ...
    'LineStyle','none', ...
    'LineWidth',1.4);

yline(0.5,'k--','LineWidth',1);

xticks(1:2)
xticklabels({'A < B','A > B'})

ylabel('Proportion / probability of choosing A')
title('3 attributes')

ylim([0 1])
xlim([0.4 2.6])

set(gca,'FontSize',13)
box off

text(-0.05,1.1,'A', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold');


nexttile
hold on

b4 = bar(1:2,meanChoice4,0.65, ...
    'FaceColor',[0.35 0.55 0.80]);

errorbar(1:2,meanChoice4,ciObserved4, ...
    'k', ...
    'LineStyle','none', ...
    'LineWidth',1.3);

plot(1:2,pModel4, ...
    'k-', ...
    'LineWidth',1.5);

m4 = errorbar(1:2,pModel4,lowerModel4,upperModel4, ...
    'kd', ...
    'MarkerFaceColor','k', ...
    'MarkerSize',7, ...
    'LineStyle','none', ...
    'LineWidth',1.4);

yline(0.5,'k--','LineWidth',1);

xticks(1:2)
xticklabels({'A < B','A > B'})

title('4 attributes')

ylim([0 1])
xlim([0.4 2.6])

set(gca,'FontSize',13)
box off

text(-0.12,1.1,'B', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold');

legend([b4 m4], ...
    {'Observed data','Model prediction'}, ...
    'Location','northwest', ...
    'Box','off');


nexttile
hold on

h1 = errorbar(1:3, ...
    choiceWeights3_N, ...
    choiceLower3, ...
    choiceUpper3, ...
    '-ko', ...
    'MarkerFaceColor','k', ...
    'LineWidth',1.5);

h2 = errorbar(1:3, ...
    meanDuration3, ...
    seDuration3, ...
    '--ks', ...
    'MarkerFaceColor','w', ...
    'LineWidth',1.5);

xlim([0.5 3.5])
xticks(1:3)
xticklabels({'Att-1','Att-2','Att-3'})

ylabel('Normalized weight / fixation duration')
title('3 attributes')

set(gca,'FontSize',13)
box off

text(-0.05,1.1,'C', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold');

legend([h1 h2], ...
    {'Model-estimated choice weight','Fixation duration'}, ...
    'Location','best', ...
    'FontSize',11, ...
    'Box','off');


nexttile
hold on

errorbar(1:4, ...
    choiceWeights4_N, ...
    choiceLower4, ...
    choiceUpper4, ...
    '-ko', ...
    'MarkerFaceColor','k', ...
    'LineWidth',1.5);

errorbar(1:4, ...
    meanDuration4, ...
    seDuration4, ...
    '--ks', ...
    'MarkerFaceColor','w', ...
    'LineWidth',1.5);

xlim([0.5 4.5])
xticks(1:4)
xticklabels({'Att-1','Att-2','Att-3','Att-4'})

title('4 attributes')

set(gca,'FontSize',13)
box off

text(-0.12,1.1,'D', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold');

%% C. Additional analysis of gaze-scan

%% Calculate the percentage of scanned attribute rows
% Block 1 contains three attributes; Block 2 contains four.
% Repeated fixations on the same attribute count once when computing row coverage.

dataFolder = detailedDataDir;

aoiVariable   = 'AOI';
blockVariable = 'Block';
trialVariable = 'Trial';

files = dir(fullfile(dataFolder,'*.csv'));


allTrialResults = table();


for f = 1:numel(files)

    filePath = fullfile(files(f).folder,files(f).name);
    T = readtable(filePath,'TextType','string');


    if ismember('Subject', T.Properties.VariableNames)
        subjectID = string(T.Subject(1));
    else
        subjectMatch = regexp(files(f).name, '\d+', 'match', 'once');
        if isempty(subjectMatch)
            subjectID = erase(files(f).name, '.csv');
        else
            subjectID = string(subjectMatch);
        end
    end


    block = T.(blockVariable);
    trial = T.(trialVariable);
    aoi   = string(T.(aoiVariable));


    % Only AOIs matching A1/B1, A2/B2, and so forth are treated as attribute rows.
    attributeText = regexp(upper(aoi),'^[AB](\d+)$','tokens','once');

    attributeNumber = nan(height(T),1);

    for row = 1:height(T)

        if ~isempty(attributeText{row})
            attributeNumber(row) = ...
                str2double(attributeText{row}{1});
        end
    end


    validTrialRows = isfinite(block) & isfinite(trial);

    trialKeys = unique( ...
        [block(validTrialRows),trial(validTrialRows)], ...
        'rows', ...
        'sorted');

    participantResults = table();


    for k = 1:size(trialKeys,1)

        currentBlock = trialKeys(k,1);
        currentTrial = trialKeys(k,2);

        rows = block == currentBlock & ...
               trial == currentTrial;

        attributesVisited = unique( ...
            attributeNumber(rows & isfinite(attributeNumber)));

        if currentBlock == 1

            numberOfAttributes = 3;

            attributesVisited = ...
                attributesVisited( ...
                attributesVisited >= 1 & ...
                attributesVisited <= 3);

        elseif currentBlock == 2

            numberOfAttributes = 4;

            attributesVisited = ...
                attributesVisited( ...
                attributesVisited >= 1 & ...
                attributesVisited <= 4);
        end

        numberVisited = numel(attributesVisited);

        rowCoverageFraction = ...
            numberVisited / numberOfAttributes;


        newRow = table( ...
            subjectID, ...
            currentBlock, ...
            currentTrial, ...
            numberVisited, ...
            numberOfAttributes, ...
            rowCoverageFraction, ...
            'VariableNames',{ ...
            'Subject', ...
            'Block', ...
            'Trial', ...
            'AttributesVisited', ...
            'TotalAttributes', ...
            'RowCoverageFraction'});

        participantResults = ...
            [participantResults; newRow];

    end

    allTrialResults = ...
        [allTrialResults; participantResults];

end


trial_row_coverage = sortrows( ...
    allTrialResults, ...
    {'Subject','Block','Trial'});


coverageSubjects = unique(trial_row_coverage.Subject, 'sorted');

subject_row_coverage = table( ...
    coverageSubjects, ...
    nan(numel(coverageSubjects), 1), ...
    nan(numel(coverageSubjects), 1), ...
    'VariableNames',{ ...
    'Subject', ...
    'Block1MeanCoverage', ...
    'Block2MeanCoverage'});


for s = 1:numel(coverageSubjects)

    subjectRows = ...
        trial_row_coverage.Subject == coverageSubjects(s);

    block1Rows = subjectRows & ...
        trial_row_coverage.Block == 1;

    block2Rows = subjectRows & ...
        trial_row_coverage.Block == 2;

    subject_row_coverage.Block1MeanCoverage(s) = ...
        mean( ...
        trial_row_coverage.RowCoverageFraction(block1Rows), ...
        'omitnan');

    subject_row_coverage.Block2MeanCoverage(s) = ...
        mean( ...
        trial_row_coverage.RowCoverageFraction(block2Rows), ...
        'omitnan');

end


PSR_block1 = ...
    subject_row_coverage.Block1MeanCoverage;

PSR_block2 = ...
    subject_row_coverage.Block2MeanCoverage;

%% Figure S3: Distribution of percentage of scanned rows

psr3 = PSR_block1(:);
psr4 = PSR_block2(:);

allValues = [psr3; psr4];
upperLimit = ceil(max(allValues)*20)/20;

figure('Color','w','Position',[100 100 750 380])

tiledlayout(1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


ax1 = nexttile;
hold on

h1 = histogram(psr3, ...
    'FaceColor',[0.35 0.55 0.80], ...
    'FaceAlpha',0.80, ...
    'EdgeColor','w', ...
    'LineWidth',0.8);

xlabel('Percentage of scanned rows')
ylabel('Number of participants')
title('3 attributes','FontWeight','normal')

xlim([0 upperLimit])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-0.12,1.06,'A', ...
    'Units','normalized', ...
    'FontSize',17, ...
    'FontWeight','bold', ...
    'Clipping','off');


ax2 = nexttile;
hold on

h2 = histogram(psr4, ...
    'FaceColor',[0.35 0.55 0.80], ...
    'FaceAlpha',0.80, ...
    'EdgeColor','w', ...
    'LineWidth',0.8);

xlabel('Percentage of scanned rows')
title('4 attributes','FontWeight','normal')

xlim([0 upperLimit])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-0.12,1.06,'B', ...
    'Units','normalized', ...
    'FontSize',17, ...
    'FontWeight','bold', ...
    'Clipping','off');


maxCount = max([h1.Values h2.Values]);
ylim(ax1,[0 maxCount + 1])
ylim(ax2,[0 maxCount + 1])

%% Figure S4: Percentage of scanned rows by strategy
strategy3 = logical(subjects_strategy_3(:));
strategy4 = logical(subjects_strategy_4(:));

allRows3 = PSR_block1(:);
allRows4 = PSR_block2(:);


comp3 = allRows3(strategy3 & isfinite(allRows3));
ttb3  = allRows3(~strategy3 & isfinite(allRows3));

meanAllRows3 = [ ...
    mean(comp3,'omitnan'), ...
    mean(ttb3,'omitnan')];

n3 = [numel(comp3), numel(ttb3)];

sem3 = [ ...
    std(comp3,0,'omitnan') / sqrt(n3(1)), ...
    std(ttb3,0,'omitnan') / sqrt(n3(2))];

ciAllRows3 = [ ...
    tinv(0.975,n3(1)-1) * sem3(1), ...
    tinv(0.975,n3(2)-1) * sem3(2)];


comp4 = allRows4(strategy4 & isfinite(allRows4));
ttb4  = allRows4(~strategy4 & isfinite(allRows4));

meanAllRows4 = [ ...
    mean(comp4,'omitnan'), ...
    mean(ttb4,'omitnan')];

n4 = [numel(comp4), numel(ttb4)];

sem4 = [ ...
    std(comp4,0,'omitnan') / sqrt(n4(1)), ...
    std(ttb4,0,'omitnan') / sqrt(n4(2))];

ciAllRows4 = [ ...
    tinv(0.975,n4(1)-1) * sem4(1), ...
    tinv(0.975,n4(2)-1) * sem4(2)];


figure('Color','w','Position',[100 100 750 400])

tiledlayout(1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


nexttile
hold on

bar(1:2,meanAllRows3,0.65, ...
    'FaceColor',[0.35 0.55 0.80]);

errorbar(1:2,meanAllRows3,ciAllRows3, ...
    'k', ...
    'LineStyle','none', ...
    'LineWidth',1.3);

xticks(1:2)
xticklabels({'WAV','TTB'})

ylabel('Mean PSR')
title('3 attributes')

xlim([.4 2.6])
ylim([.2 .7])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-0.10,1.06,'A', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Clipping','off');


nexttile
hold on

bar(1:2,meanAllRows4,0.65, ...
    'FaceColor',[0.35 0.55 0.80]);

errorbar(1:2,meanAllRows4,ciAllRows4, ...
    'k', ...
    'LineStyle','none', ...
    'LineWidth',1.3);

xticks(1:2)
xticklabels({'WAV','TTB'})

title('4 attributes')

xlim([.4 2.6])
ylim([.2 .7])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-0.10,1.06,'B', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Clipping','off');

sgtitle('Mean PSR by decision strategy')

%% Figure S5: Percentage of scanned rows by vertical-index group

highVI3 = VI_3(:) >= median(VI_3);
highVI4 = VI_4(:) >= median(VI_4);

PSR3 = PSR_block1(:);
PSR4 = PSR_block2(:);


high3 = PSR3(highVI3 & isfinite(PSR3));
low3  = PSR3(~highVI3 & isfinite(PSR3));

meanPSR3 = [mean(high3), mean(low3)];
n3 = [numel(high3), numel(low3)];

sem3 = [std(high3)/sqrt(n3(1)), ...
        std(low3)/sqrt(n3(2))];

ciPSR3 = [tinv(.975,n3(1)-1)*sem3(1), ...
          tinv(.975,n3(2)-1)*sem3(2)];


high4 = PSR4(highVI4 & isfinite(PSR4));
low4  = PSR4(~highVI4 & isfinite(PSR4));

meanPSR4 = [mean(high4), mean(low4)];
n4 = [numel(high4), numel(low4)];

sem4 = [std(high4)/sqrt(n4(1)), ...
        std(low4)/sqrt(n4(2))];

ciPSR4 = [tinv(.975,n4(1)-1)*sem4(1), ...
          tinv(.975,n4(2)-1)*sem4(2)];


figure('Color','w','Position',[100 100 750 400])

tiledlayout(1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


nexttile
hold on

bar(1:2,meanPSR3,.65, ...
    'FaceColor',[.35 .55 .80]);

errorbar(1:2,meanPSR3,ciPSR3, ...
    'k','LineStyle','none','LineWidth',1.3);

xticks(1:2)
xticklabels({'High VI','Low VI'})

ylabel('Mean PSR')
title('3 attributes')

xlim([.4 2.6])
ylim([.2 .7])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-.10,1.06,'A', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Clipping','off');


nexttile
hold on

bar(1:2,meanPSR4,.65, ...
    'FaceColor',[.35 .55 .80]);

errorbar(1:2,meanPSR4,ciPSR4, ...
    'k','LineStyle','none','LineWidth',1.3);

xticks(1:2)
xticklabels({'High VI','Low VI'})

title('4 attributes')

xlim([.4 2.6])
ylim([.2 .7])

set(gca, ...
    'FontSize',13, ...
    'Box','off', ...
    'TickDir','out');

text(-.10,1.06,'B', ...
    'Units','normalized', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Clipping','off');

sgtitle('Mean PSR by vertical-index')
