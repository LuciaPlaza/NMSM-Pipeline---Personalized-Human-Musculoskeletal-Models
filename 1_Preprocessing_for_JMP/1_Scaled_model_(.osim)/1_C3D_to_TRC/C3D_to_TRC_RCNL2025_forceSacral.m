%% C3D_to_TRC_RCNL2025_forceSacral.m
% -------------------------------------------------------------------------
% PURPOSE
% -------------------------------------------------------------------------
% Convert MANY C3D files in subfolders into OpenSim TRC files.
%
% This script is designed for this specific workflow:
%   - input:  one root folder containing subject subfolders with .c3d files
%   - model:  RCNL2025.osim, Rajagopal/RCNL-style marker names
%   - output: one clean .trc per C3D file, written into the SAME subfolder
%             as the source C3D (no extra output folder created)
%
% The script does the same operations for each C3D:
%   1) Inspect the C3D parameter section: marker labels, analog labels,
%      frame count, sampling rate, and units.
%   2) Read marker trajectories using the OpenSim MATLAB API.
%   3) Keep only physical Plug-in Gait markers that can be safely mapped to
%      RCNL2025.osim markers.
%   4) Rename those markers from PiG labels to RCNL2025/Rajagopal labels.
%   5) Transform coordinates from your C3D laboratory convention to OpenSim.
%   6) Write a valid OpenSim .trc file.
%
% -------------------------------------------------------------------------
% HOW STATIC AND WALKING TRIALS ARE TREATED
% -------------------------------------------------------------------------
% Static trials:
%   - The code does NOT force walking direction.
%   - The static TRCs will be the ones used in the OpenSim Scale Tool.
%
% Walking/dynamic trials:
%   - The code can automatically rotate trials captured in the opposite
%     walking direction, so progression is + OpenSim X.
%   - The dynamic TRCs will be later used for Inverse Kinematics (IK).
%
% Trial type is inferred from the filename. By default, files containing
% '(0)', '_0', '-0', or 'static' are considered static. Everything else is
% considered dynamic/walking. 
%
% -------------------------------------------------------------------------
% HOW TO RUN
% -------------------------------------------------------------------------
% 1) This script, RCNL2025.osim and the C3D files must be in the same folder.
% 2) In MATLAB:
%       cd('C:\your\folder')
%       C3D_to_TRC_RCNL2025_forceSacral
%
% -------------------------------------------------------------------------

clear; clc;

%% ============================= USER SETTINGS ============================
% Folder containing the C3D files and RCNL2025.osim.
% By default, this is the folder where this script is located. If MATLAB does
% not know the script path, pwd is used.
scriptFullPath = mfilename('fullpath');
if isempty(scriptFullPath)
    defaultRoot = pwd;
else
    defaultRoot = fileparts(scriptFullPath);
end

% Set to true if you prefer to choose the folder interactively.
askUserToSelectFolder = false;

if askUserToSelectFolder
    selected = uigetdir(defaultRoot, 'Select folder containing the C3D files and RCNL2025.osim');
    if isequal(selected, 0)
        error('No folder selected.');
    end
    inputFolder = selected;
else
    inputFolder = defaultRoot;
end

% Model file. Normally keep this as RCNL2025.osim in the same folder.
osimFile = fullfile(inputFolder, 'RCNL2025.osim');

% Which C3D files should be converted.
% '*.c3d' converts every C3D in inputFolder.
c3dFilePattern = '*.c3d';

% Recursive conversion.
scanSubfolders = true;   % Read C3D files inside subfolders

% Output folder: same as input folder (TRC files go next to their C3D files).
% No extra folder is created; each TRC is written to the subfolder of its C3D.
outFolder = inputFolder;

% Static-trial filename patterns.
% A file is treated as static if its name contains any of these patterns.
staticNamePatterns = {'(0)', '_0', '-0', ' static', '_static', '-static', 'static'};

% Output TRC units.
outputUnits = 'mm';

% Coordinate transform from your C3D laboratory convention to OpenSim.
%
% Your files appeared to use:
%   C3D X = forward / walking direction
%   C3D Y = subject left
%   C3D Z = vertical / up
%
% OpenSim/Rajagopal convention is normally:
%   OpenSim X = forward
%   OpenSim Y = vertical / up
%   OpenSim Z = right
%
% Therefore:
%   OpenSim X = C3D X
%   OpenSim Y = C3D Z
%   OpenSim Z = -C3D Y
applyOpenSimCoordinateTransform = true;

% For walking/dynamic trials only, make pelvis progression positive in OpenSim X.
% Static trials are never direction-corrected.
makeWalkingDirectionPositiveX = true;

% Reset each TRC time vector to start at t = 0.
resetTimeToZero = true;

% Missing marker data. NaN is safer than zeros because zero is a real point at
% the origin. Writing zeros could create false marker locations.
missingDataPolicy = 'nan';

%% ======================= CHECK INPUTS AND OPENSIM API ====================
fprintf('\n============================================================\n');
fprintf('Batch C3D -> RCNL2025 TRC conversion\n');
fprintf('============================================================\n\n');

assertFileExists(osimFile, 'RCNL2025.osim model file');
assertOpenSimAPIAvailable();

%% ======================== DISCOVER C3D FILES =============================
trials = discoverC3DTrials(inputFolder, c3dFilePattern, scanSubfolders, staticNamePatterns);
if isempty(trials)
    error('No C3D files found in:\n  %s\nPattern: %s', inputFolder, c3dFilePattern);
end

fprintf('Input folder:\n  %s\n', inputFolder);
fprintf('Output folder:\n  %s\n', outFolder);
fprintf('Found %d C3D files.\n\n', numel(trials));
for i = 1:numel(trials)
    if trials(i).isStatic
        typeText = 'static';
    else
        typeText = 'dynamic/walking';
    end
    fprintf('  %02d) %-16s %s\n', i, typeText, trials(i).c3dFile);
end
fprintf('\n');

%% =========================== INSPECT OSIM MODEL ==========================
fprintf('Reading RCNL2025.osim MarkerSet...\n');
osimMarkerNames = readOpenSimMarkerNamesFromOSIM(osimFile);
fprintf('  RCNL2025.osim contains %d markers.\n', numel(osimMarkerNames));

markerRules = buildPiGtoRCNL2025MarkerRules(osimMarkerNames);
fprintf('  The conversion will export %d RCNL2025-compatible markers.\n\n', numel(markerRules));

%% ======================== CREATE INSPECTION REPORT ========================
reportFile = fullfile(inputFolder, 'C3D_to_TRC_inspection_and_conversion_report.txt');
reportFID = fopen(reportFile, 'w');
if reportFID < 0
    error('Could not create report file: %s', reportFile);
