% =========================================================================
% Analyze_eye (formerly Analyze_eyeV3)
%
% NOTE:
% Jonathan wrote this code and it was previously named "Analyze_eyeV3.m".
% I renamed to "Analyze_eye.m" to serve as the main and only analysis
% script on the local machine.
%
% If older documents, emails, or code refer to "Analyze_eyeV3",
% they correspond to THIS file.
%
% Last rename: Jan 2026
% =========================================================================

% - AOIs aligned to TableLayout for Block 1 & Block 2

% Updated: 16-Dec-2025

clear all
load('C:\Users\user\Documents\Noa\Thesis_EyeTracking\01_Experiment\Eyedata\Subject_993_eyeData.mat');


% Eye_file = ['/Volumes/Untitled - Data/Post-doc OSU/Numerasity/Exp3/Eyedata/Subject_' num2str(subject) ' eyeData.mat'];
%% ---------- Block 1 (3 attributes, 6 rectangles) ----------
rectsBlock1 = [
% ---------- Header ----------
    480   270   800   405;   % Feature (header)
    800   270   1120  405;   % A (header)
    1120  270   1440  405;   % B (header)

% ---------- Attribute column ----------
    480   405   800   540;   % AT1
    480   540   800   675;   % AT2
    480   675   800   810;   % AT3

% ---------- Alternatives ----------
    800   405   1120  540;   % A1
    1120  405   1440  540;   % B1

    800   540   1120  675;   % A2
    1120  540   1440  675;   % B2

    800   675   1120  810;   % A3
    1120  675   1440  810;   % B3
];

%% ---------- Block 2 (4 attributes, 8 rectangles) ----------

rectsBlock2 = [
% ---------- Header ----------
    480   270   800   378;   % Feature (header)
    800   270   1120  378;   % A (header)
    1120  270   1440  378;   % B (header)

% ---------- Attribute column ----------
    480   378   800   486;   % AT1
    480   486   800   594;   % AT2
    480   594   800   702;   % AT3
    480   702   800   810;   % AT4

% ---------- Alternatives ----------
    800   378   1120  486;   % A1
    1120  378   1440  486;   % B1

    800   486   1120  594;   % A2
    1120  486   1440  594;   % B2

    800   594   1120  702;   % A3
    1120  594   1440  702;   % B3

    800   702   1120  810;   % A4
    1120  702   1440  810;   % B4
];
% Cells={'AT1','AT2','AT3','A','B','A1', 'B1','A2','B2','A3','B3','A4','B4'};


Cells1 = { ...
    'F','A','B', ...                 % 1–2  headers
    'AT1','AT2','AT3', ... % 3–5  attribute column
    'A1','B1', ...               % 6–7
    'A2','B2', ...               % 8–9
    'A3','B3', ...               % 10–11

};


Cells2 = { ...
    'F','A','B', ...                 % 1–2  headers
    'AT1','AT2','AT3','AT4', ... % 3–6  attribute column
    'A1','B1', ...               % 7–8
    'A2','B2', ...               % 9–10
    'A3','B3', ...               % 11–12
    'A4','B4' ...                % 13–14
};

AOIs=rectsBlock1; Cells=Cells1; GazeDuration=zeros(length(AOIs),1);count=0;Fix=[];
min_sample=20;min_sacc=10;

% for x = 1:length(edfStruct.FEVENT)
% 
%     % --- NEW: extract the message safely ---
%     msg = edfStruct.FEVENT(x).message;
% 
%     % --- NEW: skip non-text or empty messages ---
%     if isempty(msg) || ~ischar(msg)
%         continue
%     end
% 
%     % --- ONLY NOW it's safe to check the content ---
%     if length(msg) > 5 && strcmp(msg(1:5), 'TRIAL')

for x=1:length(edfStruct.FEVENT )
    if length(edfStruct.FEVENT(x).message)>5
        if edfStruct.FEVENT(x).message(1:5) == 'TRIAL'
            if edfStruct.FEVENT(x).message(7)~='E'
                trial_num=str2num(edfStruct.FEVENT(x).message(7));
                count=count+1;
            end
        elseif edfStruct.FEVENT(x).message(1:4) =='Stim'
            Start = find(edfStruct.FSAMPLE.time ==edfStruct.FEVENT(x).sttime);
        elseif edfStruct.FEVENT(x).message(1:4) =='RESP' | edfStruct.FEVENT(x).message(1:4) =='TIME'
            End = find(edfStruct.FSAMPLE.time ==edfStruct.FEVENT(x).sttime);

            Locations=double([edfStruct.FSAMPLE.gx(1,Start:End);edfStruct.FSAMPLE.gy(1,Start:End)]);
            for z=1:length(Locations)
                inAOI=double(AOIs(:,1)<Locations(1,z) & AOIs(:,2)<Locations(2,z) & AOIs(:,3)>Locations(1,z) & AOIs(:,4)>Locations(2,z));
                GazeDuration=GazeDuration+inAOI;
            end

            %check fixations
            count_fix=0;first=0;Fix_loc=[];Fix=[];Z=[];Fix_time=zeros(1,length(Locations));
            for z=3:length(Locations)
                if abs(Locations(1,z)-Locations(1,z-2))<min_sacc & abs(Locations(2,z)-Locations(2,z-2))<min_sacc
                    Fix_loc=[Fix_loc;Locations(:,z-2)';Locations(:,z)'];
                    Z=[Z z];
                    count_fix=count_fix+1;
                    if count_fix>min_sample & first==0
                        first=1;
                    end
                elseif first==1
                    if mean(Fix_loc)~=100000000
                        Fix=[Fix;mean(Fix_loc) std(Fix_loc)./sqrt(length(Fix_loc))];
                        Fix_time(Z)=Fix_time(Z)+1;
                    end
                    count_fix=0;first=0;Fix_loc=[];Z=[];
                elseif first==0
                    count_fix=0;first=0;Fix_loc=[];Z=[];
                end
            end
            if first==1 
                Fix=[Fix;mean(Fix_loc) std(Fix_loc)./sqrt(length(Fix_loc))];
                count_fix=0;first=0;Fix_loc=[];
            end
           
        end

    end
    if ~isempty(Fix)
        tmpp=zeros(20,1);Fix_sequance = num2cell(tmpp);
        for f=1:size(Fix,1)
            Fixed_AOI=find(double(AOIs(:,1)<Fix(f,1) & AOIs(:,2)<Fix(f,2) & AOIs(:,3)>Fix(f,1) & AOIs(:,4)>Fix(f,2)));
            if ~isempty(Fixed_AOI)
                tmpp(f)=Fixed_AOI;
            end
        end
        for t=1:length(tmpp)
            if tmpp(t)>0
                Fix_sequance{t}=Cells(tmpp(t));
            else Fix_sequance{t}=nan;
            end
        end
        Fixations(count,:)=Fix_sequance';
        if trial_num==8
            AOIs=rectsBlock2; Cells=Cells2;
            GazeDuration=zeros(length(AOIs),1);
        end
    end
end