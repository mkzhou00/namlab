%% Runs session
% This function is called upon clicking the Start button in the GUI
% Requires variables param and s (serial object).

cla;                                    % Clear the axes before starting
%% Parameters
truncITI = min(maxITI,3*minITI);                     % minITI is really the mean ITI for exponential dbn
licksinit = ceil(sum(numtrials)*(truncITI+max(CS_t_fxd))*10/1E3);  % number of licks to initialize = number of trials*max time per trial in s*10Hz (of licking)
cuesinit = sum(numtrials);                               % number of cues to initialize
logInit = 10^6;                                      % Log of all serial input events from the Arduino
bgdsolenoidsinit = ceil(sum(numtrials)*truncITI*3/T_bgd);      % number of background solenoids to initialize = total time spent in ITI*rate of rewards*3. It won't be more than 3 times the expected rate

xWindow = [-(truncITI+1000) maxdelaycuetovacuum];  % Defines x-axis limits for the plot.
fractionPSTHdisplay = 0.15;             % What fraction of the display is the PSTH?
yOffset = ceil(fractionPSTHdisplay*sum(numtrials)/(1-fractionPSTHdisplay));% amount by which the y-axis extends beyond trials so as to plot the PSTH of licks
binSize = 1000;                         % in ms
xbins = xWindow(1):binSize:xWindow(2);  % Bins in x-axis for PSTH

ticks = -(truncITI+1000):10000:maxdelaycuetovacuum;% tick marks for x-axis of raster plot. moves through by 2s
labels = ticks'/1000;                     % convert tick labels to seconds
labelsStr = cellstr(num2str(labels));     % convert to cell of strings

durationtrialpartitionnocues = 20E3;      % When experimentmode=2 or 3, how long should a single row for raster plot be?
%% Prep work

% initialize arrays for licks and cues
lickct = [0, 0, 0];% Counter for licks
bgdus = 0;% Counter for background solenoids
fxdus1 = 0;% Counter for fixed solenoid 1s
fxdus2 = 0;% Counter for fixed solenoid 2s
fxdus3 = 0;% Counter for fixed solenoid 3s
fxdus4 = 0;% counter for fixed solenoid 4s
lickretractsolenoid1 = 0;
lickretractsolenoid2 = 0;
vacuum = 0;% Counter for vacuums
cs1 = 0;% Counter for cue 1's
cs2 = 0;% Counter for cue 2's
cs3 = 0;% Counter for cue 3's
light1 = 0;% Counter for light 1's
light2 = 0;% Counter for light 2's
light3 = 0;% Counter for light 3's
both1 = 0;% Counter for both light and cue 1's
both2 = 0;% Counter for both light and cue 2's
both3 = 0;% Counter for both light and cue 3's
eventlog = zeros(logInit,3);% empty event log for all events 
l = 0;% Counter for logged events

% The following variables are declared because they are stored in the
% buffer until a trial ends. This is done so that the plot can be aligned
% to the cue for all trials. Real time plotting cannot work in this case
% since there is variability in intercue interval.
templicks = NaN(ceil(licksinit/sum(numtrials)), 3); % 3 licktubes
templicksct = [0, 0, 0];                                                % count of temp licks. Calculated explicitly to speed up indexing
templicksPSTH1 = NaN(ceil(licksinit/(numtrials(1))),numtrials(1),3); % Array in which all CS1 licks are stored for calculating PSTH 
if numtrials(2)~=0
    templicksPSTH2 = NaN(ceil(licksinit/numtrials(2)),numtrials(2),3); % Array in which all CS2 licks are stored for calculating PSTH 
elseif numtrials(2)==0
    templicksPSTH2 = [];
end
if numtrials(3)~=0
    templicksPSTH3 = NaN(ceil(licksinit/numtrials(3)),numtrials(3),3); % Array in which all CS3 licks are stored for calculating PSTH 
elseif numtrials(3)==0
    templicksPSTH3 = [];
end

hPSTH1 = [];                                                % Handle to lick1 PSTH plot on CS1 trials
hPSTH2 = [];                                                % Handle to lick1 PSTH plot on CS2 trials
hPSTH3 = [];                                                % Handle to lick1 PSTH plot on CS3 trials
hPSTH4 = [];                                                % Handle to lick2 PSTH plot on CS1 trials
hPSTH5 = [];                                                % Handle to lick2 PSTH plot on CS2 trials
hPSTH6 = [];                                                % Handle to lick2 PSTH plot on CS3 trials
hPSTH7 = [];                                                % Handle to lick3 PSTH plot on CS1 trials
hPSTH8 = [];                                                % Handle to lick3 PSTH plot on CS2 trials
hPSTH9 = [];                                                % Handle to lick3 PSTH plot on CS3 trials

