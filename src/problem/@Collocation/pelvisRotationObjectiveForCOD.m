%======================================================================
%> @file FAME\MyImplementationFC\pelvisRotationObjectiveForCOD.m
%> @brief Function to specify an objective for 3D COD
%running tracking measured IMU data. The objective is for the pelvis
%to rotate x degrees by the end of the trial. The number of degrees
%depends on the trial being simulated.
%>
%> @author Maria Eleni Athanasiadou
%> @date November, 2024
%======================================================================

% ======================================================================
%> @brief Function to specify an objective for 3D COD
%running tracking measured IMU data. The objective is for the pelvis
%to rotate x degrees by the end of the trial. The number of degrees
%depends on the trial being simulated.
%>
%> @param   obj     Collocation class object
%> @param   option  String parsing the demanded output: 'objval' or 'gradient'
%>                  (or 'init' for initialization)
%> @param   X       Double array: State vector containing at least 'states' of the model
%>%> @retval  output  Objective values for input option 'objval' or vector
%>                  with gradient for input option 'gradient'
% ======================================================================
function output = pelvisRotationObjectiveForCOD(obj,option,X) %,weigthsType,exponent,speedWeighting)

fctname = 'pelvisRotationObjectiveForCOD';

    
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
    if finalPelvicRotationAngle>2.18 && finalPelvicRotationAngle<2.53
        output = 0;
        
    % If the angle is smaller than 125 degrees the returned value wil
    % be the squared difference of the angle from 125 degrees, to
    % penalize the distance from the lower bound. Larger
    % distance=larger penalty. The same logic is used for the distance
    % from the upper bound (145 degrees).
    elseif finalPelvicRotationAngle<=2.18
        output = (finalPelvicRotationAngle-2.18)^2;
    elseif finalPelvicRotationAngle>2.53
        output = (finalPelvicRotationAngle-2.53)^2;
    end
     
elseif strcmp(option,'gradient') % gradient --> this option sets the value of the gradient for the function we set above.
    idxAtTimeNode = idxAll_PelvicRotation(timeNode);
    idxPelvVelX = idxAll_pelvVelX(timeNode);
    idxPelvVelZ = idxAll_pelvVelZ(timeNode);
    output = zeros(size(X));

    if finalPelvicRotationAngle>2.18 && finalPelvicRotationAngle<2.53
%         output(idxPelvVelX) = 0; % 0 gradient tells the optimizer that the objective value doesn't need to be adjusted further. It has reached an acceptable value
%         output(idxPelvVelZ) = 0; 
    elseif finalPelvicRotationAngle<=2.18
        output(idxAtTimeNode) = 2*(finalPelvicRotationAngle-2.18); % negative gradient signals to the optimizer that the objective value needs to be increased toward the lower bound (125)        
   elseif finalPelvicRotationAngle>=2.53
        output(idxAtTimeNode) = 2*(finalPelvicRotationAngle-2.53); % positive gradient singals to the optimizer that the objective value needs to be decreased towards the upper bound (145)
    end  
    
end




end