end
cleanupReport = onCleanup(@() fclose(reportFID));

fprintf(reportFID, 'Batch C3D -> RCNL2025 TRC conversion\n');
fprintf(reportFID, 'Input folder: %s\n', inputFolder);
fprintf(reportFID, 'Model: %s\n', osimFile);
fprintf(reportFID, 'Output folder: %s\n\n', outFolder);

fprintf(reportFID, 'RCNL2025.osim MarkerSet (%d markers):\n', numel(osimMarkerNames));
for i = 1:numel(osimMarkerNames)
    fprintf(reportFID, '  %02d  %s\n', i, osimMarkerNames{i});
end

fprintf(reportFID, '\nPiG -> RCNL2025 markers exported by this script:\n');
for r = 1:numel(markerRules)
    fprintf(reportFID, '  %-22s <= %-16s  | %s\n', ...
        markerRules(r).target, strjoin(markerRules(r).sources, ' + '), markerRules(r).reason);
end
fprintf(reportFID, '\n');

%% ============================ CONVERT EACH C3D ===========================
conversionReports = struct([]);

for i = 1:numel(trials)
    trial = trials(i);
    % Write each TRC into the same subfolder as its source C3D.
    outTRC = fullfile(fileparts(trial.c3dFile), trial.outName);

    fprintf('Converting %02d/%02d: %s\n', i, numel(trials), trial.c3dFile);

    % 1) Inspect C3D parameter section.
    info = inspectC3DParametersLight(trial.c3dFile);
    trials(i).paramInfo = info;
    writeC3DInspectionToReport(reportFID, trial.label, trial.c3dFile, info);

    % 2) Read marker trajectories using OpenSim API.
    raw = readC3DMarkersWithOpenSimAPI(trial.c3dFile);

    % 3) Convert to millimetres if OpenSim returned metres.
    [raw.data, detectedInputUnits, unitScale] = convertMarkerDataToMillimeters(raw.data);

    % 4) Apply coordinate transform from lab C3D convention to OpenSim.
    if applyOpenSimCoordinateTransform
        raw.data = transformC3DCoordinatesToOpenSim(raw.data);
        coordinateTransformDescription = 'OpenSim X=C3D X, OpenSim Y=C3D Z, OpenSim Z=-C3D Y';
    else
        coordinateTransformDescription = 'No coordinate transform applied';
    end

    % 5) Relabel PiG markers to RCNL2025 convention and remove everything else.
    mapped = mapPiGMarkersToRCNL2025(raw, markerRules);

    % 6) For walking/dynamic trials only, normalize walking direction to +X.
    walkingDirectionAction = 'not applied to static trial';
    if makeWalkingDirectionPositiveX && ~trial.isStatic
        [mapped.data, walkingDirectionAction] = forceWalkingProgressionToPositiveX(mapped.data, mapped.labels);
    end

    % 7) Time vector handling.
    if resetTimeToZero && ~isempty(mapped.time)
        mapped.time = mapped.time - mapped.time(1);
    end

    if isempty(mapped.time) || any(~isfinite(mapped.time)) || numel(mapped.time) ~= size(mapped.data,1)
        if isfield(info, 'pointRate') && ~isempty(info.pointRate) && info.pointRate > 0
            mapped.time = (0:size(mapped.data,1)-1)' ./ info.pointRate;
        else
            error('Could not determine a valid time vector for %s.', trial.c3dFile);
        end
    end

    % 8) Data rate for the TRC header.
    if isfield(info, 'pointRate') && ~isempty(info.pointRate) && info.pointRate > 0
        dataRate = info.pointRate;
    else
        dataRate = estimateRateFromTimeVector(mapped.time);
    end

    % 9) Write TRC.
    writeTRC(outTRC, mapped.time, mapped.labels, mapped.data, dataRate, outputUnits, missingDataPolicy);

    % 10) Store report.
    conversionReports(i).trial = trial.label; 
    conversionReports(i).isStatic = trial.isStatic;
    conversionReports(i).inputFile = trial.c3dFile;
    conversionReports(i).outputTRC = outTRC;
    conversionReports(i).rawOpenSimLabels = raw.labels;
    conversionReports(i).exportedLabels = mapped.labels;
    conversionReports(i).missingSources = mapped.missingSources;
    conversionReports(i).skippedTargets = mapped.skippedTargets;
    conversionReports(i).detectedInputUnits = detectedInputUnits;
    conversionReports(i).unitScaleToMM = unitScale;
    conversionReports(i).coordinateTransform = coordinateTransformDescription;
    conversionReports(i).walkingDirectionAction = walkingDirectionAction;
    conversionReports(i).numFrames = size(mapped.data,1);
    conversionReports(i).numMarkers = numel(mapped.labels);
    conversionReports(i).dataRate = dataRate;
    conversionReports(i).nanCount = sum(isnan(mapped.data(:)));
    conversionReports(i).sacralConstructionMethod = mapped.sacralConstructionMethod;

    fprintf('  Wrote: %s\n', outTRC);
    fprintf('  Frames: %d | Markers: %d | Rate: %.3f Hz | Input units detected: %s\n', ...
        conversionReports(i).numFrames, conversionReports(i).numMarkers, dataRate, detectedInputUnits);
    fprintf('  Coordinate transform: %s\n', coordinateTransformDescription);
    fprintf('  Walking direction: %s\n', walkingDirectionAction);
    fprintf('  Sacral marker: %s\n', mapped.sacralConstructionMethod);
    if ~isempty(mapped.missingSources)
        fprintf('  Missing/skipped source markers: %s\n', strjoin(unique(mapped.missingSources), ', '));
    end
    if isfield(mapped, 'skippedTargets') && ~isempty(mapped.skippedTargets)
        fprintf('  Skipped target markers: %s\n', strjoin(unique(mapped.skippedTargets), ', '));
    end
    fprintf('\n');

    writeConversionSummaryToReport(reportFID, conversionReports(i));
end

save(fullfile(inputFolder, 'C3D_to_TRC_conversion_report.mat'), ...
    'conversionReports', 'markerRules', 'osimMarkerNames', 'trials');

fprintf('============================================================\n');
fprintf('Finished. TRC files are written next to their source C3D files\n(inside each subject subfolder).\n');
fprintf('Report file:\n  %s\n', reportFile);
fprintf('============================================================\n\n');

%% ========================================================================
%% LOCAL FUNCTIONS
%% ========================================================================