tempsolenoids = NaN(ceil((bgdsolenoidsinit+cuesinit)/sum(numtrials)),6); % 6 solenoids
tempsolenoidsct = [0 0 0 0 0 0];


tempcue1 = NaN(1,1);
tempcue2 = NaN(1,1);
tempcue3 = NaN(1,1);
templight1 = NaN(1,1); 
templight2 = NaN(1,1);
templight3 = NaN(1,1);


% setup plot
axes(actvAx)                            % make the activity axes the current one
if experimentmode == 1 || experimentmode == 4 || experimentmode == 6 || experimentmode == 7
    plot(xWindow,[0 0],'k','LineWidth',2);hold on                   % start figure for plots
    set(actvAx,'ytick',[], ...
               'ylim',[-sum(numtrials) yOffset+1], ...
               'ytick',[], ...
               'xlim',xWindow, ...
               'xtick',ticks, ...
               'xticklabel',labelsStr');        % set labels: Raster plot with y-axis containing trials. Chronological order = going from top to bottom
    xlabel('time (s)');
    ylabel('Trials');
elseif experimentmode == 2 || experimentmode == 3
    plot([0 0;0 0],[0 0;-1 -1],'w');hold on
    xlabel('time (s)');
    ylabel(' ');
    xlim([-1000 durationtrialpartitionnocues+1000]);
    set(actvAx,'ytick',[],...
               'xtick',0:2000:durationtrialpartitionnocues,...
               'XTickLabel',num2str((0:2000:durationtrialpartitionnocues)'/1000));
end

drawnow


%% Load to arduino

startT = clock;                                     % find time of start
startTStr = sprintf('%d:%d:%02.0f', ...
                    startT(4),startT(5),startT(6)); % format time
set(handles.startText,'String',startTStr)           % display time
drawnow

wID = 'MATLAB:serial:fscanf:unsuccessfulRead';      % warning id for serial read timeout
warning('off',wID)                                  % suppress warning

running = true;                                     % variable to control program
%%
try
    
%% Collect data from arduino
    while running
        read = [];
        if s.BytesAvailable > 0 % is data available to read? This avoids the timeout problem
            read = fscanf(s,'%f'); % scan for data sent only when data is available
        end
        if isempty(read)
            drawnow
            continue
        end

        l = l + 1;
        eventlog(l,:) = read;                      % maps three things from read (code/time/nosolenoidflag)
        time = read(2);                             % record timestamp
        
        nosolenoidflag = read(3);                     % if =1, no solenoid was actually given. Indicates solenoid omission
        
        code = read(1);                             % read identifier for data
        if code == 0                                % signifies "end of session"
            break
        end

        % Inputs from Arduino along with their "code" (defined below)
        %   1 = Lick1 onset
        %   2 = Lick1 offset
        %   3 = Lick2 onset
        %   4 = Lick2 offset                  
        %   5 = Lick3 onset
        %   6 = Lick3 offset
        %   7 = Background solenoid
        %   8 = Fixed solenoid 1
        %   9 = Fixed solenoid 2                
        %   10 = Fixed solenoid 3
        %   11 = Fixed solenoid 4
        %   12 = Lick retract solenoid 1
        %   13 = Lick retract solenoid 2
        %   14 = Vacuum   
        %   15 = CS1
        %   16 = CS2
        %   17 = CS3                    % leave room for possible cues 
        %   21 = Light 1
        %   22 = Light 2
        %   23 = light 3
        %   25 = both CSsound1 and CSlight1
        %   26 = both CSsound2 and CSlight2
        %   27 = both CSsound3 and CSlight3
        %   30 = frame
        %   31 = laser
        %   32 = solenoid off time
        %   33 = reward indicator 1, for CS1 or lick 1
        %   34 = reward indicator 2, for CS2 or lick 2
        
        
        
        if code == 1                                % Lick1 onset; BLUE
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6                    % Store lick1 timestamp for later plotting after trial ends
                lickct(1) = lickct(1) + 1;
                set(handles.licks1Edit,'String',num2str(lickct(1)))  % change the gui input
                templicksct(1) = templicksct(1)+1;         % keep track of temp licktube number
                templicks(templicksct(1),1) = time;       % keep track of temporary licks timestamp
            elseif experimentmode == 2 || experimentmode == 3 || experimentmode == 7    %If only Poisson solenoids are given or lick for rewards, plot when lick occurs in real time
                lickct(1) = lickct(1) + 1;
                set(handles.licks1Edit,'String',num2str(lickct(1)))
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;                
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'color',[0.2 0.6 1],'LineWidth',1);hold on
            end
        elseif code == 3                            % Lick2 onset; GREY
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6                      % Store lick1 timestamp for later plotting after trial ends
                lickct(2) = lickct(2) + 1;
                set(handles.licks2Edit,'String',num2str(lickct(2)))
                templicksct(2) = templicksct(2)+1;
                templicks(templicksct(2),2) = time;
            elseif experimentmode == 2 || experimentmode == 3 || experimentmode == 7    %If only Poisson solenoids are given or lick for rewards, plot when lick occurs in real time
                lickct(2) = lickct(2) + 1;
                set(handles.licks2Edit,'String',num2str(lickct(2)))
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;                
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',0.65*[1, 1, 1],'LineWidth',1);hold on
            end
        elseif code == 5                                % Lick3 onset; BROWN
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6                     % Store lick3 timestamp for later plotting after trial ends
                lickct(3) = lickct(3) + 1;
                set(handles.licks3Edit,'String',num2str(lickct(3)))  % change the gui input
                templicksct(3) = templicksct(3)+1;         % keep track of temp licktube number
                templicks(templicksct(3),3) = time;       % keep track of temporary licks timestamp
            elseif experimentmode == 2 || experimentmode == 3 || experimentmode == 7    %If only Poisson solenoids are given or lick for rewards, plot when lick occurs in real time
                lickct(3) = lickct(3) + 1;
                set(handles.licks3Edit,'String',num2str(lickct(3)))
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;                
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.3 0 0],'LineWidth',1);hold on
            end
        elseif code == 7                            
            % Background solenoid; cyan (solenoid1) [0.64, 0.08, 0.18] (solenoid2)
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                bgdus = bgdus + 1;
                set(handles.bgdsolenoidsEdit,'String',num2str(bgdus))    % change the gui background solenoid info
                for i = 1:4
                    if backgroundsolenoid == i
                        tempsolenoidsct(i) = tempsolenoidsct(i)+1;       % keep track of solenoid number
                        tempsolenoids(tempsolenoidsct(i),i) = time;     % keep track of tempsolenoid timestamp
                    end
                end
            elseif experimentmode == 2 %If only Poisson solenoids are given, plot when solenoid occurs
                bgdus = bgdus + 1;            
