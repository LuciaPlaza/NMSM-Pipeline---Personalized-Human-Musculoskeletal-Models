%% SUBJ36_1_Step1_JMP.m  — v6
%
% CHANGES FROM v5
% ===============
% 1. Ankle joint axis moved OUT of Step 2 into a new dedicated Step 4.
%    In v5, ankle orientation in Step 2 caused severe degradation:
%      L_Ankle_Lateral: 2.94 -> 5.44 mm (+85%) in Step 2 alone.
%    Root cause: ankle axis optimization competed with large knee/shank
%    errors. The optimizer sacrificed ankle accuracy to reduce the bigger
%    knee cost. Separating ankle into its own final step eliminates
%    this competition entirely.
%
% 2. calcn_r/l added to Step 3 with scale_body=false, move_markers=XZ.
%    In v5, tibia scaling in Step 3 worsened heel/toe because the calcn
%    segment wasn't included and couldn't compensate. With calcn markers
%    free to reposition (XZ, no body scaling), heel/toe can improve too.
%
% 3. Step 2 evaluations: 800 -> 600 (fewer params without ankle joints).
%    Step 4 evaluations: 400 (small problem, 4 orientation params only).
%    Total: 1200+600+600+400 = 2800 vs previous 1200+800+600 = 2600.
%    ~30 min extra, well justified.

clear; clc; close all;

%% ========================== USER SETTINGS ================================

baseFolder  = 'C:\Users\lucia\Desktop\TFG\2_JMP\SUBJ36\Walk_1';
nmsmProject = 'C:\Users\lucia\Downloads\nmsm-core-1.5.3\nmsm-core-1.5.3\Project.prj';

originalSettingsFiles = {
    fullfile(baseFolder, 'SUBJ36_1_JMP_01_pelvis_thigh_marker_adjustment.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_02_knee_ankle_joint_personalization.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_03_lower_limb_body_marker_personalization.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_04_ankle_axis_personalization.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_05_torso_marker_adjustment.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_06_shoulder_elbow_joint_personalization.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_07_upper_limb_body_marker_personalization.xml')
    fullfile(baseFolder, 'SUBJ36_1_JMP_08_wrist_axis_personalization.xml')
};

% Steps 1-4: stroke-specific leg configuration (validated in TVC26 v3).
% Steps 5-8: upper body, same structure as SUBJ1 v9 but with slightly
%   higher eval budgets (torso 1500, shoulder/upper-limb 1000 each)
%   to account for stroke-related trunk compensation asymmetry and
%   reduced arm swing on the paretic side.
useUpdatedMaxFunctionEvaluations = true;
maxFunctionEvaluationsPerStep    = [6000 2000 2500 100 1500 1000 1500 300];

stopOnCriticalError = true;

resultsFolder = fullfile(baseFolder, 'SUBJ36_1_JMP_results');
runnerFolder  = fullfile(resultsFolder, 'JMP_runner_logs');

%% ========================== PREPARE ======================================

if ~exist(baseFolder,'dir'), error('baseFolder not found:\n%s', baseFolder); end
if ~exist(resultsFolder,'dir'), mkdir(resultsFolder); end
if ~exist(runnerFolder, 'dir'), mkdir(runnerFolder);  end

for i = 1:numel(originalSettingsFiles)
    if ~exist(originalSettingsFiles{i},'file')
        error('Missing XML:\n%s', originalSettingsFiles{i});
    end
end

logFile = fullfile(runnerFolder, ['JMP_run_log_' datestr(now,'yyyymmdd_HHMMSS') '.txt']);
diary(logFile);
cleanupDiary = onCleanup(@() diary('off'));

fprintf('============================================================\n');
fprintf('NMSM JMP RUNNER  v6  SUBJ36 Walk_1  (v5 full body - stroke config, 8 steps, redistributed budget)\n');
fprintf('Started: %s\n', datestr(now));
fprintf('============================================================\n');

%% ========================== OPEN NMSM ====================================

if isempty(which('JointModelPersonalizationTool'))
    if ~isempty(nmsmProject) && exist(nmsmProject,'file')
        openProject(nmsmProject);
    else
        error('JointModelPersonalizationTool not found. Open Project.prj first.');
    end
end
fprintf('NMSM: %s\n', which('JointModelPersonalizationTool'));

import org.opensim.modeling.*
try, ModelVisualizer.addDirToGeometrySearchPaths(fullfile(baseFolder,'Geometry')); catch; end
try, Model(); fprintf('OpenSim API OK.\n');
catch ME, error('OpenSim API error:\n%s', ME.message); end

