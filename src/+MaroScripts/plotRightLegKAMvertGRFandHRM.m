function plotRightLegKAMvertGRFandHRM()
    currentFunctionPath=mfilename('fullpath');
    currentFunctionPath=currentFunctionPath(1:end-28);
    toolboxPath=[currentFunctionPath '..' filesep '..' filesep];
    resultFolderPath=[toolboxPath 'results' filesep 'MaroCODsims'];

    cd(resultFolderPath);

    varsExceptKAM=load('varsExceptKAM.mat');
    KAMandMetrics=load('KAMsAndMetrics.mat');

    varsOfInterest=varsExceptKAM.varsOfInterest;
    rmseSim=varsExceptKAM.rmseSim;
    corrSim=varsExceptKAM.corrSim;
    KAMsAndMetrics=KAMandMetrics.KAMsAndMetrics;
    
    interpTo100=@(x) interp1(linspace(0,1,length(x)), x, linspace(0,1,100), 'linear');


    kamFields=fieldnames(KAMsAndMetrics);

    for i=1:numel(kamFields)
        fieldName=kamFields{i};

        %Add gtKAM and simKAm to varsOfInterest
        if isfield(varsOfInterest, fieldName)
            varsOfInterest.(fieldName).gtKAM=KAMsAndMetrics.(fieldName).gtKAM;
            varsOfInterest.(fieldName).simKAM=KAMsAndMetrics.(fieldName).simKAM;
        else
            warning('Field %s is not found in varsOfInterest', fieldName);
        end

        %Add rmse of KAM to rmseSim
        if isfield(rmseSim, fieldName)
            rmseSim.(fieldName).rKAM=KAMsAndMetrics.(fieldName).rmse;            
        else
            warning('Field %s is not found in rmseSim', fieldName);
        end

        %Add corr of KAM to corrSim
        if isfield(rmseSim, fieldName)
            corrSim.(fieldName).rKAM=KAMsAndMetrics.(fieldName).corr;            
        else
            warning('Field %s is not found in corrSim', fieldName);
        end
    end









     
    setups={'CODinitGuess', 'tfs', 'fts', 'ftc'};
    numSetups=numel(setups);
    subjects={'01','02','03','04','05'};

    %Get final aggregated RMSE and Corr tables
    vars={'path', 'rKAM', 'rHRM', 'rHAM', 'rKFM', 'rGRFy', 'rKFA', 'rHFA', 'rHAA', 'rAA', 'rHRA'};

    rmseVals=zeros(length(vars), length(setups));
    corrVals=zeros(length(vars), length(setups));

    for v=1:length(vars)
        varName=vars{v};
        for s=1:length(setups)
            setup=setups{s};

            rmse_list=[];
            corr_list=[];
            for p=1:length(subjects)
                subj=subjects{p};
                fieldName=['s' subj setup];

                if strcmp(subj, '03') && strcmp(setup, 'fts')
                    continue;
                end

                if isfield(rmseSim, fieldName) && isfield(rmseSim.(fieldName), varName)
                    rmse_val=rmseSim.(fieldName).(varName);
                    rmse_list(end+1)=rmse_val;
                end

                if isfield(corrSim, fieldName) && isfield(corrSim.(fieldName), varName)
                    corr_val=corrSim.(fieldName).(varName);
                    if ~isnan(corr_val) && abs(corr_val)<1
                        z=atanh(corr_val);
                        corr_list(end+1)=z;
                    end
                end
            end

            if ~isempty(rmse_list)
                rmseVals(v,s)=mean(rmse_list);
            else
                rmseVals(v,s)=NaN;
            end

            if ~isempty(corr_list)
                z_avg=mean(corr_list);
                corrVals(v,s)=tanh(z_avg);
            else
                corrVals(v,s)=NaN;
            end
        end
    end
    rmseTable=array2table(rmseVals, 'VariableNames',setups,'RowNames',vars);
    corrTable=array2table(corrVals, 'VariableNames',setups, 'RowNames',vars);

    disp('Average RMSE per parameter per simulation setup:');
    disp(rmseTable);

    disp('Average Correlation per parameter per simulation setup:');
    disp(corrTable);









    colors=lines(numSetups);

    gtKAM_all=[];
    gtHRM_all=[];
    gtGRF_all=[];

    simKAM_set=cell(1,numSetups);
    simHRM_set=cell(1,numSetups);
    simGRF_set=cell(1,numSetups);

    %Track if ground truth was already added for a subject
    addedGT=containers.Map;

    %Aggregate data
    for s=1:numel(subjects)
        subj=subjects{s};
        for k=1:numSetups
            setup=setups{k};
            fieldName=['s' subj setup];

            %skip s03fts because it didn't converge
            if strcmp(subj, '03') && strcmp(setup, 'fts')
                continue;
            end

            if isfield(varsOfInterest, fieldName)
                data=varsOfInterest.(fieldName);

                %Add ground truth only once per subject
                if ~isKey(addedGT, subj)
                    gtKAM_all(end+1, :)=interpTo100(data.gtKAM(:)');
                    gtHRM_all(end+1, :)=interpTo100(data.gtHRM(:)');
                    gtGRF_all(end+1, :)=interpTo100(data.gtGRFy(:)');
                    addedGT(subj)=true;
                end

                %Add simulation data
                simKAM_set{k}(end+1,:)=interpTo100(data.simKAM(:)');
                simHRM_set{k}(end+1,:)=interpTo100(data.simHRM(:)');
                simGRF_set{k}(end+1,:)=interpTo100(data.simGRFy(:)');

            end
        end
    end

    %PLOT

    figure;
    titles={'Knee Abduction Moment (KAM)', 'Hip Rotation Moment (HRM)', 'Vertical Ground Reaction Force (vGRF)'};
    gtData={gtKAM_all, gtHRM_all, gtGRF_all};
    simData={simKAM_set, simHRM_set, simGRF_set};

    shadedHandles=gobjects(1,numSetups);
    

    lineHandles=[];
    legendLabels={};
    legendEntries={'IMC-basic', 'IMC-PR', 'IMC-VD', 'IMC-VDC'};
    yLab={'Moment (Nm)', 'Moment (Nm)', 'GRF (BW)'};
    shadeLabels=legendEntries;

    for i=1:3
        subplot(3,1,i);hold on;
        gtMat=gtData{i};
        simCell=simData{i};

        N=size(gtMat,2); %time axis
        t=linspace(0,100,N);

        %Plot ground truth
        meanGT=mean(gtMat,1);
        pGT=plot(t, meanGT, 'k', 'LineWidth',2,'DisplayName','OMC-Ground Truth');
        lineHandles(end+1)=pGT;
        legendLabels{end+1}='OMC-Ground Truth';

        for k=1:numSetups
            simMat=simCell{k};
            if isempty(simMat)
                continue;
            end

            meanSim=mean(simMat, 1);
            stdSim=std(simMat,0,1);

            hShade=fill([t fliplr(t)], [meanSim+stdSim, fliplr(meanSim-stdSim)], ...
                colors(k,:), 'FaceAlpha',0.2,'EdgeColor','none', ...
                'HandleVisibility','off');

            %save one shaded handle per setup
            if i==1
                shadedHandles(k)=hShade;
            end

            %Plot mean line
            pLine = plot(t, meanSim, 'Color', colors(k,:), 'LineWidth',1.5,'DisplayName',legendEntries{k});

            lineHandles(end+1)=pLine;
            legendLabels{end+1}=legendEntries{k};

        end
        title(titles{i}, 'FontWeight','bold');
        xlabel('% of COD from penultimate to final foot contact');
        ylabel(yLab{i});
        legend('show', 'Location','best');


    end

    lgd=legend(shadedHandles,shadeLabels, 'Orientation', 'horizontal', ...
        'Position', [0.25 0.03 0.5 0.05], 'Box', 'off');





    



end