%                   bgdsolenoids(bgdus,1) = time;
                set(handles.bgdsolenoidsEdit,'String',num2str(bgdus))
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                if backgroundsolenoid == 1
                    plot([time-temptrialdur;time-temptrialdur],...
                    [-trial;-trial-1],'c','LineWidth',2);hold on
                elseif backgroundsolenoid == 2
                    plot([time-temptrialdur;time-temptrialdur],...
                    [-trial;-trial-1],'Color',[0.64, 0.08, 0.18],'LineWidth',2);hold on
                elseif backgroundsolenoid == 3
                    plot([time-temptrialdur;time-temptrialdur],...
                    [-trial;-trial-1],'Color',[1 0.5 0],'LineWidth',2);hold on
                end                
            end
        elseif code == 8                            % Fixed solenoid 1; cyan, 'c'
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    fxdus1 = fxdus1 + 1;            
                    set(handles.fxdsolenoids1Edit,'String',num2str(fxdus1))
                    tempsolenoidsct(1) = tempsolenoidsct(1)+1;      % keep track of solenoid1 count
                    tempsolenoids(tempsolenoidsct(1), 1) = time;   % keep track of solenoid1 timestamp
                end
            elseif experimentmode == 3 || experimentmode == 7
                if nosolenoidflag == 0
                    fxdus1 = fxdus1 + 1;
                    set(handles.fxdsolenoids1Edit,'String',num2str(fxdus1))
                    trial = floor(time/durationtrialpartitionnocues);
                    temptrialdur = trial*durationtrialpartitionnocues;
                    plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'c','LineWidth',2);hold on
                end
            end
        elseif code == 9                            % Fixed solenoid 2; [0.64, 0.08, 0.18]
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    fxdus2 = fxdus2 + 1;            
                    set(handles.fxdsolenoids2Edit,'String',num2str(fxdus2))
                    tempsolenoidsct(2) = tempsolenoidsct(2)+1;      % keep track of solenoid2 count
                    tempsolenoids(tempsolenoidsct(2), 2) = time;   % keep track of solenoid2 timestamp
                end
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     fxdus2 = fxdus2 + 1;
                     set(handles.fxdsolenoids2Edit,'String',num2str(fxdus2))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.64 0.08 0.18],'LineWidth',2);hold on
                 end
            end      
        elseif code == 10                            % Fixed solenoid 3; orange [1 0.5 0]
             if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    fxdus3 = fxdus3 + 1;            
                    set(handles.fxdsolenoids3Edit,'String',num2str(fxdus3))
                    tempsolenoidsct(3) = tempsolenoidsct(3)+1;      % keep track of solenoid3 count
                    tempsolenoids(tempsolenoidsct(3), 3) = time;   % keep track of solenoid3 timestamp
                end 
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     fxdus3 = fxdus3 + 1;
                     set(handles.fxdsolenoids3Edit,'String',num2str(fxdus3))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[1 0.5 0],'LineWidth',2);hold on
                 end
            end 
        elseif code == 11                            % Fixed solenoid 4; [0.72 0.27 1]
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    fxdus4 = fxdus4 + 1;            
                    set(handles.fxdsolenoids4Edit,'String',num2str(fxdus4))
                    tempsolenoidsct(4) = tempsolenoidsct(4)+1;      % keep track of solenoid4 count
                    tempsolenoids(tempsolenoidsct(4), 4) = time;   % keep track of solenoid4 timestamp
                end 
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     fxdus4 = fxdus4 + 1;
                     set(handles.fxdsolenoids4Edit,'String',num2str(fxdus4))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.72 0.27 1],'LineWidth',2);hold on
                 end
            end 
        elseif code == 12                            % Lick retraction solenoid1; [0.3 0.75 0.93]
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    lickretractsolenoid1 = lickretractsolenoid1 + 1;            
                    set(handles.lickretractsolenoid1Edit,'String',num2str(lickretractsolenoid1))
                    tempsolenoidsct(5) = tempsolenoidsct(5)+1;      % keep track of solenoid4 count
                    tempsolenoids(tempsolenoidsct(5), 5) = time;   % keep track of solenoid4 timestamp
                end 
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     lickretractsolenoid1 = lickretractsolenoid1 + 1;
                     set(handles.lickretractsolenoid1Edit,'String',num2str(lickretractsolenoid1))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.3 0.75 0.93],'LineWidth',2);hold on
                 end
            end 
        elseif code == 13                            % Lick retraction solenoid2; [0.97 0.28 0.18]
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    lickretractsolenoid2 = lickretractsolenoid2 + 1;            
                    set(handles.lickretractsolenoid2Edit,'String',num2str(lickretractsolenoid2))
                    tempsolenoidsct(6) = tempsolenoidsct(6)+1;      % keep track of solenoid4 count
                    tempsolenoids(tempsolenoidsct(6), 6) = time;   % keep track of solenoid4 timestamp
                end 
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     lickretractsolenoid2 = lickretractsolenoid2 + 1;
                     set(handles.lickretractsolenoid2Edit,'String',num2str(lickretractsolenoid2))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.97 0.28 0.18],'LineWidth',2);hold on
                 end
            end 
        elseif code == 18                            % Lick retraction solenoid1 and 2;
            if experimentmode == 1 || experimentmode == 4 || experimentmode == 6
                if nosolenoidflag == 0                      % Indicates trial with solenoid
                    lickretractsolenoid1 = lickretractsolenoid1 + 1;
                    set(handles.lickretractsolenoid1Edit,'String',num2str(lickretractsolenoid1))
                    tempsolenoidsct(5) = tempsolenoidsct(5)+1;      % keep track of solenoid4 count
                    tempsolenoids(tempsolenoidsct(5), 5) = time;   % keep track of solenoid4 timestamp
                    lickretractsolenoid2 = lickretractsolenoid2 + 1;            
                    set(handles.lickretractsolenoid2Edit,'String',num2str(lickretractsolenoid2))
                    tempsolenoidsct(6) = tempsolenoidsct(6)+1;      % keep track of solenoid4 count
                    tempsolenoids(tempsolenoidsct(6), 6) = time;   % keep track of solenoid4 timestamp
                end 
             elseif experimentmode == 3 || experimentmode == 7
                 if nosolenoidflag == 0
                     lickretractsolenoid2 = lickretractsolenoid2 + 1;
                     set(handles.lickretractsolenoid2Edit,'String',num2str(lickretractsolenoid2))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.97 0.28 0.18],'LineWidth',2);hold on
                     lickretractsolenoid1 = lickretractsolenoid1 + 1;
                     set(handles.lickretractsolenoid1Edit,'String',num2str(lickretractsolenoid1))
                     trial = floor(time/durationtrialpartitionnocues);
                     temptrialdur = trial*durationtrialpartitionnocues;
                     plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.3 0.75 0.93],'LineWidth',2);hold on
                 end
            end 
        elseif code == 14                            % Vaccum;            
            if experimentmode ==1 || experimentmode == 4 || experimentmode == 6
                tempcuetovacuumdelay = NaN;
                if ~isnan(tempcue1)                      % indicates there is cue1
                    tempcuetovacuumdelay = time - tempcue1;      
                    for i=1:3
                        templicksPSTH1(1:length(templicks(:,i)),cs1,i) = templicks(:,i)-time+tempcuetovacuumdelay; % run over each licktube
                    end                
                    tempcue1 = 0;
                elseif ~isnan(tempcue2)
                    tempcuetovacuumdelay = time - tempcue2;
                    for i=1:3
                        templicksPSTH2(1:length(templicks(:,i)),cs2,i) = templicks(:,i)-time+tempcuetovacuumdelay;
                    end
                    tempcue2 = 0;
                elseif ~isnan(tempcue3)
                    tempcuetovacuumdelay = time - tempcue3;
                    for i=1:3
                        templicksPSTH3(1:length(templicks(:,i)),cs3,i) = templicks(:,i)-time+tempcuetovacuumdelay;
                    end
                    tempcue3 = 0;
                end
                if ~isnan(templight1)                      % indicates there is light1
                    tempcuetovacuumdelay = time - templight1;      
                    for i=1:3
                        templicksPSTH1(1:length(templicks(:,i)),light1,i) = templicks(:,i)-time+tempcuetovacuumdelay; % run over each licktube
                    end                
                    templight1 = 0;
                elseif ~isnan(templight2)
                    tempcuetovacuumdelay = time - templight2;
                    for i=1:3
                        templicksPSTH2(1:length(templicks(:,i)),light2,i) = templicks(:,i)-time+tempcuetovacuumdelay;
                    end
                    templight2 = 0;
                elseif ~isnan(templight3)
                    tempcuetovacuumdelay = time - templight3;
                    for i=1:3
                        templicksPSTH3(1:length(templicks(:,i)),light3,i) = templicks(:,i)-time+tempcuetovacuumdelay;
                    end
                    templight3 = 0;       
                end
                tempsolenoids = tempsolenoids-time+tempcuetovacuumdelay; %find timestamps wrt vacuum         
                templicks = templicks-time+tempcuetovacuumdelay;

                % Raster plot
                cs = cs1+cs2+cs3+light1+light2+light3-both1-both2-both3;


                plot([templicks(:,1) templicks(:,1)],[-(cs-1) -cs],'color',[0.2 0.6 1],'LineWidth',1);hold on    % lick1            
                plot([templicks(:,2) templicks(:,2)],[-(cs-1) -cs],'Color',0.65*[1, 1, 1],'LineWidth',1);hold on   %lick2            
                plot([templicks(:,3) templicks(:,3)],[-(cs-1) -cs],'Color',[0.3 0 0],'LineWidth',1);hold on    % lick3            

                plot([tempsolenoids(:,1) tempsolenoids(:,1)],[-(cs-1) -cs],'c','LineWidth',2);hold on       % solenoid1
                plot([tempsolenoids(:,2) tempsolenoids(:,2)],[-(cs-1) -cs],'Color',[0.64, 0.08, 0.18],'LineWidth',2);hold on    % solenoid2
                plot([tempsolenoids(:,3) tempsolenoids(:,3)],[-(cs-1) -cs],'Color',[1 0.5 0],'LineWidth',2);hold on      % solenoid3
                plot([tempsolenoids(:,4) tempsolenoids(:,4)],[-(cs-1) -cs],'Color',[0.72, 0.27, 1],'LineWidth',2);hold on       % solenoid4
                plot([tempsolenoids(:,5) tempsolenoids(:,5)],[-(cs-1) -cs],'Color',[0.3 0.75 0.93],'LineWidth',2);hold on      % lickretractsolenoid1 
                plot([tempsolenoids(:,6) tempsolenoids(:,6)],[-(cs-1) -cs],'Color',[0.97 0.28 0.18],'LineWidth',2);hold on       % lickretractsolenoid2

                plot([tempcue1 tempcue1],[-(cs-1) -cs],'g','LineWidth',2);hold on       % cue1
                plot([tempcue2 tempcue2],[-(cs-1) -cs],'r','LineWidth',2);hold on       % cue2
                plot([tempcue3 tempcue3],[-(cs-1) -cs],'b','LineWidth',2);hold on       % cue3
                plot([templight1 templight1],[-(cs-1) -cs],'Color',[0 0.45 0.74],'LineWidth',2);hold on       % light1
                plot([templight2 templight2],[-(cs-1) -cs],'Color',[0.93 0.69 0.13],'LineWidth',2);hold on    % light2
                plot([templight3 templight3],[-(cs-1) -cs],'Color',[0.85 0.33 0.1],'LineWidth',2);hold on     % light3

                % Begin PSTH plotting
                delete(hPSTH1);delete(hPSTH2);delete(hPSTH3); %Clear previous PSTH plots  
                delete(hPSTH4);delete(hPSTH5);delete(hPSTH6); %Clear previous PSTH plots  
                delete(hPSTH7);delete(hPSTH8);delete(hPSTH9); %Clear previous PSTH plots      
                if ~isempty(templicksPSTH1)
                    if sum(~isnan(templicksPSTH1(:,:,1)), 'all')>0
                        temp = templicksPSTH1(:,:,1);
                        nPSTH1 = histc(temp(~isnan(temp)),xbins); % Count licks1 in each bin for all trials until now
                        nPSTH1 = nPSTH1/max(nPSTH1); % Plot PSTH for CS1 scaled to the available range on the y-axis 
                        hPSTH1 = plot(xbins,nPSTH1*yOffset,'Marker','o','MarkerFaceColor',[0.47 0.67 0.19],'Color',[0.47 0.67 0.19]);
                        hold on;
                    end
                    if sum(~isnan(templicksPSTH1(:,:,2)), 'all')>0
                        assignin('base','templicksPSTH1',templicksPSTH1);
                        assignin('base','xbins',xbins);
                        temp = templicksPSTH1(:,:,2);
                        nPSTH1 = histc(temp(~isnan(temp)),xbins); % Count licks2 in each bin for all trials until now
                        nPSTH1 = nPSTH1/max(nPSTH1); % Plot PSTH for CS1 scaled to the available range on the y-axis            
                        hPSTH4 = plot(xbins,nPSTH1*yOffset,'Marker','o','MarkerFaceColor',[0.27 0.67 0.19],'Color',[0.27 0.67 0.19]);
    %                     hold on;
                    end
                    if sum(~isnan(templicksPSTH1(:,:,3)), 'all')>0
                        assignin('base','templicksPSTH1',templicksPSTH1);
                        assignin('base','xbins',xbins);
                        temp = templicksPSTH1(:,:,3);
                        nPSTH1 = histc(temp(~isnan(temp)),xbins); % Count licks3 in each bin for all trials until now
                        nPSTH1 = nPSTH1/max(nPSTH1); % Plot PSTH for CS1 scaled to the available range on the y-axis            
                        hPSTH7 = plot(xbins,nPSTH1*yOffset,'Marker','o','MarkerFaceColor',[0.09 0.43 0.02],'Color',[0.09 0.43 0.02]);
    %                     hold on;
                    end
                end
                if ~isempty(templicksPSTH2)
                    if sum(~isnan(templicksPSTH2(:,:,1)), 'all')>0
                        temp = templicksPSTH2(:,:,1);
                        nPSTH2 = histc(temp(~isnan(temp)),xbins); % Count licks1 in each bin for all trials until now
                        nPSTH2 = nPSTH2/max(nPSTH2); % Plot PSTH for CS2 scaled to the available range on the y-axis
                        hPSTH2 = plot(xbins,nPSTH2*yOffset,'Marker','o','MarkerFaceColor',[1 0.6 0.78],'Color',[1 0.6 0.78]);
    %                     hold on;
                    end
                    if sum(~isnan(templicksPSTH2(:,:,2)), 'all')>0
                        temp = templicksPSTH2(:,:,2);
                        nPSTH2 = histc(temp(~isnan(temp)),xbins); % Count licks2 in each bin for all trials until now
                        nPSTH2 = nPSTH2/max(nPSTH2); % Plot PSTH for CS2 scaled to the available range on the y-axis
                        hPSTH5 = plot(xbins,nPSTH2*yOffset,'Marker','o','MarkerFaceColor',[1 0.35 0.78],'Color',[1 0.35 0.78]);
    %                     hold on;
                    end
                    if sum(~isnan(templicksPSTH2(:,:,3)), 'all')>0
                        temp = templicksPSTH2(:,:,3);
                        nPSTH2 = histc(temp(~isnan(temp)),xbins); % Count licks3 in each bin for all trials until now
                        nPSTH2 = nPSTH2/max(nPSTH2); % Plot PSTH for CS2 scaled to the available range on the y-axis
                        hPSTH8 = plot(xbins,nPSTH2*yOffset,'Marker','o','MarkerFaceColor',[0.79 0.03 0.56],'Color',[0.79 0.03 0.56]);
    %                     hold on;
                    end
                end
                if ~isempty(templicksPSTH3)
                    if sum(~isnan(templicksPSTH3(:,:,1)), 'all')>0
                        temp = templicksPSTH3(:,:,1);
                        nPSTH3 = histc(temp(~isnan(temp)),xbins); % Count licks1 in each bin for all trials until now
                        nPSTH3 = nPSTH3/max(nPSTH3); % Plot PSTH for CS3 scaled to the available range on the y-axis
                        hPSTH3 = plot(xbins,nPSTH3*yOffset,'Marker','o','MarkerFaceColor',[0.2 0.6 1],'Color',[0.2 0.6 1]);
    %                     hold on;
                    end
                    if sum(~isnan(templicksPSTH3(:,:,2)), 'all')>0
                        temp = templicksPSTH3(:,:,2);
                        nPSTH3 = histc(temp(~isnan(temp)),xbins); % Count licks2 in each bin for all trials until now
                        nPSTH3 = nPSTH3/max(nPSTH3); % Plot PSTH for CS3 scaled to the available range on the y-axis
                        hPSTH6 = plot(xbins,nPSTH3*yOffset,'Marker','o','MarkerFaceColor',[0.2 0.35 1],'Color',[0.2 0.35 1]);
    %                     hold on;
                    end
                    if sum(~isnan(templicksPSTH3(:,:,3)), 'all')>0
                        temp = templicksPSTH3(:,:,3);
                        nPSTH3 = histc(temp(~isnan(temp)),xbins); % Count licks3 in each bin for all trials until now
                        nPSTH3 = nPSTH3/max(nPSTH3); % Plot PSTH for CS3 scaled to the available range on the y-axis
                        hPSTH9 = plot(xbins,nPSTH3*yOffset,'Marker','o','MarkerFaceColor',[0.03 0.14 0.69],'Color',[0.03 0.14 0.69]);
    %                     hold on;
                    end
                end
                drawnow
                % End PSTH plotting

                % Re-initialize the temp variables
                templicks = NaN(ceil(licksinit/sum(numtrials)),3);
                templicksct = [0, 0, 0]; %count of temp licks. Calculated explicitly to speed up indexing
                tempsolenoid1s = NaN(ceil((bgdsolenoidsinit+cuesinit)/sum(numtrials)),1);
                tempsolenoid2s = NaN(ceil((bgdsolenoidsinit+cuesinit)/sum(numtrials)),1);
                tempsolenoid3s = NaN(ceil((bgdsolenoidsinit+cuesinit)/sum(numtrials)),1);
                tempsolenoid4s = NaN(ceil((bgdsolenoidsinit+cuesinit)/sum(numtrials)),1);            
                tempsolenoid1sct = 0;
                tempsolenoid2sct = 0;
                tempsolenoid3sct = 0;
                tempsolenoid4sct = 0;
                tempcue1 = NaN;
                tempcue2 = NaN;
                tempcue3 = NaN;  
                templight1 = NaN; 
                templight2 = NaN;
                templight3 = NaN;
            end
        elseif code == 15                            % CS1 cue onset; GREEN
            cs1 = cs1 + 1;
            set(handles.cues1Edit,'String',num2str(cs1))
            tempcue1 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3  || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'g','LineWidth',2);hold on
            end
        elseif code == 16                            % CS2 cue onset; RED
            cs2 = cs2 + 1;         
            set(handles.cues2Edit,'String',num2str(cs2))            
            tempcue2 = time;            
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'r','LineWidth',2);hold on
            end
        elseif code == 17                            % CS3 cue onset; BLUE
            cs3 = cs3 + 1;         
            set(handles.cues3Edit,'String',num2str(cs3))            
            tempcue3 = time;            
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'b','LineWidth',2);hold on
            end
        elseif code == 21                            % CS1 light onset;
            light1 = light1 + 1;
            set(handles.light1Edit,'String',num2str(light1))
            templight1 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0 0.45 0.74],'LineWidth',2);hold on
            end
        elseif code == 22                            % CS2 light onset;
            light2 = light2 + 1;
            set(handles.light2Edit,'String',num2str(light2))
            templight2 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.93 0.69 0.13],'LineWidth',2);hold on
            end
        elseif code == 23                            % CS3 light onset;
            light3 = light3 + 1;
            set(handles.light3Edit,'String',num2str(light3))
            templight3 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.85 0.33 0.1],'LineWidth',2);hold on %light cue3
            end
        elseif code == 25                           % both CS1 sound and light onset;
            both1 = both1 + 1;
            cs1 = cs1 + 1;
            set(handles.cues1Edit,'String',num2str(cs1))
            tempcue1 = time;
            light1 = light1 + 1;
            set(handles.light1Edit,'String',num2str(light1))
            templight1 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0 0.45 0.74],'LineWidth',2);hold on %light cue1
            end
        elseif code == 26                           % both CS2 sound and light onset;                     
            both2 = both2 + 1;
            cs2 = cs2 + 1;
            set(handles.cues2Edit,'String',num2str(cs2))
            tempcue2 = time;
            light2 = light2 + 1;
            set(handles.light2Edit,'String',num2str(light2))
            templight2 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.93 0.69 0.13],'LineWidth',2);hold on %light cue2
            end
        elseif code == 27                           % both CS3 sound and light onset;
            both3 = both3 + 1;
            cs3 = cs3 + 1;
            set(handles.cues3Edit,'String',num2str(cs3))
            tempcue3 = time;
            light3 = light3 + 1;
            set(handles.light3Edit,'String',num2str(light3))
            templight3 = time;
            if cs1+cs2+cs3+light1+light2+light3-both1-both2-both3<sum(numtrials)
                fprintf('Executing trial %d\n',cs1+cs2+cs3+light1+light2+light3-both1-both2-both3);
            end
            if experimentmode == 3 || experimentmode == 7
                trial = floor(time/durationtrialpartitionnocues);
                temptrialdur = trial*durationtrialpartitionnocues;
                plot([time-temptrialdur;time-temptrialdur],[-trial;-trial-1],'Color',[0.85 0.33 0.1],'LineWidth',2);hold on %light cue3
            end
        end
    end
    
    if l < logInit
        eventlog = eventlog(1:l,:);   % smaller eventlog
    end
    

