function createOsimModelMatAndMomentArmsForHPC(modelNamesArray)

    for i=1:length(modelNamesArray)
        modelPath = ['/home/od80izej/Documents/BioMAC-Sim-Toolbox/data/MaroCODsims/DataStructsForInnsbruckOldDtaFromJiating/model/gait3d_pelvis213_Innsbruck_scaled_' modelNamesArray{i} '.osim'];
        modelLoaded = Gait3d(modelPath);

        modelPathMat = ['/home/od80izej/Documents/BioMAC-Sim-Toolbox/data/MaroCODsims/DataStructsForInnsbruckOldDtaFromJiating/model/gait3d_pelvis213_Innsbruck_scaled_' modelNamesArray{i} '.mat'];    
        load(modelPathMat);

        model.osim.file=['/home/hpc/iwb8/iwb8106h/OptCntrlSims/BioMAC-Sim-Toolbox/data/MaroCODsims/DataStructsForInnsbruckOldDtaFromJiating/model/gait3d_pelvis213_Innsbruck_scaled_' modelNamesArray{i} '.osim'];
        save(modelPathMat, "model", "osim_sha256")
        disp('Test');
    end