function trials = discoverC3DTrials(inputFolder, pattern, scanSubfolders, staticNamePatterns)
    % Find C3D files and classify each one as static or dynamic.
    if scanSubfolders
        files = dir(fullfile(inputFolder, '**', pattern));
    else
        files = dir(fullfile(inputFolder, pattern));
    end

    % Remove directories just in case.
    files = files(~[files.isdir]);
    if isempty(files)
        trials = struct([]);
        return;
    end

    % Sort files in a more human/natural order when names contain trial numbers.
    files = sortFilesByNameAndNumber(files);

    trials = struct([]);
    for i = 1:numel(files)
        c3dFile = fullfile(files(i).folder, files(i).name);
        [~, baseName, ~] = fileparts(files(i).name);
        isStatic = inferStaticTrialFromName(baseName, staticNamePatterns);

        label = sanitizeFileStemForLabel(baseName);
        if isStatic
            typeSuffix = 'static';
        else
            typeSuffix = 'walk';
        end

        outName = sprintf('%s_%s_RCNL2025.trc', label, typeSuffix);

        trials(i).label = label;
        trials(i).c3dFile = c3dFile;
        trials(i).outName = outName;
        trials(i).isStatic = isStatic;
    end
end

function tf = inferStaticTrialFromName(baseName, staticNamePatterns)
    nameLower = lower(baseName);
    tf = false;
    for k = 1:numel(staticNamePatterns)
        if contains(nameLower, lower(staticNamePatterns{k}))
            tf = true;
            return;
        end
    end
end

function label = sanitizeFileStemForLabel(baseName)
    % Convert filenames like 'SUBJ1 (0)' to 'SUBJ1_0'.
    label = regexprep(baseName, '[^A-Za-z0-9]+', '_');
    label = regexprep(label, '_+', '_');
    label = regexprep(label, '^_|_$', '');
    if isempty(label)
        label = 'trial';
    end
end

function filesOut = sortFilesByNameAndNumber(filesIn)
    % Sort in a human/natural way for names such as:
    %   SUBJ1 (0).c3d, SUBJ1 (1).c3d, ..., SUBJ1 (10).c3d
    % This avoids alphabetic ordering where trial 10 would appear before 2.
    names = {filesIn.name};
    prefixKey = strings(size(names));
    numericKey = nan(size(names));

    for i = 1:numel(names)
        name = names{i};
        tok = regexp(name, '\((\d+)\)', 'tokens', 'once');
        if isempty(tok)
            tok = regexp(name, '(?:_|-|\s)(\d+)(?=\.c3d$)', 'tokens', 'once', 'ignorecase');
        end

        if ~isempty(tok)
            numericKey(i) = str2double(tok{1});
        else
            numericKey(i) = i;
        end

        prefix = regexprep(name, '\(\d+\)', '', 'ignorecase');
        prefix = regexprep(prefix, '(?:_|-|\s)\d+(?=\.c3d$)', '', 'ignorecase');
        prefixKey(i) = string(lower(strtrim(prefix)));
    end

    T = table(prefixKey(:), numericKey(:), string(names(:)), 'VariableNames', {'Prefix','Number','Name'});
    [~, idx] = sortrows(T, {'Prefix','Number','Name'});
    filesOut = filesIn(idx);
end

function assertFileExists(filePath, description)
    if ~exist(filePath, 'file')
        error('Missing %s:\n  %s', description, filePath);
    end
end

function assertOpenSimAPIAvailable()
    % Checks whether the OpenSim Java/MATLAB API is visible.
    try
        import org.opensim.modeling.*
        testModel = Model();
    catch ME
        error(['The OpenSim MATLAB API is not visible from MATLAB.\n\n' ...
               'This script requires OpenSim.\n' ...
               'Configure OpenSim with MATLAB first, then rerun this script.\n\n' ...
               'Original error:\n%s'], ME.message);
    end
end

function markerNames = readOpenSimMarkerNamesFromOSIM(osimFile)
    % Reads the MarkerSet names directly from the .osim XML file.
    % This avoids guessing the Rajagopal/RCNL2025 marker naming convention.
    doc = xmlread(osimFile);
    markerNodes = doc.getElementsByTagName('Marker');
    markerNames = cell(markerNodes.getLength, 1);
    for i = 0:markerNodes.getLength-1
        node = markerNodes.item(i);
        markerNames{i+1} = char(node.getAttribute('name'));
    end
end

