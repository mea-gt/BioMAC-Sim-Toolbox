                                               %======================================================================
%> @file FAME\MyImplementationFC\evaluateCODrunning3DwthMeasuredIMU.m
%> @brief Script to evaluate simulated joint angles, joint moments, GRFs
% (and possibly accelerometer/gyro data)
%> @example
%> @details
%> This script can be used to calculate the RMSE and correlation between
%the measured and simulation kinetic-kinematic data of interest.
%>
%> @author Maria Eleni Athanasiadou
%> @date December, 2024
%======================================================================

% ======================================================================
%> @brief Function to obtain the simVarTable of simulation results and
%compute the RMSEs and correlations for joint angles, pelvic translations,
%GRFs or other variables of interest, as well as the path of the
%simulation's skeleton. Make sure to add to the path the correct
%BioSimToolbox, depending on which toolbox was used to generated the
%simulations inside 'resultFilesIn'. Simulations that were generated using
%the old toolbox should add the old toolbox to the path.
%>
%> @param   resultFilesIn       Array with 1 or more elements containing the
%                               file names of the simulation result files (for example:
%                               '2024_12_18_scriptCODfromMeasIMU_CODrunning'
%                               '2024_12_19_scriptCODfromMeasIMU_CODrunning' etc)
%> @param   rotatePath          Boolean: true if you want to rotate the
%                               simulations' path by the pelvis angle at the first time node. False
%                               otherwise
%> @retval  simVarTableOutput   Objective values for input option 'objval' or vector
%>                  with gradient for input option 'gradient'
% ======================================================================

% clear all 
% close all
% clc


%TODO: add inputVars for subjId, trialType --> use those to find the
%correct directory and then find the 4 mat files (1 mat file from each
%of the 4 simulations) based on the foldername suffixes (-CODinitGuess, _tfs, _fts & _ftc).

