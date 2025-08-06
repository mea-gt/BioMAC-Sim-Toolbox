%======================================================================
%> @file FAME\MyImplementationFC\velocityDirectionObjectiveForCOD.m
%> @brief Function to specify an objective for 3D COD
%running, tracking measured IMU data. The objective is for the resultant velocity
%direction from the x and z velocity directions (vectors) to rotate by
%125-145 degrees by the end of the trial.The number of degrees
%should depend on the trial being simulated.
%>
%> @author Maria Eleni Athanasiadou
%> @date February, 2025
%======================================================================

% ======================================================================
%> @brief Function to specify an objective for 3D COD
%running, tracking measured IMU data. The objective is for the resultant velocity
%direction from the x and z velocity directions (vectors) to rotate by
%125-145 degrees by the end of the trial.The number of degrees
%should depend on the trial being simulated.
%>
%> @param   obj     Collocation class object
%> @param   option  String parsing the demanded output: 'objval' or 'gradient'
%>                  (or 'init' for initialization)
%> @param   X       Double array: State vector containing at least 'states' of the model
%>%> @retval  output  Objective values for input option 'objval' or vector
%>                  with gradient for input option 'gradient'
% ======================================================================
function output = velocityDirectionObjectiveForCOD(obj,option,X) %,weigthsType,exponent,speedWeighting)

fctname = 'velocityDirectionObjectiveForCOD';

    
%% initalization
if strcmp(option,'init')
    %{

    % check input parameter
    if ~isfield(obj.idx,'controls') % check whether controls are stored in X
        error('Model controls are not stored in state vector X.')
    end

    %TODO: vector that refers to the indices of the pelvis state. What
    'Get pelvis indices' section does at the moment until the
    timeNode=... definition
    % initialize some variables (faster to get it once; even though they are not so expensive)
    obj.objectiveInit.(fctname).idxNeuralExAllNodes = obj.idx.controls(obj.model.extractControl('u'), 1:obj.nNodes);

   % obj.objectiveInit.(fctname).weights = weights;

    if nargin < 5
        obj.objectiveInit.(fctname).exponent = 3;
    elseif round(exponent) ~= exponent || exponent < 1
        error('Exponent must be a positive integer');
    end
    obj.objectiveInit.(fctname).exponent = exponent;

    if nargin < 6
        speedWeighting = 0;
    end
    obj.objectiveInit.(fctname).speedWeighting = speedWeighting;
    if speedWeighting && ~isfield(obj.idx,'speed') % check whether controls are stored in X
        error('Model speed is not stored in state vector X.')
    end
    %}
    
    % Return a dummy value
    output = NaN;
    return;
end

%% Get pelvis indices
%gets the index of the required state from model.states
idxDOFs_PelvicRotation = obj.model.extractState('q', 'pelvis_rotation');
idxDOFs_velx = obj.model.extractState('qdot', 'pelvis_tx');
idxDOFs_velz = obj.model.extractState('qdot', 'pelvis_tz');

%gets all the indices of the required state, for each time node
idxAll_PelvicRotation = obj.idx.states(idxDOFs_PelvicRotation, :);
idxAll_pelvVelX = obj.idx.states(idxDOFs_velx, :);
idxAll_pelvVelZ = obj.idx.states(idxDOFs_velz, :);

timeNode = obj.nNodes;
finalPelvicRotationAngle = X(idxAll_PelvicRotation(timeNode)); % returns the pelvic rotation angle at the requested time-node.
finalPelvVelX = X(idxAll_pelvVelX(timeNode));
finalPelvVelZ = X(idxAll_pelvVelZ(timeNode));

%% Get the objective value or gradient that are needed during the optimization
if strcmp(option,'objval') % objective value --> this option sets the function that we are trying to minimize.
    % If the angle is in the intended range (currently we are
    % simulating a 135 degree cut so the appropriate range for the 
    % simulation to end at, will be btwn 125 and 145 degrees) return a
    % zero value for the objective value --> no penalty for the
    % objective function
    output = 0;

    % If the angle is smaller than 125 degrees the returned value will
    % be the squared difference of 125 and resultant vector/direction
    % of the x and z velocity vectors. 
    % Larger distance=larger penalty. The same logic is used for the distance
    % from the upper bound (145 degrees).
    if finalPelvVelZ/finalPelvVelX<=tan(deg2rad(125))
        output = ((finalPelvVelZ-finalPelvVelX*tan(deg2rad(125))))^2;        
    elseif finalPelvVelZ/finalPelvVelX>=tan(deg2rad(145))
        output = ((finalPelvVelZ-finalPelvVelX*tan(deg2rad(145))))^2;        
    end
     
elseif strcmp(option,'gradient') % gradient --> this option sets the value of the gradient for the function we set above.
    idxAtTimeNode = idxAll_PelvicRotation(timeNode);
    idxPelvVelX = idxAll_pelvVelX(timeNode);
    idxPelvVelZ = idxAll_pelvVelZ(timeNode);
    output = spalloc(size(X,1),size(X,2),length(idxPelvVelX)*2);

    if finalPelvVelZ/finalPelvVelX >tan(deg2rad(125)) && finalPelvVelZ/finalPelvVelX<tan(deg2rad(145))
    
    elseif finalPelvVelZ/finalPelvVelX<=tan(deg2rad(125))
        output(idxPelvVelX) = output(idxPelvVelX)-2* (finalPelvVelZ-finalPelvVelX*tan(deg2rad(125)))*tan(deg2rad(125));%(2*finalPelvVelZ*(finalPelvVelX*cot((7*pi)/36) + finalPelvVelZ)*(finalPelvVelZ*cot((7*pi)/36)-finalPelvVelX))/(finalPelvVelX^2+finalPelvVelZ^2)^2;
        output(idxPelvVelZ) = output(idxPelvVelZ)+2* (finalPelvVelZ-finalPelvVelX*tan(deg2rad(125)));%(2*finalPelvVelX*(finalPelvVelX*cot((7*pi)/36) + finalPelvVelZ)*(finalPelvVelX - finalPelvVelZ*cot((7*pi)/36)))/(finalPelvVelX^2 + finalPelvVelZ^2)^2;
        
    elseif finalPelvVelZ/finalPelvVelX>=tan(deg2rad(145))
        output(idxPelvVelX) = output(idxPelvVelX)-2*(finalPelvVelZ-finalPelvVelX*tan(deg2rad(145)))*tan(deg2rad(145));%finalPelvVelZ*(finalPelvVelZ-finalPelvVelX*tan(deg2rad(145)))*(finalPelvVelZ*tan(deg2rad(145))+finalPelvVelX))/(finalPelvVelX^2+finalPelvVelZ^2)^2;
        output(idxPelvVelZ) = output(idxPelvVelZ)+2*(finalPelvVelZ-finalPelvVelX*tan(deg2rad(145)));%finalPelvVelX*(finalPelvVelZ-finalPelvVelX*tan(deg2rad(145)))*(finalPelvVelZ*tan(deg2rad(145))+finalPelvVelX))/(finalPelvVelX^2+finalPelvVelZ^2)^2;
        % positive gradient signals to the optimizer that the objective value needs to be decreased towards the upper bound (145)
    end  
    
end

end