function rules = buildPiGtoRCNL2025MarkerRules(osimMarkerNames)
    % Build the marker relabeling rules.
    %
    % The source names are the physical Plug-in Gait markers found in your C3D.
    % The target names are the actual marker names found in RCNL2025.osim.
    %
    % Posterior pelvis handling is deliberately conservative:
    %   - If a file contains SACR, Sacral is exported from SACR.
    %   - If a file does not contain SACR but contains LPSI and RPSI, Sacral is
    %     computed as the midpoint of LPSI/RPSI. This is acceptable because both
    %     are physical posterior pelvis markers and the midpoint approximates a
    %     single sacral marker.
    %   - If neither SACR nor both PSIS are available in a given frame, version 3
    %     estimates Sacral from the best remaining anatomy: one PSIS + ASIS midline,
    %     one PSIS + C7/T10 vertical line, or ASIS height + C7/T10 vertical line.
    %   - If LPSI/RPSI are present, they are also exported as L_Psis/R_Psis,
    %     because RCNL2025.osim contains those markers.
    %   - If a target marker cannot be built from real physical markers, it is
    %     skipped instead of being written as an all-NaN column.

    rules = struct('target', {}, 'sources', {}, 'operation', {}, 'reason', {});

    % Upper body / trunk.
    rules(end+1) = makeRule('R_Shoulder', {'RSHO'}, 'single', 'Right shoulder physical marker.');
    rules(end+1) = makeRule('L_Shoulder', {'LSHO'}, 'single', 'Left shoulder physical marker.');
    rules(end+1) = makeRule('C7',         {'C7'},   'single', 'C7 physical marker.');
    rules(end+1) = makeRule('J_Notch',    {'CLAV'}, 'single', 'PiG CLAV marker corresponds approximately to jugular notch/clavicle marker.');
    rules(end+1) = makeRule('R_Elbow',    {'RELB'}, 'single', 'Right elbow physical marker.');
    rules(end+1) = makeRule('L_Elbow',    {'LELB'}, 'single', 'Left elbow physical marker.');
    rules(end+1) = makeRule('R_Wrist',    {'RWRA','RWRB'}, 'mean', 'Average of the two right wrist bar markers.');
    rules(end+1) = makeRule('L_Wrist',    {'LWRA','LWRB'}, 'mean', 'Average of the two left wrist bar markers.');
    rules(end+1) = makeRule('Thoracic',   {'T10'},  'single', 'PiG T10 marker used as thoracic posterior trunk marker.');
    rules(end+1) = makeRule('Sternum',    {'STRN'}, 'single', 'Sternum physical marker.');

    % Pelvis.
    rules(end+1) = makeRule('R_Asis',     {'RASI'}, 'single', 'Right ASIS physical marker.');
    rules(end+1) = makeRule('L_Asis',     {'LASI'}, 'single', 'Left ASIS physical marker.');
    rules(end+1) = makeRule('R_Psis',     {'RPSI'}, 'single_optional', 'Right PSIS physical marker, exported only when present.');
    rules(end+1) = makeRule('L_Psis',     {'LPSI'}, 'single_optional', 'Left PSIS physical marker, exported only when present.');
    rules(end+1) = makeRule('Sacral',     {'SACR','LPSI','RPSI'}, 'sacral_from_sacr_or_psis', ...
        'Sacral marker from SACR when available; otherwise midpoint of LPSI and RPSI.');

    % Right lower limb.
    rules(end+1) = makeRule('R_Thigh_Lateral', {'RTHI'}, 'single', 'Right lateral thigh tracking marker.');
    rules(end+1) = makeRule('R_Knee_Lateral',  {'RKNE'}, 'single', 'Right lateral knee marker.');
    rules(end+1) = makeRule('R_Shank_Lateral', {'RTIB'}, 'single', 'Right lateral shank/tibia tracking marker.');
    rules(end+1) = makeRule('R_Ankle_Lateral', {'RANK'}, 'single', 'Right lateral ankle marker.');
    rules(end+1) = makeRule('R_Heel',          {'RHEE'}, 'single', 'Right heel marker.');
    rules(end+1) = makeRule('R_Toe',           {'RTOE'}, 'single', 'Right toe marker.');

    % Left lower limb.
    rules(end+1) = makeRule('L_Thigh_Lateral', {'LTHI'}, 'single', 'Left lateral thigh tracking marker.');
    rules(end+1) = makeRule('L_Knee_Lateral',  {'LKNE'}, 'single', 'Left lateral knee marker.');
    rules(end+1) = makeRule('L_Shank_Lateral', {'LTIB'}, 'single', 'Left lateral shank/tibia tracking marker.');
    rules(end+1) = makeRule('L_Ankle_Lateral', {'LANK'}, 'single', 'Left lateral ankle marker.');
    rules(end+1) = makeRule('L_Heel',          {'LHEE'}, 'single', 'Left heel marker.');
    rules(end+1) = makeRule('L_Toe',           {'LTOE'}, 'single', 'Left toe marker.');

    % Keep only target markers that exist in RCNL2025.osim.
    targetNames = {rules.target};
    existsInModel = ismember(targetNames, osimMarkerNames);
    if any(~existsInModel)
        warning('Some target markers were not found in RCNL2025.osim and will be skipped: %s', ...
            strjoin(targetNames(~existsInModel), ', '));
    end
    rules = rules(existsInModel);

    % Sort output marker order according to the order in the .osim MarkerSet.
    [~, modelOrder] = ismember({rules.target}, osimMarkerNames);
    [~, sortIdx] = sort(modelOrder);
    rules = rules(sortIdx);
end

function r = makeRule(target, sources, operation, reason)
    r = struct('target', target, 'sources', {sources}, 'operation', operation, 'reason', reason);
end

function raw = readC3DMarkersWithOpenSimAPI(c3dFile)
    % Reads marker trajectories from a C3D using OpenSim's C3DFileAdapter.
    %
    % Output:
    %   raw.labels : cell array of marker/POINT labels returned by OpenSim
    %   raw.time   : nFrames x 1 time vector
    %   raw.data   : nFrames x 3 x nLabels numeric array
    %
    % Note: depending on the OpenSim version, C3DFileAdapter may return marker
    % coordinates in metres even if the C3D POINT:UNITS parameter says mm. The
    % main script handles this using magnitude-based unit detection.

    import org.opensim.modeling.*

    adapter = C3DFileAdapter();
    tables = adapter.read(c3dFile);
    markerTable = adapter.getMarkersTable(tables);

    nRows = markerTable.getNumRows();
    nCols = markerTable.getNumColumns();

    % Extract labels.
    osimLabels = markerTable.getColumnLabels();
    labels = cell(1, nCols);
    for c = 0:nCols-1
        labels{c+1} = char(osimLabels.get(c));
    end

    % Extract time vector.
    time = zeros(nRows, 1);
    try
        independent = markerTable.getIndependentColumn();
        for r = 0:nRows-1
            time(r+1) = independent.get(r);
        end
    catch
        time = [];
    end

    % Extract Vec3 marker trajectories.
    data = nan(nRows, 3, nCols);
    for c = 1:nCols
        col = markerTable.getDependentColumn(labels{c});
        for r = 0:nRows-1
            vec = col.getElt(r, 0);
            data(r+1, 1, c) = vec.get(0);
            data(r+1, 2, c) = vec.get(1);
            data(r+1, 3, c) = vec.get(2);
        end
    end

    raw = struct();
    raw.labels = labels;
    raw.time = time;
    raw.data = data;
end

function [dataMM, detectedUnits, scaleToMM] = convertMarkerDataToMillimeters(data)
    % Convert the OpenSim C3DFileAdapter output to millimetres.
    %
    % Reason:
    %   The C3D file itself reports POINT:UNITS = mm, but OpenSim's adapter may
    %   return marker locations in metres depending on version/configuration.
    %   We therefore use a conservative magnitude check.
    %
    % Human marker coordinates are usually around:
    %   - 0.1 to 2.0 if in metres
    %   - 100 to 2000 if in millimetres

    v = abs(data(:));
    v = v(isfinite(v) & v > 0);
    if isempty(v)
        warning('Could not detect marker units from data magnitude. Assuming mm.');
        detectedUnits = 'unknown_assumed_mm';
        scaleToMM = 1;
        dataMM = data;
        return;
    end

    medAbs = median(v);
    if medAbs < 10
        detectedUnits = 'm';
        scaleToMM = 1000;
    else
        detectedUnits = 'mm';
        scaleToMM = 1;
    end

    dataMM = data .* scaleToMM;
end

function dataOS = transformC3DCoordinatesToOpenSim(dataC3D)
    % Applies:
    %   OpenSim X = C3D X
    %   OpenSim Y = C3D Z
    %   OpenSim Z = -C3D Y
    %
    % dataC3D is nFrames x 3 x nMarkers.
    dataOS = nan(size(dataC3D));
    dataOS(:,1,:) = dataC3D(:,1,:);
    dataOS(:,2,:) = dataC3D(:,3,:);
    dataOS(:,3,:) = -dataC3D(:,2,:);
end

