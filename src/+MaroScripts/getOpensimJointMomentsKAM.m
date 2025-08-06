function getOpensimJointMomentsKAM(filename,osimfile,muscleforce)

curpath = pwd;
[pathname,name,ext] = fileparts(filename);
cd(pathname)
name_ext=[name,ext];
if exist(name_ext, 'file')
    load(name_ext)

    %M% cd(name_ext) %what was the purpose of this? name was just a string,
    %not a directory

    duration = result.X(result.problem.idx.dur);
    if result.problem.isSymmetric
        duration = duration*2;
    end
    if result.problem.isSymmetric
        N = result.problem.nNodes*2;
    else
        N = result.problem.nNodes;
    end
    times = (0:N-1)/(N-1)*duration;

    %%
    resultspath = [pwd filesep 'Analysis'];
    if exist(resultspath, 'dir')
        cd(resultspath)
    else
        mkdir(resultspath)
        cd(resultspath)
    end

    %maybe change pathname to resultspath in below line
    result.problem.writeMotionToOsim(result.X,[resultspath filesep name]);
    movefile([resultspath filesep name '_kinetics_force.sto'], [resultspath filesep 'muscleforce.sto']);
    %M% was the purpose of the above line to rename or move the
    %kinetics_force file???

    import org.opensim.modeling.*;

    genericSetupForAn = [resultspath filesep 'settings_getReactionForce_generic.xml'];
    analyzeTool = AnalyzeTool(genericSetupForAn);
    analyzeTool.getAnalysisSet().get(0).setStartTime(times(1));
    analyzeTool.getAnalysisSet().get(0).setEndTime(times(end));

    % Scale model

    %M% what should the file below contain?
    extforpath = fullfile([resultspath filesep name '_extfor.xml']);
    % Create external forces xml file 
    if ~exist([resultspath filesep name '_extfor.xml'],'file')
        ext_loads = ExternalLoads();
        ext_loads.setDataFileName([resultspath filesep name '_kinetics_GRFs.mot']);
        %ext_loads.setExternalLoadsModelKinematicsFileName([pathname filesep name '_kinematics.mot']);
        ext_loads.print(extforpath);
    end

    model = Model(osimfile);
    analyzeTool.setModel(model);
    analyzeTool.setName(name);
    analyzeTool.setResultsDir(resultspath);
    analyzeTool.setCoordinatesFileName([resultspath filesep name '_kinematics.mot']);
    analyzeTool.setExternalLoadsFileName(extforpath);
    analyzeTool.setInitialTime(times(1));
    analyzeTool.setFinalTime(times(end));   
    model.addAnalysis(analyzeTool.getAnalysisSet().get(0));
    %analyzeTool.setForces

    outfile = ['Setup_Analyze_' name '.xml'];
    analyzeTool.print([resultspath filesep outfile]);

    
    % cd([pathname filesep name])
    %M%cd([pathname filesep])

    if result.converged
        analyzeTool.run();
    end
    cd ..
    disp('Performing Analysis');
    disp('Done, check out.log for any errors');
end

cd(curpath)

    % % rename the out.log so that it doesn't get overwritten
    % copyfile('..\out.log',[pathname '\' name '_out.log'])


    % 
    % % Get Initial and Final Time
    % motfile = Storage([cur_fol '\' filename '.sto']);
    % initial_time = motfile.getFirstTime();
    % final_time = motfile.getLastTime();
    % 
    % % Set Joint Reaction Analysis
    % analysis = JointReaction();
    % analysis.setOn(1);
    % analysis.setStartTime(initial_time);
    % analysis.setEndTime(final_time);
    % analysis.setInDegrees(1);
    % analysis.setForcesFileName([cur_fol '\' pathname '\' name '_force.sto']);
    % analysis.setJointNames(ArrayStr(['knee_r', 'knee_l', 'hip_r', 'hip_l']));
    % analysis.setOnBody(ArrayStr('child'));
    % analysis.setInFrame(ArrayStr('child'));
    % % analysisSet.cloneAndAppend(analysis);
    % 
    %analyzeTool.getAnalysisSet().get(0).safeDownCast(JointReaction());
    % analyzeTool.getAnalysisSet().get(0).setForcesFileName([cur_fol '\' pathname '\' name '_force.sto']);