%% Save data

    format = 'yymmdd-HHMMSS';
    date = datestr(now,format);
    
    if experimentmode == 1
        str = 'cues_';
    elseif experimentmode == 2
        str = 'randomrewards_';
    elseif experimentmode == 3
        str = 'lickforreward_';
    elseif experimentmode == 4
        str = 'decisionmaking_';
    elseif experimentmode == 5
        str = 'serialporttest_';
    elseif experimentmode == 6
        str = 'ramptiming_';
    elseif experimentmode == 7
        str = 'delaydiscounting_';
    end
    
%     if randlaserflag==0 && laserlatency==0 && laserduration==CS_t_fxd(1)
%         laserstr = 'lasercue_';
%     elseif randlaserflag==0 && laserlatency==CS_t_fxd(1) && laserduration==CS_t_fxd(1)
%         laserstr = 'lasersolenoid_';
%     elseif randlaserflag==0 && laserlatency==0 && laserduration==1000
%         laserstr = 'lasercueonset_';
%     elseif randlaserflag==0 && laserlatency==2000 && laserduration==1000
%         laserstr = 'lasercuetrace_';
%     elseif randlaserflag ==1
%         laserstr = 'randlaser_';
%     else
%         laserstr = [];
%     end
%     if lasertrialbytrialflag==1 && laserduration > 0
%         laserstr = [laserstr 'trialbytriallaser_'];
%     end
%     
%     if trialbytrialbgdsolenoidflag == 1
%         bgdsolenoidstr = 'trialbytrialbgd_';
%     else
%         bgdsolenoidstr = [];
%     end
%     
%     if sum(CSopentime) == 0
%         extinctionstr = 'extinction_';
%     else
%         extinctionstr = [];
%     end
%     
%     probstr = ['CSprob' sprintf('_%u', CSprob)];
    
    assignin('base','eventlog',eventlog);