function mapped = mapPiGMarkersToRCNL2025(raw, rules)
    % Creates a new marker table containing only markers that match RCNL2025.
    %
    % Markers whose source data are completely absent are skipped
    % instead of being exported as all-NaN columns. This is important for mixed
    % datasets where some files use SACR and others use LPSI/RPSI.
    %
    % The C3D/OpenSim source labels may contain prefixes such as SUBJECT:LASI.
    % For matching, we normalize labels by removing prefixes and comparing in
    % upper case. The original exact label is still used to extract data.

    nFrames = size(raw.data, 1);
    normalizedRawLabels = cellfun(@normalizeMarkerLabel, raw.labels, 'UniformOutput', false);

    outLabels = {};
    outData = nan(nFrames, 3, 0);
    missingSources = {};
    skippedTargets = {};
    sacralConstructionMethod = 'Sacral rule not reached';

    for r = 1:numel(rules)
        rule = rules(r);

        switch lower(rule.operation)
            case {'single','single_optional'}
                idx = findSourceIndex(normalizedRawLabels, rule.sources{1});
                if isempty(idx)
                    % Optional markers such as L_Psis/R_Psis are simply skipped
                    % if the C3D does not contain the corresponding physical marker.
                    skippedTargets{end+1} = rule.target; 
                    if strcmpi(rule.operation, 'single')
                        missingSources{end+1} = rule.sources{1}; 
                    end
                    continue;
                end
                outLabels{end+1} = rule.target; 
                outData(:,:,end+1) = raw.data(:,:,idx); 

            case 'mean'
                sourceDataStack = [];
                nFoundSources = 0;
                for s = 1:numel(rule.sources)
                    idx = findSourceIndex(normalizedRawLabels, rule.sources{s});
                    if isempty(idx)
                        missingSources{end+1} = rule.sources{s};
                        continue;
                    end
                    nFoundSources = nFoundSources + 1;
                    sourceDataStack(:,:,:,nFoundSources) = reshape(raw.data(:,:,idx), [nFrames, 3, 1, 1]); %#ok<AGROW>
                end
                if nFoundSources == 0
                    skippedTargets{end+1} = rule.target;
                    continue;
                end
                outLabels{end+1} = rule.target;
                outData(:,:,end+1) = meanIgnoringNaNs4D(sourceDataStack);

            case 'sacral_from_sacr_or_psis'
                % Sacral is mandatory because the scaling setup needs
                % a posterior pelvis / lower trunk reference. We therefore always
                % export a Sacral column.
                %
                % Construction hierarchy, frame by frame:
                %   1) real SACR if it exists and is valid;
                %   2) midpoint of LPSI/RPSI if both exist and are valid;
                %   3) one PSIS + ASIS midline, if one PSIS is visible;
                %   4) one PSIS + posterior trunk vertical line through C7/T10;
                %   5) ASIS height + posterior trunk vertical line through C7/T10;
                %   6) ASIS midpoint as a final very-low-confidence fallback.
                %
                % This marker must be documented as estimated whenever it is not
                % copied directly from a physical SACR marker.
                [sacralData, sacralConstructionMethod, sacralMissingText] = estimateSacralMarkerFromAvailableMarkers(raw, normalizedRawLabels);

                outLabels{end+1} = rule.target; 
                outData(:,:,end+1) = sacralData;

                if ~isempty(sacralMissingText)
                    missingSources{end+1} = sacralMissingText;
                end

            otherwise
                error('Unknown marker mapping operation: %s', rule.operation);
        end
    end

    mapped = struct();
    mapped.labels = outLabels;
    mapped.time = raw.time;
    mapped.data = outData;
    mapped.missingSources = unique(missingSources);
    mapped.skippedTargets = unique(skippedTargets);
    mapped.sacralConstructionMethod = sacralConstructionMethod;
end

function idx = findSourceIndex(normalizedRawLabels, sourceLabel)
    idx = find(strcmpi(normalizedRawLabels, normalizeMarkerLabel(sourceLabel)), 1, 'first');
end

function label = normalizeMarkerLabel(label)
    % Normalize a C3D/OpenSim marker label for matching.
    % Examples:
    %   'SUBJ1:LASI' -> 'LASI'
    %   ' LASI '     -> 'LASI'
    label = char(label);
    label = strtrim(label);
    colonIdx = find(label == ':', 1, 'last');
    if ~isempty(colonIdx)
        label = label(colonIdx+1:end);
    end
    label = strtrim(label);
    label = upper(label);
end

function M = meanIgnoringNaNs4D(stack)
    % stack: nFrames x 3 x 1 x nSources
    % returns nFrames x 3 matrix.
    sz = size(stack);
    if numel(sz) < 4
        M = stack(:,:,1);
        return;
    end

    nFrames = sz(1);
    M = nan(nFrames, 3);
    for f = 1:nFrames
        for xyz = 1:3
            vals = squeeze(stack(f, xyz, 1, :));
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                M(f, xyz) = mean(vals);
            end
        end
    end
end