function simVarTableOutput = evaluateCODrunning3DwthMeasuredIMU(rotatePath)

    pID={1,2,3,4,5};
    for partLoopIdx=1:length(pID)

        %% Settings
        % Get path of this script
        filePath = fileparts(mfilename('fullpath'));
        % Path to your repository
        path2repo = [filePath filesep '..' filesep '..'];
        
        % Fixed settings
        [participant, resultFilesIn]=setSettings(pID{partLoopIdx});
        %participant.ID = 's01';
        %participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s01_baseline.osim';
        participant.trialType = 'Baseline';
        dataFolder     = ['data' filesep 'MaroCODsims' filesep 'DataStructsForInnsbruckOldDtaFromJiating'];    % Relative from the path of the repository
        %participant.dataFile       = 'data_Erlangen_cut135_s01_3D_1_measuredIMU.mat'; % datastruct object created by Jiating's code
        %%%%modelFile      = 'gait3d_pelvis213.osim';        % Name of our default model with adapted pelvis rotation order in constrast to Hamners model
        resultFolder   = ['results' filesep 'MaroCODsims']; % Relative from the path of the repository
        
        %% Initalization
        % Get date
        dateString = datestr(date, 'yyyy_mm_dd');
        
        % Get absolute file names for produced simulations
        %1st file=simB (bbno), 2nd file=simC (bbwo), 3rd file=simA (sbno), 4th file=simD(velocity dir obj + standing init
        %guess), 5th file=simE(velocity dir obj + COD init guess), 6th file=simF(velocity dir obj + COD init guess, using new toolbox)
        
        %resultNewToolboxVelDirObj = 'NewToolboxResults/ToolboxSimulationResults/20_02_2025/2025_02_20_scriptCODfromMeasIMU_CODrunning';
        %resultFileNames = {'2024_12_18_scriptCODfromMeasIMU_CODrunning' '2024_12_19_scriptCODfromMeasIMU_CODrunning' '2024_12_21_scriptCODfromMeasIMU_CODrunning', '2025_01_29_scriptCODfromMeasIMU_CODrunning', '2025_01_29_scriptCODfromMeasIMU_CODrunning-CODinitGuess'};%, resultNewToolboxVelDirObj};
        resultFileNames = resultFilesIn;
        for i=1:length(resultFileNames)
            resultFilesCODRunning{i} = [path2repo,filesep,resultFolder,filesep,participant.ID, filesep, participant.trialType, filesep, resultFileNames{i},'.mat'];
        end
        dataFile                = [path2repo,filesep,dataFolder,filesep,participant.ID,filesep,participant.trialType,filesep,participant.dataFile];
        dataPath                = [path2repo,filesep,dataFolder];
        modelPath          = participant.modelFile;%[path2repo,filesep,dataFolder,filesep,participant.ID,filesep,participant.trialType,filesep,'OpenSimFiles',filesep,participant.modelFile];
        
        addpath(dataPath);
        
        % Create resultfolder if it does not exist
        if ~exist([path2repo,filesep,resultFolder], 'dir')
            mkdir([path2repo,filesep,resultFolder]);
        end
        
        %Load result data for each simulation
        for i=1:length(resultFilesCODRunning)
            resultData(i) = load(resultFilesCODRunning{i}); 
        end
        
        % Load tracking data struct and create a TrackingData object
        trackingData = TrackingData.loadStruct(dataFile);
        trackingData.resampleData(resultData(1).result.problem.nNodes);
        trackingDataVariables = trackingData.variables;
        
        % set the start point of the translation in x and z axis to 0
        trackingDataVariables.mean{53,1} = trackingDataVariables.mean{53,1} - trackingDataVariables.mean{53,1}(1);
        trackingDataVariables.mean{55,1} = trackingDataVariables.mean{55,1} - trackingDataVariables.mean{55,1}(1);
        
        %dummy variable to later-on store unwanted rows of trackingDataVariables, 
        %that will be deleted
        rowsToDelete = false(height(trackingDataVariables), 1);
        
        for j=1:length(trackingDataVariables.name)
            dofName = trackingDataVariables.name(j);
            dofType = trackingDataVariables.type{j};
            if strcmp(dofType, 'acc') || strcmp(dofType, 'gyro')
                %marking acceleration and gyro rows to be deleted
                %although they could be included in simVarTableIMU, 
                %they have 100 time nodes whereas the simulation and tracked acc
                %have 99 time nodes
                disp('Acc/Gyro found');
                rowsToDelete(j)=true;
            elseif strcmp(dofName, 'pelvis_tilt')
                disp('pelvis tilt found at ' + string(j));
                trackingDataVariables.name{j}='pelvis_rotation';
            elseif strcmp(dofName, 'pelvis_list')
                trackingDataVariables.name{j}='pelvis_obliquity';
            elseif strcmp(dofName, 'pelvis_rotation')
                trackingDataVariables.name{j}='pelvis_tilt';
            elseif strcmp(dofName,'knee_angle_r') || strcmp(dofName,'knee_angle_l') || strcmp(dofName,'mtp_angle_r') || strcmp(dofName,'mtp_angle_l')
                trackingDataVariables.mean{j}=-trackingDataVariables.mean{j};
                %dataJointAngles.mean(i) = num2cell(-dataJointAngles.mean{i},1);
            end 
        end
        
        trackingDataVariables(rowsToDelete,:)=[];
        
        % Adapt style to your needs
        style = struct();
        style.xLabelText  = 'Motion in \%';
        style.subFigSettings.nCol = 7;
        style.subFigSettings.width       = 5.5; % in cm
        style.subFigSettings.height      = 5;   % in cm
        style.subFigSettings.originUp    = 3;   % in cm
        style.subFigSettings.originRight = 1.5; % in cm
        style.subFigSettings.oneUp       = 1.0; % in cm
        style.subFigSettings.oneRight    = 1.5; % in cm     
    
        %create simVarTableIMU for each simulation
        for i=1:length(resultFilesCODRunning)
            dofNames = resultData(i).result.problem.model.dofs.Properties.RowNames;
            idxTrans = ismember(dofNames, {'pelvis_tx', 'pelvis_ty', 'pelvis_tz'});
            %idxAngle = ~ismember(dofNames, {});
            settings.translation = dofNames(idxTrans);
            settings.angle = dofNames(~idxTrans);
            settings.torque = dofNames(resultData(i).result.problem.model.idxTorqueDof); % all arm DOFs
            settings.acc = resultData(i).result.problem.objectiveTerms(strcmp({resultData(i).result.problem.objectiveTerms.name}, 'trackAcc')).varargin{1}.variables;
            settings.gyro = resultData(i).result.problem.objectiveTerms(strcmp({resultData(i).result.problem.objectiveTerms.name}, 'trackGyro')).varargin{1}.variables;
            
    
    
            %simVarTableIMU.(['simulationResult',num2str(i)]) = resultData(i).result.problem.extractData(resultData(i).result.X, settings, trackingDataVariables);
    
    
            if contains(resultFilesCODRunning{i}, 'CODinitGuess')
                simSetupName='CODinitGuess';
            elseif contains(resultFilesCODRunning{i}, 'tfs')
                simSetupName='tfs';
            elseif contains(resultFilesCODRunning{i}, 'fts')
                simSetupName='fts';
            elseif contains(resultFilesCODRunning{i}, 'ftc')
                simSetupName='ftc';
            end
            simVarTableIMU.([participant.ID,simSetupName]) = resultData(i).result.problem.extractData(resultData(i).result.X, settings, trackingDataVariables);
    
    
    
    
            rowsToDelete2 = false(height(simVarTableIMU.([participant.ID,simSetupName])), 1);
        
            %remove unneeded joint angles
            for ind=1:height(simVarTableIMU.([participant.ID,simSetupName]))
                dofNames = simVarTableIMU.([participant.ID,simSetupName]).name;        
                if strcmp(dofNames{ind}, 'arm_flex_r') || strcmp(dofNames{ind}, 'arm_add_r') || ...
                    strcmp(dofNames{ind}, 'arm_rot_r') || strcmp(dofNames{ind}, 'elbow_flex_r') || ...
                    strcmp(dofNames{ind}, 'pro_sup_r') || strcmp(dofNames{ind}, 'arm_flex_l') || ...
                    strcmp(dofNames{ind}, 'arm_add_l') || strcmp(dofNames{ind}, 'arm_rot_l') || ...
                    strcmp(dofNames{ind}, 'elbow_flex_l') || strcmp(dofNames{ind}, 'pro_sup_l')
                    rowsToDelete2(ind) = true; 
                end
            end
            simVarTableIMU.([participant.ID,simSetupName])(rowsToDelete2,:)=[];
        
            if rotatePath == true
                initMeasPelvRotat = simVarTableIMU.([participant.ID,simSetupName]).mean_extra{4,1}(1,:);
                initSimPelvRotat = simVarTableIMU.([participant.ID,simSetupName]).sim{4,1}(1,:);
                simVarTableIMU.([participant.ID,simSetupName]).sim{4,1} = simVarTableIMU.([participant.ID,simSetupName]).sim{4,1} + initMeasPelvRotat;
                
                initMeasPelvRotat = deg2rad(initMeasPelvRotat);
                initSimPelvRotat = deg2rad(initSimPelvRotat);
            
                pelvRotDiff = initMeasPelvRotat-initSimPelvRotat;
            
                R = [
                    cos(pelvRotDiff), 0, sin(pelvRotDiff);
                    0,                1, 0;
                    -sin(pelvRotDiff),0, cos(pelvRotDiff)
                ];
            
                translations = [simVarTableIMU.([participant.ID,simSetupName]).sim{1,1}'; simVarTableIMU.([participant.ID,simSetupName]).sim{2,1}'; simVarTableIMU.([participant.ID,simSetupName]).sim{3,1}'];
            
                rotatedTranslations = R * translations;
            
                simVarTableIMU.([participant.ID,simSetupName]).sim{1,1} = rotatedTranslations(1,:)';
                simVarTableIMU.([participant.ID,simSetupName]).sim{2,1} = rotatedTranslations(2,:)';
                simVarTableIMU.([participant.ID,simSetupName]).sim{3,1} = rotatedTranslations(3,:)';
            end
        
        %     idxDOFs_tx = resultData(i).result.problem.model.extractState('q', 'pelvis_tx');
        %     idxAll_tx= resultData(i).result.problem.idx.states(idxDOFs_tx,:);
        %     txResult = resultData(i).result.X(idxAll_tx,1);
        %     idxDOFs_tz = resultData(i).result.problem.model.extractState('q', 'pelvis_tz');
        %     idxAll_tz= resultData(i).result.problem.idx.states(idxDOFs_tz,:);
        %     tzResult = resultData(i).result.X(idxAll_tz,1);
        
            %{
            %Plot the simulated path of the pelvis against the measured one, for each simulation
            figure(i);
            titleAdd=["bbno", "bbwo", "sbno"];
            %plot(txResult, tzResult);
            plot(simVarTableIMU.(['simulationResult',num2str(i)]).sim{3,1}, simVarTableIMU.(['simulationResult',num2str(i)]).sim{1,1},simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{3,1}, simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{1,1}, '--');
            xlabel('Pelvis translation in z-direction');
            ylabel('Pelvis translation in x-direction');
            legend('Simulated signal', 'Extra signal');
            title('View of the pelvis path in the transverse plane ('+titleAdd(i)+')');
            %}
        
            %Get evaluation metrics for variables of interest
            %{
            %Mean values
            meanMeasuredPelvisTx = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{1,1});
            meanMeasuredPelvisTy = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{2,1});
            meanMeasuredPelvisTz = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{3,1});
            
            meanMeasuredPelvisRotation = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{4,1});
            meanMeasuredPelvisObliq = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{5,1});
            meanMeasuredPelvisTilt = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{6,1});
            
            meanMeasuredRkneeJointAngle = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{10,1});
            meanMeasuredLkneeJointAngle = mean(simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{17,1});
            %}
        
    
    
            %% TODO: decide how to calc RMSE/corr for path-->use procrustes error, for plotting and also correlation calculation (can corr be calculated after procrustes?)
            %% TODO: implement loop where all subject IDs are provided and we will eventually get a simVarTableIMU with 20 rows (20 sims)
    
            % getting pelvis translations (x and z) for both ground truth
            % and simulaiton and rotating the simulation to match the 
            % initial movement direction    
            measZ=simVarTableIMU.([participant.ID,simSetupName]).mean_extra{3,1};
            measX=simVarTableIMU.([participant.ID,simSetupName]).mean_extra{1,1};
            simZ=simVarTableIMU.([participant.ID,simSetupName]).sim{3,1};
            simX=simVarTableIMU.([participant.ID,simSetupName]).sim{1,1};
            measuredPath=[measZ, measX]; %--> to use for RMSE and plotting
            simulatedPath=[simZ, simX];
    
            [~,~, tr]=procrustes(measuredPath, simulatedPath, 'scaling', false, 'reflection', false);
            simulatedRotatedPath=simulatedPath*tr.T; %--> to use for RMSE and plotting

            varsOfInterest.([participant.ID,simSetupName]).gtPath=measuredPath;
            varsOfInterest.([participant.ID,simSetupName]).simRotatedPath=simulatedRotatedPath;


            % finding the lag between measured and simulated right leg
            % vertical GRF, to shift right leg (knee, hip, ankle) kinematics
            % and kinetics (joint angles and moments)
            rightLegVertGRFmeasured=simVarTableIMU.([participant.ID,simSetupName]).mean_extra{42,1};
            rightLegVertGRFsimulated=simVarTableIMU.([participant.ID,simSetupName]).sim{42,1};

            [xc, lags] = xcorr(rightLegVertGRFsimulated, rightLegVertGRFmeasured, 'coeff');
            [~, maxIdx] = max(xc);
            optimalLag = lags(maxIdx);

            

            %shifting based on optimalLag the simulated right leg grfs, kinematics and kinetics for pelvis, right
            %knee, right hip and right ankle