%     file = [saveDir fname '_' num2str(r_bgd) '_' num2str(T_bgd) '_'  str probstr laserstr bgdsolenoidstr extinctionstr date '.mat'];
    file = [saveDir fname '_' str date '.mat'];
    save(file, 'eventlog', 'params')

catch exception
    if l < logInit
        eventlog = eventlog(1:l,:);
    end
    
    fprintf(s,'1');                                  % send stop signal to arduino; 49 in Arduino is the ASCII code for 1
    disp('Error running program.')
    format = 'yymmdd-HHMMSS';
    date = datestr(now,format);
    
    
    if experimentmode == 1
        str = 'cues_';
    elseif experimentmode == 2
        str = 'randomrewards_';
    elseif experimentmode == 3
        str = 'lickforreward_';
    elseif experimentmode == 4
        str = 'decisionmaking_';
    elseif experimentmode == 5
        str = 'serialporttest_';
    elseif experimentmode == 6
        str = 'ramptiming_';
    elseif experimentmode == 7
        str = 'delaydiscounting_';
    end
    
%     if randlaserflag==0 && laserlatency==0 && laserduration==CS_t_fxd(1)
%         laserstr = 'lasercue_';
%     elseif randlaserflag==0 && laserlatency==CS_t_fxd(1) && laserduration==CS_t_fxd(1)
%         laserstr = 'lasersolenoid_';
%     elseif randlaserflag==0 && laserlatency==0 && laserduration==1000
%         laserstr = 'lasercueonset_';
%     elseif randlaserflag==0 && laserlatency==2000 && laserduration==1000
%         laserstr = 'lasercuetrace_';
%     elseif randlaserflag ==1
%         laserstr = 'randlaser_';
%     else
%         laserstr = [];
%     end
%     
%     if lasertrialbytrialflag==1 && laserduration > 0
%         laserstr = [laserstr 'trialbytriallaser_'];
%     end
%     
%     if trialbytrialbgdsolenoidflag == 1
%         bgdsolenoidstr = 'trialbytrialbgd_';
%     else
%         bgdsolenoidstr = [];
%     end
%     
%     if sum(CSopentime) == 0
%         extinctionstr = 'extinction_';
%     else
%         extinctionstr = [];
%     end
%     
%     probstr = ['CSprob' sprintf('_%u', CSprob)];
    
    assignin('base','eventlog',eventlog);
    
%     file = [saveDir fname '_' num2str(r_bgd) '_' num2str(T_bgd) '_'  str probstr laserstr bgdsolenoidstr extinctionstr date '.mat'];
    file = [saveDir '_error_' fname '_' str date '.mat'];
    save(file, 'eventlog', 'params','exception')
end