function [sacralData, methodText, missingText] = estimateSacralMarkerFromAvailableMarkers(raw, normalizedRawLabels)
    % Estimate/create the RCNL2025 marker named Sacral.
    %
    % INPUT DATA ARE ALREADY IN OPENSIM COORDINATES AND MILLIMETRES.
    % Therefore, the resulting Sacral marker is written in the same coordinate
    % system as all other exported TRC markers.
    %
    % Best option:
    %   - If a real SACR marker exists in the C3D, preserve it.
    %
    % Strong fallback:
    %   - If LPSI and RPSI exist, compute their midpoint. This is the most
    %     defensible estimate of a single sacral marker because both markers are
    %     physical posterior pelvis landmarks.
    %
    % Other fallbacks:
    %   - If only one PSIS exists, use that PSIS depth/height and place the
    %     marker on the pelvis midline using the ASIS pair when available.
    %   - If PSIS data are absent but C7/T10 and ASIS are present, use the
    %     posterior trunk vertical line defined by C7/T10, and place the marker
    %     at pelvis/ASIS height. This is less anatomical and is marked as low
    %     confidence in the report.
    %
    % Output:
    %   sacralData : nFrames x 3 matrix.
    %   methodText : textual report of the construction method.
    %   missingText: empty if at least some finite data were produced; otherwise
    %                a warning string for the report.

    nFrames = size(raw.data, 1);
    sacralData = nan(nFrames, 3);
    methodPerFrame = strings(nFrames,1);

    % Candidate source labels. The first entries are the labels expected in your
    % current C3D files. Extra variants make the code more robust for other files.
    SACR = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'SACR','SACRAL','SAC'});
    LPSI = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'LPSI','LPSIS','LPS','L_PSI','L_PSIS'});
    RPSI = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'RPSI','RPSIS','RPS','R_PSI','R_PSIS'});
    LASI = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'LASI','LASIS','LASI1','L_ASI','L_ASIS'});
    RASI = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'RASI','RASIS','RASI1','R_ASI','R_ASIS'});
    C7   = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'C7'});
    T10  = getFirstAvailableMarkerData(raw, normalizedRawLabels, {'T10','THORACIC','THRX','T12'});

    for f = 1:nFrames
        pSACR = SACR(f,:);
        pLPSI = LPSI(f,:);
        pRPSI = RPSI(f,:);
        pLASI = LASI(f,:);
        pRASI = RASI(f,:);
        pC7   = C7(f,:);
        pT10  = T10(f,:);

        % 1) Real measured sacral marker.
        if isValid3DPoint(pSACR)
            sacralData(f,:) = pSACR;
            methodPerFrame(f) = "real_SACR";
            continue;
        end

        % 2) Best estimate: midpoint between both posterior pelvis markers.
        if isValid3DPoint(pLPSI) && isValid3DPoint(pRPSI)
            sacralData(f,:) = 0.5 .* (pLPSI + pRPSI);
            methodPerFrame(f) = "midpoint_LPSI_RPSI";
            continue;
        end

        % Compute ASIS pelvis midline if possible.
        asisMid = nan(1,3);
        hasAsisMid = false;
        if isValid3DPoint(pLASI) && isValid3DPoint(pRASI)
            asisMid = 0.5 .* (pLASI + pRASI);
            hasAsisMid = true;
        end

        % Compute posterior trunk vertical line using C7 and T10 if possible.
        % We use the X/Z position of the posterior trunk line and then set the
        % Y coordinate at pelvis/PSIS/ASIS height depending on availability.
        trunkXZ = nan(1,2); % [X Z]
        hasTrunkXZ = false;
        if isValid3DPoint(pC7) && isValid3DPoint(pT10)
            trunkMean = 0.5 .* (pC7 + pT10);
            trunkXZ = [trunkMean(1), trunkMean(3)];
            hasTrunkXZ = true;
        elseif isValid3DPoint(pT10)
            trunkXZ = [pT10(1), pT10(3)];
            hasTrunkXZ = true;
        elseif isValid3DPoint(pC7)
            trunkXZ = [pC7(1), pC7(3)];
            hasTrunkXZ = true;
        end

        % 3) Only one PSIS is present. Keep the posterior depth and height from
        % that PSIS, but use the ASIS pair to place the point on the pelvis
        % left-right midline.
        if isValid3DPoint(pLPSI) || isValid3DPoint(pRPSI)
            if isValid3DPoint(pLPSI)
                pOnePSIS = pLPSI;
                sideText = "LPSI_only";
            else
                pOnePSIS = pRPSI;
                sideText = "RPSI_only";
            end

            if hasAsisMid
                sacralData(f,:) = [pOnePSIS(1), pOnePSIS(2), asisMid(3)];
                methodPerFrame(f) = "one_PSIS_plus_ASIS_midline_" + sideText;
                continue;
            elseif hasTrunkXZ
                sacralData(f,:) = [trunkXZ(1), pOnePSIS(2), trunkXZ(2)];
                methodPerFrame(f) = "one_PSIS_plus_C7_T10_vertical_line_" + sideText;
                continue;
            else
                sacralData(f,:) = pOnePSIS;
                methodPerFrame(f) = "one_PSIS_only_low_confidence_" + sideText;
                continue;
            end
        end

        % 4) No SACR/PSIS. Use trunk posterior line at ASIS height.
        if hasAsisMid && hasTrunkXZ
            sacralData(f,:) = [trunkXZ(1), asisMid(2), trunkXZ(2)];
            methodPerFrame(f) = "C7_T10_vertical_line_at_ASIS_height_low_confidence";
            continue;
        end

        % 5) Final fallback: ASIS midpoint. This is not a posterior pelvis
        % marker; it only prevents an all-empty Sacral column. Treat as very
        % low confidence and do not give this marker high scaling weight.
        if hasAsisMid
            sacralData(f,:) = asisMid;
            methodPerFrame(f) = "ASIS_midpoint_very_low_confidence";
            continue;
        end

        methodPerFrame(f) = "failed_no_suitable_markers";
    end

    validRows = all(isfinite(sacralData), 2);
    if any(validRows)
        used = methodPerFrame(validRows);
        [u,~,ic] = unique(used);
        counts = accumarray(ic, 1);
        parts = strings(numel(u),1);
        for i = 1:numel(u)
            parts(i) = sprintf('%s: %d frames', u(i), counts(i));
        end
        methodText = strjoin(cellstr(parts), '; ');
        missingText = '';
    else
        methodText = 'failed: Sacral column written but all frames are NaN';
        missingText = 'Sacral_could_not_be_estimated_from_SACR_PSI_ASIS_C7_T10';
    end
end

function data = getFirstAvailableMarkerData(raw, normalizedRawLabels, candidateLabels)
    % Return nFrames x 3 data for the first candidate source marker found.
    nFrames = size(raw.data, 1);
    data = nan(nFrames, 3);
    for i = 1:numel(candidateLabels)
        idx = findSourceIndex(normalizedRawLabels, candidateLabels{i});
        if ~isempty(idx)
            data = raw.data(:,:,idx);
            return;
        end
    end
end

function tf = isValid3DPoint(p)
    tf = numel(p) == 3 && all(isfinite(p));
end

function [dataOut, action] = forceWalkingProgressionToPositiveX(dataIn, labels)
    % For walking trials, detect pelvis progression using L_Asis, R_Asis, and
    % Sacral if available. If the pelvis moves towards negative X, rotate the
    % whole marker cloud 180 degrees around OpenSim vertical Y.
    %
    % Rotation about Y by 180 deg:
    %   X -> -X
    %   Y ->  Y
    %   Z -> -Z

    dataOut = dataIn;
    action = 'already positive X or not enough pelvis data';

    pelvisLabels = {'L_Asis', 'R_Asis', 'Sacral'};
    idx = find(ismember(labels, pelvisLabels));
    if isempty(idx)
        action = 'not enough pelvis markers to detect walking direction';
        return;
    end

    pelvis = dataIn(:,:,idx);
    pelvisCenter = nan(size(dataIn,1), 3);
    for f = 1:size(dataIn,1)
        framePts = squeeze(pelvis(f,:,:))'; % nMarkers x 3
        for k = 1:3
            vals = framePts(:,k);
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                pelvisCenter(f,k) = mean(vals);
            end
        end
    end

    valid = isfinite(pelvisCenter(:,1));
    validIdx = find(valid);
    if numel(validIdx) < 2
        action = 'not enough valid pelvis frames to detect walking direction';
        return;
    end

    % Use first and last valid 10% of frames to avoid one noisy frame deciding
    % the direction.
    nUse = max(1, round(0.10 * numel(validIdx)));
    firstSet = validIdx(1:nUse);
    lastSet = validIdx(end-nUse+1:end);
    xStart = mean(pelvisCenter(firstSet,1), 'omitnan');
    xEnd = mean(pelvisCenter(lastSet,1), 'omitnan');
    dx = xEnd - xStart;

    if isfinite(dx) && dx < 0
        dataOut(:,1,:) = -dataIn(:,1,:);
        dataOut(:,2,:) =  dataIn(:,2,:);
        dataOut(:,3,:) = -dataIn(:,3,:);
        action = sprintf('rotated 180 deg about OpenSim Y because pelvis dx = %.3f mm', dx);
    else
        action = sprintf('kept original direction because pelvis dx = %.3f mm', dx);
    end