%             GRFxRSimShifted=
%             GRFyRSimShifted=
%             GRFzRSimShifted=
% 
%             pelvisRotationSimShifted= 
%             pelvisObliqSimShifted= 
%             pelvisTiltSimShifted= 
% 
%             hipFlexRSimShifted= 
%             hipAddRSimShifted=
%             hipRotRSimShifted=
% 
%             KneeFlexAngleRSimShifted=
%             AnkleAngleRSimShifted=

            varsOfInterest.([participant.ID,simSetupName]).gtHRM=simVarTableIMU.([participant.ID,simSetupName]).mean_extra{26,1};
            varsOfInterest.([participant.ID,simSetupName]).simHRM=simVarTableIMU.([participant.ID,simSetupName]).sim{26,1};
            varsOfInterest.([participant.ID,simSetupName]).gtGRFy=simVarTableIMU.([participant.ID,simSetupName]).mean_extra{42,1};
            varsOfInterest.([participant.ID,simSetupName]).simGRFy=simVarTableIMU.([participant.ID,simSetupName]).sim{42,1};
            %varsOfInterest.([participant.ID,simSetupName]).gtKAM=;
            %varsOfInterest.([participant.ID,simSetupName]).simKAM=;

    
            %RMSE values
            differences=measuredPath-simulatedRotatedPath;
            rmseSim.([participant.ID,simSetupName]).path=sqrt(mean(sum(differences.^2,2)));
            
            % 2 right Hip Rotation Moment
            rmseSim.([participant.ID,simSetupName]).rHRM = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{26,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{26,1}).^2));
            
            % 3 right Hip Abduction Moment
            rmseSim.([participant.ID,simSetupName]).rHAM = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{25,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{25,1}).^2));

            % 4 right Knee Flexion Moment
            rmseSim.([participant.ID,simSetupName]).rKFM = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{27,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{27,1}).^2));

            % 5 right GRF vertical
            rmseSim.([participant.ID,simSetupName]).rGRFy = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{42,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{42,1}).^2));            

            % 6 right Knee Flexion Angle
            rmseSim.([participant.ID,simSetupName]).rKFA = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{10,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{10,1}).^2));            

            % 7 right Hip Flexion Angle
            rmseSim.([participant.ID,simSetupName]).rHFA = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{7,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{7,1}).^2));

            % 8 righ Hip Abduction Angle
            rmseSim.([participant.ID,simSetupName]).rHAA = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{8,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{8,1}).^2));            

            % 9 right Ankle Angle
            rmseSim.([participant.ID,simSetupName]).rAA = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{11,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{11,1}).^2));
    
            % 10 right Hip Rotation Angle
            rmseSim.([participant.ID,simSetupName]).rHRA = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{9,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{9,1}).^2));            


            rmseSim.([participant.ID,simSetupName]).GRFxR = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{41,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{41,1}).^2));
            rmseSim.([participant.ID,simSetupName]).GRFzR = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{43,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{43,1}).^2));

            rmseSim.([participant.ID,simSetupName]).pelvisTx = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{1,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{1,1}).^2));
            rmseSim.([participant.ID,simSetupName]).pelvisTy = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{2,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{2,1}).^2));
            rmseSim.([participant.ID,simSetupName]).pelvisTz = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{3,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{3,1}).^2));
            
            rmseSim.([participant.ID,simSetupName]).pelvisRotation = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{4,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{4,1}).^2));
            rmseSim.([participant.ID,simSetupName]).pelvisObliq = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{5,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{5,1}).^2));
            rmseSim.([participant.ID,simSetupName]).pelvisTilt = sqrt(mean((simVarTableIMU.([participant.ID,simSetupName]).mean_extra{6,1}-simVarTableIMU.([participant.ID,simSetupName]).sim{6,1}).^2));            
                        
            %rmseSim(i).GRFxL = sqrt(mean((simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{44,1}-simVarTableIMU.(['simulationResult',num2str(i)]).sim{44,1}).^2));
            %rmseSim(i).GRFyL = sqrt(mean((simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{45,1}-simVarTableIMU.(['simulationResult',num2str(i)]).sim{45,1}).^2));
            %rmseSim(i).GRFzL = sqrt(mean((simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{46,1}-simVarTableIMU.(['simulationResult',num2str(i)]).sim{46,1}).^2));
        
            %rmseSim(i).lKneeJointAngle = sqrt(mean((simVarTableIMU.(['simulationResult',num2str(i)]).mean_extra{17,1}-simVarTableIMU.(['simulationResult',num2str(i)]).sim{17,1}).^2));
            
            
    
    
    
            %{
            %rRMSE values
            rRmseSim(i).pelvisTx = (rmseSim(i).pelvisTx/ meanMeasuredPelvisTx)*100;
            rRmseSim(i).pelvisTy = (rmseSim(i).pelvisTy/ meanMeasuredPelvisTy)*100;
            rRmseSim(i).pelvisTz = (rmseSim(i).pelvisTz/ meanMeasuredPelvisTz)*100;
            
            rRmseSim(i).pelvisRotation = (rmseSim(i).pelvisRotation/ meanMeasuredPelvisRotation)*100;
            
            rRmseSim(i).rKneeJointAngle = (rmseSim(i).rKneeJointAngle/ meanMeasuredRkneeJointAngle)*100;
            rRmseSim(i).lKneeJointAngle = (rmseSim(i).lKneeJointAngle/ meanMeasuredLkneeJointAngle)*100;
            %}
        
            %Correlations
            % 2 right Hip Rotation Moment
            corrSim.([participant.ID,simSetupName]).rHRM = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{26,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{26,1});
            
            % 3 right Hip Abduction Moment
            corrSim.([participant.ID,simSetupName]).rHAM = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{25,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{25,1});

            % 4 right Knee Flexion Moment
            corrSim.([participant.ID,simSetupName]).rKFM = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{27,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{27,1});

            % 5 right GRF vertical
            corrSim.([participant.ID,simSetupName]).rGRFy = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{42,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{42,1});

            % 6 right Knee Flexion Angle
            corrSim.([participant.ID,simSetupName]).rKFA = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{10,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{10,1});            

            % 7 right Hip Flexion Angle
            corrSim.([participant.ID,simSetupName]).rHFA = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{7,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{7,1});

            % 8 righ Hip Abduction Angle
            corrSim.([participant.ID,simSetupName]).rHAA = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{8,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{8,1});       

            % 9 right Ankle Angle
            corrSim.([participant.ID,simSetupName]).rAA = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{11,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{11,1});
    
            % 10 right Hip Rotation Angle
            corrSim.([participant.ID,simSetupName]).rHRA = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{9,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{9,1});         


            corrSim.([participant.ID,simSetupName]).pelvisTx = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{1,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{1,1});
            corrSim.([participant.ID,simSetupName]).pelvisTy = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{2,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{2,1});
            corrSim.([participant.ID,simSetupName]).pelvisTz = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{3,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{3,1});
            
            corrSim.([participant.ID,simSetupName]).pelvisRotation = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{4,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{4,1});
            corrSim.([participant.ID,simSetupName]).pelvisObliq = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{5,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{5,1});
            corrSim.([participant.ID,simSetupName]).pelvisTilt = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{6,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{6,1});
            
            corrSim.([participant.ID,simSetupName]).GRFxR = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{41,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{41,1});
            corrSim.([participant.ID,simSetupName]).GRFzR = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{43,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{43,1});
            
    %         corrSim(i).GRFxL = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{44,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{44,1});
    %         corrSim(i).GRFyL = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{45,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{45,1});
    %         corrSim(i).GRFzL = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{46,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{46,1});

    %         corrSim(i).lKneeJointAngle = corr(simVarTableIMU.([participant.ID,simSetupName]).mean_extra{17,1}, simVarTableIMU.([participant.ID,simSetupName]).sim{17,1});
    
    
            %plots joint angles, joint moments, activation, stimulation, tracked signals (acc,
            %gyro), GRFs, translations from generated simVarTable
            %plotVarTable(simVarTableIMU.([participant.ID,simSetupName]), style);
        end
    
        figure; hold on;
        
        colors = lines(length(resultFilesCODRunning)+1);
    
        %% TODO: make this plotting work and then check if simVarTableIMU 
        % gathers correctly the simulations even after one participant loop
        for i=1:(length(resultFilesCODRunning)+1)

            if i<=length(resultFilesCODRunning)
                if contains(resultFilesCODRunning{i}, 'CODinitGuess')
                    simSetupName='CODinitGuess';
                elseif contains(resultFilesCODRunning{i}, 'tfs')
                    simSetupName='tfs';
                elseif contains(resultFilesCODRunning{i}, 'fts')
                    simSetupName='fts';
                elseif contains(resultFilesCODRunning{i}, 'ftc')
                    simSetupName='ftc';
                end    
            else
                if contains(resultFilesCODRunning{i-1}, 'ftc')
                    simSetupName='ftc';
                end
            end


            if i==(length(resultFilesCODRunning)+1)
                plotLabels = sprintf('Measurement');
        
                plot(varsOfInterest.([participant.ID,simSetupName]).gtPath(:,1), varsOfInterest.([participant.ID,simSetupName]).gtPath(:,2), 'Color', colors(i,:), 'DisplayName', plotLabels, 'LineWidth', 1.5);
    
            else
                plotLabels = sprintf('Simulation %d', i);
        
                plot(varsOfInterest.([participant.ID,simSetupName]).simRotatedPath(:,1), varsOfInterest.([participant.ID,simSetupName]).simRotatedPath(:,2), 'Color', colors(i,:), 'DisplayName', plotLabels, 'LineWidth', 1.5);
            end
        end
    
        legend show;
        xlabel('Pelvis translation in lateral direction');
        ylabel('Pelvis translation in forward direction');
        title('COD Movement Path in the Transverse Plane');
        hold off;
    
        %==================Old plotting before trying to plot new-toolbox
        %simulations=========================
    %     %Plot the simulated path of the pelvis against the measured one, for each simulation
    %     %figure(i);
    %     titleAdd=["bbno-SimB", "bbwo-SimC", "sbno-SimA"];
    %     %plot(txResult, tzResult);
    %     %plot(simVarTableIMU.('simulationResult3').sim{3,1}, simVarTableIMU.('simulationResult3').sim{1,1},'r-');
    %     %hold on;
    %     plot(simVarTableIMU.('simulationResult1').sim{3,1}, simVarTableIMU.('simulationResult1').sim{1,1},'b-');
    %     hold on;
    %     plot(simVarTableIMU.('simulationResult2').sim{3,1}, simVarTableIMU.('simulationResult2').sim{1,1},'g-');
    %     hold on;
    %     plot(simVarTableIMU.('simulationResult5').sim{3,1}, simVarTableIMU.('simulationResult5').sim{1,1},'r-', simVarTableIMU.('simulationResult1').mean_extra{3,1}, simVarTableIMU.('simulationResult1').mean_extra{1,1}, 'k--');
    %     hold on;
    %     %plot(simVarTableIMU.('simulationResult6').sim{3,1}, simVarTableIMU.('simulationResult6').sim{1,1},'m-', simVarTableIMU.('simulationResult1').mean_extra{3,1}, simVarTableIMU.('simulationResult1').mean_extra{1,1}, 'k--');
    %     %plot(simVarTableIMU.('simulationResult4').sim{3,1}, simVarTableIMU.('simulationResult4').sim{1,1},'r--');
    %     %hold on;
    %     
    %     xlabel('Pelvis translation in lateral direction');
    %     ylabel('Pelvis translation in forward direction');
    %     legend('Simulation A', 'Simulation B', 'Simulation C', 'Measurement');
    %     title('COD Movement Path in the Transverse Plane');
        %=================================
        
        %============Old plotting of simVarTable variables=======
    %     plotVarTable(simVarTableIMU.simulationResult1, style);
    %     plotVarTable(simVarTableIMU.simulationResult2, style);
    %     plotVarTable(simVarTableIMU.simulationResult5, style);
        %=========================
    end
        simVarTableOutput = simVarTableIMU;

    save([path2repo filesep resultFolder filesep 'varsExceptKAM.mat'], 'varsOfInterest', 'rmseSim', 'corrSim');