%% ========================== XML PREPARATION ==============================

if useUpdatedMaxFunctionEvaluations
    xmlOut = fullfile(runnerFolder,'AutoXML_with_updated_MaxFunctionEvaluations');
    if ~exist(xmlOut,'dir'), mkdir(xmlOut); end
    settingsFiles = cell(size(originalSettingsFiles));
    for i = 1:numel(originalSettingsFiles)
        settingsFiles{i} = createXMLWithNewMaxFunctionEvaluations( ...
            originalSettingsFiles{i}, xmlOut, maxFunctionEvaluationsPerStep(i));
        fprintf('Step %d XML (%d evals): %s\n', i, maxFunctionEvaluationsPerStep(i), settingsFiles{i});
    end
else
    settingsFiles = originalSettingsFiles;
end

%% ========================== RUN JMP STEPS ================================

cd(baseFolder);

for i = 1:numel(settingsFiles)
    step = readJMPSettingsXML(settingsFiles{i}, baseFolder);
    fprintf('\n=== STEP %d/%d ===\n  In:  %s\n  Out: %s\n', ...
        i, numel(settingsFiles), step.inputModelFile, step.outputModelFile);

    if ~exist(step.inputModelFile,'file')
        handleCriticalError(sprintf('Input model missing:\n%s', step.inputModelFile), stopOnCriticalError);
        continue;
    end
    if exist(step.outputModelFile,'file')
        bk = [step.outputModelFile '.bak_' datestr(now,'yyyymmdd_HHMMSS')];
        movefile(step.outputModelFile, bk);
    end

    try
        JointModelPersonalizationTool(settingsFiles{i});
    catch ME
        handleCriticalError(sprintf('JMP error step %d:\n%s', i, ...
            getReport(ME,'extended','hyperlinks','off')), stopOnCriticalError);
        continue;
    end

    if exist(step.outputModelFile,'file')
        fprintf('Step %d done: %s\n', i, step.outputModelFile);
    else
        handleCriticalError(sprintf('Output missing after step %d', i), stopOnCriticalError);
    end
end

fprintf('\nAll steps done. Log: %s\n', logFile);
fprintf('Next: run SUBJ36_1_Step2_STO_PLOTS.m\n');

%% ========================== LOCAL FUNCTIONS ==============================

function handleCriticalError(msg, stopFlag)
    fprintf(2,'\nERROR:\n%s\n',msg);
    if stopFlag, error('%s',msg); else, warning('%s',msg); end
end

function outFile = createXMLWithNewMaxFunctionEvaluations(xmlFile, outFolder, newVal)
    txt = fileread(xmlFile);
    if ~contains(txt,'<max_function_evaluations>')
        error('No <max_function_evaluations> in:\n%s', xmlFile);
    end
    newTxt = regexprep(txt, ...
        '<max_function_evaluations>.*?</max_function_evaluations>', ...
        sprintf('<max_function_evaluations>%d</max_function_evaluations>', newVal));
    [~,name,ext] = fileparts(xmlFile);
    outFile = fullfile(outFolder, sprintf('%s_maxEval%d%s', name, newVal, ext));
    fid = fopen(outFile,'w');
    if fid < 0, error('Cannot write:\n%s', outFile); end
    fprintf(fid,'%s',newTxt); fclose(fid);
end

function step = readJMPSettingsXML(xmlFile, baseFolder)
    txt = fileread(xmlFile);
    inDir  = getTag(txt,'input_directory');
    if isempty(inDir) || strcmp(strtrim(inDir),'.'), base = baseFolder;
    elseif isAbsPath(inDir), base = inDir;
    else, base = fullfile(baseFolder, inDir); end
    step.inputModelFile  = resolvePath(getTag(txt,'input_model_file'),  base);
    step.outputModelFile = resolvePath(getTag(txt,'output_model_file'), base);
    step.trcFile         = resolvePath(getTag(txt,'marker_file_name'),  base);
    step.timeRangeText   = getTag(txt,'time_range');
end

function t = getTag(xml, tag)
    tok = regexp(xml, ['<' tag '>\s*(.*?)\s*</' tag '>'], 'tokens','once');
    if isempty(tok), t=''; else, t=strtrim(tok{1}); end
end

function p = resolvePath(p, base)
    p = strtrim(p);
    if ~isempty(p) && ~isAbsPath(p), p = fullfile(base,p); end
end

function tf = isAbsPath(p)
    tf = (numel(p)>=2 && p(2)==':') || startsWith(p,filesep) || startsWith(p,'\\');
end