end

function writeTRC(filePath, time, labels, data, dataRate, units, missingDataPolicy)
    % Writes a valid OpenSim-style TRC file manually.
    % data is nFrames x 3 x nMarkers.

    if nargin < 7
        missingDataPolicy = 'nan';
    end
    if ~strcmpi(missingDataPolicy, 'nan')
        error('Only MissingDataPolicy = ''nan'' is intentionally supported. Writing zeros for missing markers is unsafe.');
    end

    nFrames = size(data, 1);
    nMarkers = numel(labels);
    [~, fname, ext] = fileparts(filePath);
    displayName = [fname ext];

    fid = fopen(filePath, 'w');
    if fid < 0
        error('Could not open TRC for writing: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'PathFileType\t4\t(X/Y/Z)\t%s\n', displayName);
    fprintf(fid, 'DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames\n');
    fprintf(fid, '%.10g\t%.10g\t%d\t%d\t%s\t%.10g\t%d\t%d\n', ...
        dataRate, dataRate, nFrames, nMarkers, units, dataRate, 1, nFrames);

    fprintf(fid, 'Frame#\tTime');
    for m = 1:nMarkers
        fprintf(fid, '\t%s\t\t', labels{m});
    end
    fprintf(fid, '\n');

    fprintf(fid, '\t\t');
    for m = 1:nMarkers
        if m < nMarkers
            fprintf(fid, 'X%d\tY%d\tZ%d\t', m, m, m);
        else
            fprintf(fid, 'X%d\tY%d\tZ%d', m, m, m);
        end
    end
    fprintf(fid, '\n');

    for f = 1:nFrames
        fprintf(fid, '%d\t%.8f', f, time(f));
        for m = 1:nMarkers
            xyz = data(f,:,m);
            fprintf(fid, '\t%.6f\t%.6f\t%.6f', xyz(1), xyz(2), xyz(3));
        end
        fprintf(fid, '\n');
    end
end

function rate = estimateRateFromTimeVector(time)
    dt = diff(time(:));
    dt = dt(isfinite(dt) & dt > 0);
    if isempty(dt)
        rate = 100;
    else
        rate = 1 / median(dt);
    end
end

function info = inspectC3DParametersLight(c3dFile)
    % Lightweight C3D parameter parser used only for inspection.
    % It reads parameters such as POINT:LABELS, POINT:RATE, ANALOG:LABELS.
    % It does not read trajectory data. The trajectory data are read using the
    % OpenSim C3DFileAdapter.

    params = readC3DParameterSection(c3dFile);

    info = struct();
    info.pointUsed   = getC3DParam(params, 'POINT',  'USED',   []);
    info.pointFrames = getC3DParam(params, 'POINT',  'FRAMES', []);
    info.pointRate   = getC3DParam(params, 'POINT',  'RATE',   []);
    info.pointUnits  = getC3DParam(params, 'POINT',  'UNITS',  '');
    info.pointLabels = getC3DParam(params, 'POINT',  'LABELS', {});

    info.analogUsed   = getC3DParam(params, 'ANALOG', 'USED',   []);
    info.analogRate   = getC3DParam(params, 'ANALOG', 'RATE',   []);
    info.analogLabels = getC3DParam(params, 'ANALOG', 'LABELS', {});
    info.analogUnits  = getC3DParam(params, 'ANALOG', 'UNITS',  {});

    info.subjectNames = getC3DParam(params, 'SUBJECTS', 'NAMES', {});
    info.markerSets   = getC3DParam(params, 'SUBJECTS', 'MARKER_SETS', {});
end

function params = readC3DParameterSection(c3dFile)
    % Minimal C3D parameter-section reader.
    %
    % This is included so that the script can inspect C3D labels/channels.
    % .It assumes little-endian C3D files, which matches your Vicon Nexus C3Ds.

    fid = fopen(c3dFile, 'rb', 'ieee-le');
    if fid < 0
        error('Could not open C3D file: %s', c3dFile);
    end
    cleaner = onCleanup(@() fclose(fid));

    parameterBlockNumber = fread(fid, 1, 'uint8');
    if isempty(parameterBlockNumber)
        error('Could not read C3D header from: %s', c3dFile);
    end

    parameterStart = double(parameterBlockNumber - 1) * 512;
    fseek(fid, parameterStart, 'bof');
    headerBytes = fread(fid, 4, 'uint8');
    if numel(headerBytes) < 4
        error('Could not read C3D parameter header from: %s', c3dFile);
    end

    nParameterBlocks = double(headerBytes(3));
    if nParameterBlocks <= 0
        nParameterBlocks = 20; % conservative fallback
    end
    parameterEnd = parameterStart + nParameterBlocks * 512;

    groups = struct('id', {}, 'name', {});
    records = struct('groupID', {}, 'name', {}, 'value', {});

    pos = parameterStart + 4;
    while pos < parameterEnd
        fseek(fid, pos, 'bof');
        nameLength = fread(fid, 1, 'int8');
        if isempty(nameLength) || nameLength == 0
            break;
        end
        groupID = fread(fid, 1, 'int8');
        if isempty(groupID)
            break;
        end

        nChars = abs(double(nameLength));
        name = char(fread(fid, nChars, 'uint8')');
        name = strtrim(name);

        offsetPosition = ftell(fid);
        offsetToNext = fread(fid, 1, 'int16');
        if isempty(offsetToNext) || offsetToNext == 0
            break;
        end

        if groupID < 0
            descriptionLength = fread(fid, 1, 'uint8');
            if ~isempty(descriptionLength) && descriptionLength > 0
                fread(fid, descriptionLength, 'uint8'); % description not needed
            end
            groups(end+1).id = abs(double(groupID)); 
            groups(end).name = upper(name);
        else
            dataType = fread(fid, 1, 'int8');
            nDimensions = fread(fid, 1, 'uint8');
            if isempty(dataType) || isempty(nDimensions)
                break;
            end
            dimensions = fread(fid, double(nDimensions), 'uint8')';
            if isempty(dimensions)
                nItems = 1;
            else
                nItems = prod(double(dimensions));
            end

            value = readC3DParameterValue(fid, dataType, dimensions, nItems);

            descriptionLength = fread(fid, 1, 'uint8');
            if ~isempty(descriptionLength) && descriptionLength > 0
                fread(fid, descriptionLength, 'uint8'); % description not needed
            end

            records(end+1).groupID = double(groupID);
            records(end).name = upper(name);
            records(end).value = value;
        end

        % In the C3D parameter format, offsetToNext is measured from the byte
        % position of the offset field, not from the current file position.
        pos = offsetPosition + double(offsetToNext);
    end

    params = struct();
    for r = 1:numel(records)
        groupName = findGroupName(groups, records(r).groupID);
        if isempty(groupName)
            groupName = sprintf('GROUP%d', records(r).groupID);
        end
        g = matlab.lang.makeValidName(upper(groupName));
        p = matlab.lang.makeValidName(upper(records(r).name));
        if ~isfield(params, g)
            params.(g) = struct();
        end
        params.(g).(p) = records(r).value;
    end
end

function value = readC3DParameterValue(fid, dataType, dimensions, nItems)
    switch double(dataType)
        case -1 % character
            raw = char(fread(fid, nItems, 'uint8')');
            if numel(dimensions) == 2
                charLen = double(dimensions(1));
                count = double(dimensions(2));
                value = cell(1, count);
                for i = 1:count
                    idx1 = (i-1)*charLen + 1;
                    idx2 = i*charLen;
                    value{i} = strtrim(raw(idx1:idx2));
                end
            else
                value = strtrim(raw);
            end
        case 1 % signed byte
            value = fread(fid, nItems, 'int8')';
        case 2 % int16
            value = fread(fid, nItems, 'int16')';
        case 4 % float32
            value = fread(fid, nItems, 'float32')';
        otherwise
            % Unknown type: consume bytes conservatively as uint8.
            value = fread(fid, nItems, 'uint8')';
    end

    if isnumeric(value) && numel(value) == 1
        value = value(1);
    end
end

function groupName = findGroupName(groups, groupID)
    groupName = '';
    for i = 1:numel(groups)
        if groups(i).id == groupID
            groupName = groups(i).name;
            return;
        end
    end
end

function value = getC3DParam(params, groupName, paramName, defaultValue)
    g = matlab.lang.makeValidName(upper(groupName));
    p = matlab.lang.makeValidName(upper(paramName));
    if isfield(params, g) && isfield(params.(g), p)
        value = params.(g).(p);
    else
        value = defaultValue;
    end
end

function writeC3DInspectionToReport(fid, trialLabel, c3dFile, info)
    fprintf(fid, '============================================================\n');
    fprintf(fid, 'C3D inspection: %s\n', trialLabel);
    fprintf(fid, 'File: %s\n', c3dFile);
    fprintf(fid, '------------------------------------------------------------\n');
    fprintf(fid, 'POINT:USED   = %s\n', valueToString(info.pointUsed));
    fprintf(fid, 'POINT:FRAMES = %s\n', valueToString(info.pointFrames));
    fprintf(fid, 'POINT:RATE   = %s\n', valueToString(info.pointRate));
    fprintf(fid, 'POINT:UNITS  = %s\n', valueToString(info.pointUnits));
    fprintf(fid, 'ANALOG:USED  = %s\n', valueToString(info.analogUsed));
    fprintf(fid, 'ANALOG:RATE  = %s\n', valueToString(info.analogRate));

    fprintf(fid, '\nPOINT labels (%d):\n', numel(info.pointLabels));
    writeCellList(fid, info.pointLabels, 6);

    fprintf(fid, '\nANALOG labels (%d):\n', numel(info.analogLabels));
    writeCellList(fid, info.analogLabels, 6);

    fprintf(fid, '\n\n');
end

function writeConversionSummaryToReport(fid, rep)
    fprintf(fid, '============================================================\n');
    fprintf(fid, 'Conversion summary: %s\n', rep.trial);
    fprintf(fid, 'Input:  %s\n', rep.inputFile);
    fprintf(fid, 'Output: %s\n', rep.outputTRC);
    fprintf(fid, 'Frames: %d\n', rep.numFrames);
    fprintf(fid, 'Markers exported: %d\n', rep.numMarkers);
    fprintf(fid, 'Data rate: %.6f Hz\n', rep.dataRate);
    fprintf(fid, 'Detected OpenSim input units: %s\n', rep.detectedInputUnits);
    fprintf(fid, 'Scale to mm: %.6f\n', rep.unitScaleToMM);
    fprintf(fid, 'Coordinate transform: %s\n', rep.coordinateTransform);
    fprintf(fid, 'Walking direction action: %s\n', rep.walkingDirectionAction);
    if isfield(rep, 'sacralConstructionMethod')
        fprintf(fid, 'Sacral construction: %s\n', rep.sacralConstructionMethod);
    end
    fprintf(fid, 'NaN values in exported data: %d\n', rep.nanCount);
    fprintf(fid, '\nExported RCNL2025 labels:\n');
    writeCellList(fid, rep.exportedLabels, 4);
    if ~isempty(rep.missingSources)
        fprintf(fid, '\nMissing/skipped source markers requested by mapping:\n');
        writeCellList(fid, rep.missingSources, 4);
    end
    if isfield(rep, 'skippedTargets') && ~isempty(rep.skippedTargets)
        fprintf(fid, '\nSkipped target markers because they could not be built from physical C3D markers:\n');
        writeCellList(fid, rep.skippedTargets, 4);
    end
    fprintf(fid, '\n\n');
end

function writeCellList(fid, values, perLine)
    if isempty(values)
        fprintf(fid, '  <none>\n');
        return;
    end
    if ischar(values)
        values = {values};
    end
    for i = 1:numel(values)
        fprintf(fid, '  %-24s', values{i});
        if mod(i, perLine) == 0 || i == numel(values)
            fprintf(fid, '\n');
        end
    end
end

function s = valueToString(v)
    if isempty(v)
        s = '<empty>';
    elseif isnumeric(v)
        if numel(v) == 1
            s = num2str(v);
        else
            s = mat2str(v);
        end
    elseif ischar(v)
        s = v;
    elseif iscell(v)
        s = sprintf('cell[%d]', numel(v));
    else
        s = '<value>';
    end
end