end


function [participant, resultFiles] = setSettings(pId)
    if pId==1
        participant.ID = 's01';
        participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s01_baseline.osim';
        participant.dataFile  = 'data_Erlangen_cut135_s01_3D_1_measuredIMU-MEA.mat'; 
        resultFiles = {'10032025-CODinitGuess/2025_03_10_scriptCODfromMeasIMU_CODrunning' ...
            '11032025_tfs/2025_03_11_scriptCODfromMeasIMU_CODrunning' ...
            '12032025_fts/2025_03_12_scriptCODfromMeasIMU_CODrunning' ...
            '14032025_ftc/2025_03_14_scriptCODfromMeasIMU_CODrunning'};
    elseif pId==2
        participant.ID = 's02';
        participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s02_baseline.osim';
        participant.dataFile  = 'data_Erlangen_cut135_s02_3D_6_measuredIMU.mat'; 
        resultFiles = {'22062025-CODinitGuess/22062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_tfs/s02Btfs_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_fts/s02Bfts_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_ftc/s02Bftc_24062025_scriptCODfromMeasIMU_CODrunning'};
    elseif pId==3
        participant.ID = 's03';
        participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s03_baseline.osim';
        participant.dataFile  = 'data_Erlangen_cut135_s03_3D_4_measuredIMU-wOCode2nd.mat'; 
        resultFiles = {'23062025-CODinitGuess/23062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_tfs/s03Btfs_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_fts/s03Bfts_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_ftc/s03Bftc_24062025_scriptCODfromMeasIMU_CODrunning'};
    elseif pId==4
        participant.ID = 's04';
        participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s04_baseline.osim';
        participant.dataFile  = 'data_Erlangen_cut135_s04_3D_1_measuredIMU-wOcode.mat'; 
        resultFiles = {'23062025-CODinitGuess/23062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_tfs/s04Btfs_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_fts/s04Bfts_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_ftc/s04Bftc_24062025_scriptCODfromMeasIMU_CODrunning'};
    elseif pId==5
        participant.ID = 's05';
        participant.modelFile = 'gait3d_pelvis213_Innsbruck_scaled_s05_baseline.osim';
        participant.dataFile  = 'data_Erlangen_cut135_s05_3D_3_measuredIMU-wOcode.mat'; 
        resultFiles = {'23062025-CODinitGuess/23062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_tfs/s05Btfs_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_fts/s05Bfts_24062025_scriptCODfromMeasIMU_CODrunning' ...
            '24062025_ftc/s05Bftc_24062025_scriptCODfromMeasIMU_CODrunning'};
    end
end
