%% SUBJ1_1_Step2_STO_PLOTS.m  — v9 (generalized for N steps)
%
% PURPOSE
% -------
% Post-process JMP results: generate STO error files, per-step plots,
% and a comprehensive global comparison between the scaled input model
% (TVC39_scaled.osim) and the final personalised model (after the LAST
% step in settingsFiles).
%
% CHANGES FROM v6
% ----------------
% 1. GENERALIZED to any number of steps (was hardcoded to 4 steps / 5
%    states). All loops now use nSteps = numel(settingsFiles) and
%    nStates = nSteps + 1, so adding/removing steps (e.g. the new torso
%    and arm steps 5-8) no longer requires manually editing array sizes
%    or loop bounds throughout the script.
%
% 2. BUG FIX: the radar chart and the console "GLOBAL RMS" summary
%    previously used RMS(4,:) as if it were the final state, but in the
%    5-state indexing (1=scaled, 2..4=steps 1-3, 5=step 4/final) that is
%    actually "after Step 3", NOT the true final model. This was silent
%    for SUBJ1 only because Step 4 (ankle axis) converged with exactly
%    zero change there, making RMS(4,:) numerically equal to RMS(5,:) by
%    coincidence. With more steps added (and no guarantee the last step
%    is a no-op), this bug would have silently produced an incorrect
%    "final" plot. Now everything correctly references RMS(end,:).
%
% 3. defaultMarkerNames extended from 15 (pelvis + lower limb) to 25
%    (+ torso: R/L_Shoulder, C7, J_Notch, Thoracic, Sternum;
%     + arms:  R/L_Elbow, R/L_Wrist), to analyse all markers now that
%    the upper body is personalised too.
%
% 4. State colors are now generated programmatically for any nStates via
%    interpolation across the same grey->blue->green->orange->red ramp
%    used before (instead of a hardcoded 5-row matrix).
%
% OUTPUTS
% -------
%  TVC39_1_JMP_results/TVC39_1_STO_and_Plots_ONLY/
%    step_0N_*/        - per-step initial/final STO error files
%    step_0N_marker_errors_page_NN.png   - time-series per marker
%    step_0N_marker_mean_error_changes.png
%    JMP_global_step_error_summary.csv
%    JMP_marker_error_summary.csv
%    JMP_global_mean_error_summary.png
%
%    global_comparison/
%      global_marker_RMS_comparison.png     - bar: scaled vs final, per marker
%      global_marker_improvement_pct.png    - % improvement per marker
%      global_step_progression.png          - RMS evolution across all states
%      global_waterfall.png                 - stacked contribution per step
%      global_radar_chart.png               - normalised scaled vs final
%      global_worst6_timeseries.png         - 6 highest-error markers
%      global_allmarkers_NN_<marker>.png    - one page per marker, all markers
%      global_summary_table.csv             - full numeric table

clear; clc; close all;

%% ========================== USER SETTINGS ================================

baseFolder = 'C:\Users\lucia\Desktop\TFG\2_JMP\TVC39\Walk_1';

settingsFiles = {
    fullfile(baseFolder, 'TVC39_1_JMP_01_pelvis_thigh_marker_adjustment.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_02_knee_ankle_joint_personalization.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_03_lower_limb_body_marker_personalization.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_04_ankle_axis_personalization.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_05_torso_marker_adjustment.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_06_shoulder_elbow_joint_personalization.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_07_upper_limb_body_marker_personalization.xml')
    fullfile(baseFolder, 'TVC39_1_JMP_08_wrist_axis_personalization.xml')
};

resultsFolder  = fullfile(baseFolder, 'TVC39_1_JMP_results');
analysisFolder = fullfile(resultsFolder, 'TVC39_1_STO_and_Plots_ONLY');
globalFolder   = fullfile(analysisFolder, 'global_comparison');

defaultMarkerNames = {
    % --- Pelvis (27 markers for stroke subjects: includes R_Psis and L_Psis) ---
    'R_Asis'; 'L_Asis'; 'R_Psis'; 'L_Psis'; 'Sacral';
    % --- Lower limb ---
    'R_Thigh_Lateral'; 'R_Knee_Lateral'; 'R_Shank_Lateral';
    'R_Ankle_Lateral'; 'R_Heel'; 'R_Toe';
    'L_Thigh_Lateral'; 'L_Knee_Lateral'; 'L_Shank_Lateral';
    'L_Ankle_Lateral'; 'L_Heel'; 'L_Toe';
    % --- Torso (NEW) ---
    'R_Shoulder'; 'L_Shoulder'; 'C7'; 'J_Notch'; 'Thoracic'; 'Sternum';
    % --- Arms (NEW) ---
    'R_Elbow'; 'L_Elbow'; 'R_Wrist'; 'L_Wrist'
};

ikAccuracy     = 1e-5;
markerWeight   = 1.0;
makePlots      = true;
maxMarkersPerFigure = 6;

%% ========================== PREPARE ======================================

if ~exist(baseFolder,'dir'),  error('baseFolder not found:\n%s', baseFolder); end
if ~exist(resultsFolder,'dir'), mkdir(resultsFolder); end
if ~exist(analysisFolder,'dir'), mkdir(analysisFolder); end
if ~exist(globalFolder,'dir'), mkdir(globalFolder); end

import org.opensim.modeling.*
try, ModelVisualizer.addDirToGeometrySearchPaths(fullfile(baseFolder,'Geometry')); catch; end
try, Model(); fprintf('OpenSim API OK.\n');
catch ME, error('OpenSim API error:\n%s', ME.message); end

nSteps  = numel(settingsFiles);
nStates = nSteps + 1;   % state 1 = scaled, state k+1 = after step k

%% ========================== RESOLVE MODEL PATHS ==========================

% Step 0 = scaled model (before any JMP)
scaledModel = fullfile(baseFolder, 'TVC39_scaled.osim');

% Final model = output of the LAST step in settingsFiles (not hardcoded
% to any particular step index, so the script adapts automatically if
% steps are added or removed).
stepLast   = readJMPSettingsXML(settingsFiles{end}, defaultMarkerNames, baseFolder);
finalModel = stepLast.outputModelFile;

trcFile   = stepLast.trcFile;
timeRange = stepLast.timeRange;

if ~exist(scaledModel,'file'), error('Scaled model not found:\n%s', scaledModel); end
if ~exist(finalModel,'file'),  error('Final JMP model not found:\n%s', finalModel); end
if ~exist(trcFile,'file'),     error('TRC not found:\n%s', trcFile); end

markerNames = defaultMarkerNames;

%% ========================== PER-STEP STO FILES ===========================

stepErrorPairs = cell(nSteps, 2);
stepNames      = cell(nSteps, 1);

for i = 1:nSteps
    [~, xmlBase, ~] = fileparts(settingsFiles{i});
    stepNames{i}    = xmlBase;
    step = readJMPSettingsXML(settingsFiles{i}, defaultMarkerNames, baseFolder);

    fprintf('\n--- Step %d/%d: %s ---\n', i, nSteps, xmlBase);

    if ~exist(step.inputModelFile,'file')
        error('Input model missing step %d:\n%s', i, step.inputModelFile);
    end
    if ~exist(step.outputModelFile,'file')
        error('Output model missing step %d:\n%s', i, step.outputModelFile);
    end

    stepOut    = fullfile(analysisFolder, sprintf('step_%02d_%s', i, xmlBase));
    if ~exist(stepOut,'dir'), mkdir(stepOut); end

    prefix     = sprintf('%s_task_1', xmlBase);
    iniSto     = fullfile(stepOut, [prefix '_initialErrors.sto']);
    finSto     = fullfile(stepOut, [prefix '_finalErrors.sto']);

    generateMarkerErrorSTOPair(step.inputModelFile, step.outputModelFile, ...
        step.trcFile, step.markerNames, step.timeRange, ...
        iniSto, finSto, stepOut, prefix, ikAccuracy, markerWeight);

    stepErrorPairs{i,1} = iniSto;
    stepErrorPairs{i,2} = finSto;
end

%% ========================== PER-STEP PLOTS & CSVS ========================

fprintf('\n--- Per-step plots ---\n');
plotAndSummarizeSteps(stepErrorPairs, stepNames, analysisFolder, makePlots, maxMarkersPerFigure);

%% ========================== GLOBAL COMPARISON ============================
%  Compare SUBJ1_scaled (state 1) vs the LAST step's output (state nStates)
%  and track the full nStates progression.

fprintf('\n--- Global comparison: scaled vs final ---\n');

% Run IK for scaled model (state 1)
ik0File = fullfile(globalFolder, 'global_scaled_IK.mot');
sto0    = fullfile(globalFolder, 'global_scaled_errors.sto');
fprintf('  IK: scaled model...\n');
runIKForErrors(scaledModel, trcFile, ik0File, markerNames, timeRange, ikAccuracy, markerWeight);
computeMarkerErrorSTO(scaledModel, trcFile, ik0File, markerNames, sto0);

% Run IK for final model (state nStates)
ikFFile = fullfile(globalFolder, 'global_final_IK.mot');
stoF    = fullfile(globalFolder, 'global_final_errors.sto');
fprintf('  IK: final model...\n');
runIKForErrors(finalModel, trcFile, ikFFile, markerNames, timeRange, ikAccuracy, markerWeight);
computeMarkerErrorSTO(finalModel, trcFile, ikFFile, markerNames, stoF);

% Build the full state list: 1=scaled, 2..nSteps+1 = each step's FINAL error file
sto_states  = [{sto0}; stepErrorPairs(:,2)];
stateLabels = [{'Scaled (S0)'}, arrayfun(@(k) sprintf('After Step %d', k), 1:nSteps, 'UniformOutput', false)];
stateLabels{end} = sprintf('Final (after Step %d)', nSteps);
stateColors = makeStateColormap(nStates);

% Parse all states
stateData = cell(nStates,1);
for s = 1:nStates
    stateData{s} = readOpenSimStorageLocal(sto_states{s});
end

% Common markers across ALL states (robust intersection, not just first vs one other)
commonM = string(stateData{1}.labels(2:end));
for s = 2:nStates
    commonM = intersect(commonM, string(stateData{s}.labels(2:end)), 'stable');
end
nM = numel(commonM);

% Build RMS matrix [nStates x nMarkers]
RMS  = zeros(nStates, nM);
MEAN = zeros(nStates, nM);
for s = 1:nStates
    [~, idxS] = ismember(commonM, string(stateData{s}.labels(2:end)));
    for m = 1:nM
        col = stateData{s}.data(:, idxS(m)+1);
        RMS(s,m)  = sqrt(mean(col.^2, 'omitnan')) * 1000;
        MEAN(s,m) = mean(col, 'omitnan') * 1000;
    end
end

%% -- PLOT 1: Grouped bar — scaled vs final RMS per marker -----------------
if makePlots
    fig = figure('Visible','off','Color','w','Position',[50 50 1600 580]);
    bh  = bar([RMS(1,:); RMS(end,:)]', 'grouped');
    bh(1).FaceColor = stateColors(1,:);
    bh(2).FaceColor = stateColors(end,:);
    grid on; box off;
    xticks(1:nM);
    xticklabels(strrep(cellstr(commonM),'_','\_'));
    xtickangle(40);
    ylabel('RMS marker error [mm]');
    title('Marker errors: scaled model vs JMP final (all markers)', 'FontWeight','bold');
    legend({'Scaled input','JMP final'}, 'Location','northeast');
    yline(5,'--k','LineWidth',1,'Label','5 mm','LabelVerticalAlignment','bottom');
    saveas(fig, fullfile(globalFolder,'global_marker_RMS_comparison.png')); close(fig);
    fprintf('  Saved: global_marker_RMS_comparison.png\n');
end

%% -- PLOT 2: % improvement per marker (RMS) --------------------------------
if makePlots
    pct_improv = 100 * (RMS(1,:) - RMS(end,:)) ./ RMS(1,:);
    [~, sortIdx] = sort(pct_improv, 'descend');

    fig = figure('Visible','off','Color','w','Position',[50 50 1500 520]);
    bh  = bar(pct_improv(sortIdx));
    bh.FaceColor = 'flat';
    for k = 1:nM
        if pct_improv(sortIdx(k)) >= 0
            bh.CData(k,:) = [0.2 0.7 0.3];   % green = improvement
        else
            bh.CData(k,:) = [0.9 0.3 0.2];   % red = worsening
        end
    end
    grid on; box off;
    xticks(1:nM);
    xticklabels(strrep(cellstr(commonM(sortIdx)),'_','\_'));
    xtickangle(40);
    ylabel('Improvement [%]');
    yline(0,'k-','LineWidth',1);
    title('RMS error reduction: scaled -> JMP final  (sorted)', 'FontWeight','bold');
    saveas(fig, fullfile(globalFolder,'global_marker_improvement_pct.png')); close(fig);
    fprintf('  Saved: global_marker_improvement_pct.png\n');
end

%% -- PLOT 3: full-state progression (global mean and RMS) -----------------
if makePlots
    globalMean = zeros(nStates,1);
    globalRMS  = zeros(nStates,1);
    for s = 1:nStates
        allE = [];
        for m = 1:nM
            [~,idx] = ismember(commonM(m), string(stateData{s}.labels(2:end)));
            allE = [allE; stateData{s}.data(:, idx+1)]; %#ok<AGROW>
        end
        globalMean(s) = mean(allE,'omitnan') * 1000;
        globalRMS(s)  = sqrt(mean(allE.^2,'omitnan')) * 1000;
    end

    fig = figure('Visible','off','Color','w','Position',[50 50 900 460]);
    plot(0:nSteps, globalRMS,  'o-','LineWidth',2,'Color',[0.85 0.2 0.2],'MarkerSize',8,'DisplayName','Global RMS');
    hold on;
    plot(0:nSteps, globalMean, 's--','LineWidth',1.5,'Color',[0.2 0.5 0.85],'MarkerSize',8,'DisplayName','Global Mean');
    grid on; box off;
    xticks(0:nSteps); xticklabels(stateLabels);
    xtickangle(25);
    ylabel('Marker error [mm]');
    title('Global marker error progression through JMP (all 25 markers)', 'FontWeight','bold');
    legend('Location','northeast');
    for s = 1:nStates
        text(s-1, globalRMS(s)+0.2, sprintf('%.2f', globalRMS(s)), ...
            'HorizontalAlignment','center','FontSize',9,'Color',[0.85 0.2 0.2]);
    end
    saveas(fig, fullfile(globalFolder,'global_step_progression.png')); close(fig);
    fprintf('  Saved: global_step_progression.png\n');
end

%% -- PLOT 4: Waterfall — each step's contribution per marker --------------
if makePlots
    % deltaRMS per step: positive = improvement
    delta = zeros(nSteps, nM);
    for st = 1:nSteps
        delta(st,:) = RMS(st,:) - RMS(st+1,:);
    end

    fig = figure('Visible','off','Color','w','Position',[50 50 1600 580]);
    bh  = bar(delta', 'stacked');
    stepColors = makeStateColormap(nSteps + 1);
    stepColors = stepColors(2:end,:);  % skip the "scaled" grey, one color per step
    for st = 1:nSteps
        bh(st).FaceColor = stepColors(st,:);
    end
    hold on;
    yline(0,'k-','LineWidth',1);
    grid on; box off;
    xticks(1:nM);
    xticklabels(strrep(cellstr(commonM),'_','\_'));
    xtickangle(40);
    ylabel('\DeltaRMS [mm]  (positive = improvement)');
    title('Per-step contribution to error reduction per marker', 'FontWeight','bold');
    legend(arrayfun(@(k) sprintf('Step %d', k), 1:nSteps, 'UniformOutput', false), 'Location','northeast');
    saveas(fig, fullfile(globalFolder,'global_waterfall.png')); close(fig);
    fprintf('  Saved: global_waterfall.png\n');
end

%% -- PLOT 5: Radar / spider chart  (scaled vs final) ---------------------
if makePlots && nM >= 3
    % Normalise by initial value so all markers are on 0-1 scale.
    % BUG FIX vs v6: uses RMS(end,:) (the true final state), not a
    % hardcoded intermediate index.
    scaled_norm = ones(1, nM);   % = 1 (100%)
    final_norm  = RMS(end,:) ./ RMS(1,:);  % fraction remaining

    angles = linspace(0, 2*pi, nM+1);

    rScaled = [scaled_norm, scaled_norm(1)];
    rFinal  = [final_norm,  final_norm(1)];

    fig = figure('Visible','off','Color','w','Position',[50 50 800 800]);
    axes('Position',[0.1 0.1 0.8 0.8]);
    hold on; axis equal; axis off;

    for r = [0.25 0.5 0.75 1.0]
        plot(r*cos(linspace(0,2*pi,200)), r*sin(linspace(0,2*pi,200)), ...
            '-','Color',[0.8 0.8 0.8],'LineWidth',0.8);
        text(0, r+0.04, sprintf('%.0f%%',r*100), ...
            'HorizontalAlignment','center','FontSize',7,'Color',[0.5 0.5 0.5]);
    end
    for k = 1:nM
        plot([0 cos(angles(k))],[0 sin(angles(k))],'-','Color',[0.85 0.85 0.85]);
        text(1.15*cos(angles(k)), 1.15*sin(angles(k)), ...
            strrep(char(commonM(k)),'_','\_'), ...
            'HorizontalAlignment','center','FontSize',7);
    end

    fill(rScaled.*cos(angles), rScaled.*sin(angles), [0.6 0.6 0.6], ...
        'FaceAlpha',0.25,'EdgeColor',[0.4 0.4 0.4],'LineWidth',2,'DisplayName','Scaled');
    fill(rFinal.*cos(angles),  rFinal.*sin(angles),  [0.9 0.3 0.2], ...
        'FaceAlpha',0.25,'EdgeColor',[0.9 0.3 0.2],'LineWidth',2,'DisplayName','JMP final');

    legend({'Scaled','JMP final'},'Location','southoutside','Orientation','horizontal');
    title('Normalised marker error: scaled (grey) vs JMP final (red)', 'FontWeight','bold');
    saveas(fig, fullfile(globalFolder,'global_radar_chart.png')); close(fig);
    fprintf('  Saved: global_radar_chart.png\n');
end

%% -- PLOT 6: Time-series overlay for worst 6 markers ----------------------
if makePlots
    [~, worst6] = sort(RMS(1,:), 'descend');
    worst6 = worst6(1:min(6,nM));

    E0_all = stateData{1}.data;
    EF_all = stateData{end}.data;
    time0  = stateData{1}.time;

    [~,idxW0] = ismember(commonM(worst6), string(stateData{1}.labels(2:end)));
    [~,idxWF] = ismember(commonM(worst6), string(stateData{end}.labels(2:end)));

    fig = figure('Visible','off','Color','w','Position',[50 50 1300 800]);
    for k = 1:numel(worst6)
        subplot(3, 2, k);
        plot(time0, E0_all(:, idxW0(k)+1)*1000, '-', 'Color',[0.5 0.5 0.5], 'LineWidth',1);
        hold on; grid on;
        plot(time0, EF_all(:, idxWF(k)+1)*1000, '-', 'Color',[0.85 0.2 0.2], 'LineWidth',1.5);
        mn = commonM(worst6(k));
        title(strrep(char(mn),'_','\_'), 'FontWeight','bold');
        xlabel('Time [s]'); ylabel('Error [mm]');
        legend({'Scaled','JMP final'}, 'Location','best');
        yline(5,'--k');
    end
    sgtitle('6 highest-error markers: scaled vs JMP final', 'FontWeight','bold');
    saveas(fig, fullfile(globalFolder,'global_worst6_timeseries.png')); close(fig);
    fprintf('  Saved: global_worst6_timeseries.png\n');
end

%% -- PLOT 7: All-marker time series (scaled vs final) — one page per marker -
if makePlots
    E0_all = stateData{1}.data;
    EF_all = stateData{end}.data;
    time0  = stateData{1}.time;
    [~,idx0] = ismember(commonM, string(stateData{1}.labels(2:end)));
    [~,idxF] = ismember(commonM, string(stateData{end}.labels(2:end)));

    for mk = 1:nM
        fig = figure('Visible','off','Color','w','Position',[50 50 900 400]);
        % BUG FIX: idx0(mk)/idxF(mk) are 1-based positions WITHIN the
        % marker-only label list (labels(2:end)), but E0_all/EF_all
        % (stateData{*}.data) have TIME as column 1, so the real data
        % column is idx+1. Without the +1, marker 1 (R_Asis) plotted
        % the time column itself (hence the straight ramp from 0.45 to
        % 2.05 s shown as "error", RMS = 1333.60 mm = RMS of time*1000),
        % and every other marker silently showed the PREVIOUS marker's
        % data shifted by one position.
        y0 = E0_all(:, idx0(mk)+1) * 1000;
        yF = EF_all(:, idxF(mk)+1) * 1000;
        rms0 = sqrt(mean(y0.^2));
        rmsF = sqrt(mean(yF.^2));
        improv = 100*(rms0-rmsF)/rms0;

        plot(time0, y0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.2, ...
            'DisplayName', sprintf('Scaled  (RMS = %.2f mm)', rms0));
        hold on; grid on;
        plot(time0, yF, '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.8, ...
            'DisplayName', sprintf('JMP final  (RMS = %.2f mm)', rmsF));

        yline(5, '--k', 'LineWidth', 0.8, 'Label', '5 mm threshold', ...
            'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');

        xlabel('Time [s]', 'FontSize', 11);
        ylabel('Marker error [mm]', 'FontSize', 11);
        mname = strrep(char(commonM(mk)), '_', '\_');
        title(sprintf('%s  —  improvement: %.1f%%', mname, improv), ...
            'FontWeight', 'bold', 'FontSize', 12);
        legend('Location', 'northeast', 'FontSize', 10);

        fname = sprintf('global_allmarkers_%02d_%s.png', mk, char(commonM(mk)));
        saveas(fig, fullfile(globalFolder, fname)); close(fig);
    end
    fprintf('  Saved: global_allmarkers_01_%s.png ... (all %d markers)\n', ...
        char(commonM(1)), nM);
end

%% -- CSV: global summary table --------------------------------------------
rows = {};
for m = 1:nM
    improv_mm  = RMS(1,m) - RMS(end,m);
    improv_pct = 100 * improv_mm / RMS(1,m);
    rowData = num2cell(RMS(:,m)');  % one column per state
    rows(end+1,:) = [{char(commonM(m))}, rowData, {improv_mm, improv_pct}]; %#ok<AGROW>
end

stateVarNames = [{'Marker'}, ...
    arrayfun(@(k) sprintf('RMS_State%02d_mm', k-1), 1:nStates, 'UniformOutput', false), ...
    {'Improvement_mm','Improvement_pct'}];

T = cell2table(rows, 'VariableNames', stateVarNames);

csvPath = fullfile(globalFolder, 'global_summary_table.csv');
writetable(T, csvPath);
fprintf('  Saved: global_summary_table.csv  (states: %s)\n', strjoin(stateLabels, ' | '));

% Also print to console
fprintf('\n');
headerFmt = ['%-22s' repmat('  %8s', 1, nStates) '  %8s  %8s\n'];
stateHdrs = arrayfun(@(k) sprintf('S%d', k-1), 1:nStates, 'UniformOutput', false);
fprintf(headerFmt, 'Marker', stateHdrs{:}, 'D(mm)', 'D(%)');
fprintf('%s\n', repmat('-', 1, 24 + 10*nStates + 20));
for r = 1:height(T)
    rowVals = table2array(T(r, 2:1+nStates));
    fprintf('%-22s', T.Marker{r});
    fprintf('  %8.2f', rowVals);
    fprintf('  %8.2f  %7.1f%%\n', T.Improvement_mm(r), T.Improvement_pct(r));
end
fprintf('%s\n', repmat('-', 1, 24 + 10*nStates + 20));
rmsAtState = sqrt(mean(RMS.^2, 2));  % global RMS at each state
fprintf('%-22s', 'GLOBAL RMS');
fprintf('  %8.2f', rmsAtState);
fprintf('  %8.2f  %7.1f%%\n', rmsAtState(1)-rmsAtState(end), 100*(rmsAtState(1)-rmsAtState(end))/rmsAtState(1));

fprintf('\nAll outputs saved to:\n  %s\n  %s\n', analysisFolder, globalFolder);

%% =========================================================================
%% LOCAL FUNCTION: state colormap (grey -> blue -> green -> orange -> red)
%% =========================================================================

function colors = makeStateColormap(n)
    % Interpolates n colors across a fixed grey->blue->green->orange->red
    % anchor ramp, so any number of states gets a sensible, consistent
    % progression instead of a hardcoded fixed-size color matrix.
    anchors = [0.6 0.6 0.6;   % grey   (scaled / start)
               0.3 0.6 1.0;   % blue
               0.3 0.9 0.5;   % green
               0.95 0.7 0.2;  % orange
               0.9 0.3 0.3];  % red    (final)
    if n <= 1
        colors = anchors(1,:);
        return;
    end
    xAnchor = linspace(0, 1, size(anchors,1));
    xQuery  = linspace(0, 1, n);
    colors = zeros(n,3);
    for c = 1:3
        colors(:,c) = interp1(xAnchor, anchors(:,c), xQuery, 'linear');
    end
end

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================

function step = readJMPSettingsXML(xmlFile, defaultMarkerNames, baseFolder)
    txt = fileread(xmlFile);
    inDir = getTag(txt,'input_directory');
    if isempty(inDir) || strcmp(strtrim(inDir),'.')
        base = baseFolder;
    elseif isAbsPath(inDir), base = inDir;
    else, base = fullfile(baseFolder, inDir); end

    mnTxt = getTag(txt,'marker_names');
    if isempty(mnTxt), mn = defaultMarkerNames;
    else, mn = regexp(strtrim(mnTxt),'\s+','split'); end

    trTxt = getTag(txt,'time_range');
    tr    = str2double(regexp(strtrim(trTxt),'\s+','split'));
    if numel(tr)~=2||any(isnan(tr)), error('Bad time_range in %s',xmlFile); end

    step.inputModelFile  = resolvePath(getTag(txt,'input_model_file'),  base);
    step.outputModelFile = resolvePath(getTag(txt,'output_model_file'), base);
    step.trcFile         = resolvePath(getTag(txt,'marker_file_name'),  base);
    step.markerNames     = mn;
    step.timeRange       = tr;
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

function generateMarkerErrorSTOPair(iniModel, finModel, trcFile, markers, tr, ...
        iniSto, finSto, outFolder, prefix, acc, wt)
    iniIK = fullfile(outFolder, [prefix '_initialModel_IK.mot']);
    finIK = fullfile(outFolder, [prefix '_finalModel_IK.mot']);
    fprintf('    IK initial...\n');
    runIKForErrors(iniModel, trcFile, iniIK, markers, tr, acc, wt);
    computeMarkerErrorSTO(iniModel, trcFile, iniIK, markers, iniSto);
    fprintf('    IK final...\n');
    runIKForErrors(finModel, trcFile, finIK, markers, tr, acc, wt);
    computeMarkerErrorSTO(finModel, trcFile, finIK, markers, finSto);
end

function runIKForErrors(modelFile, trcFile, outMot, markers, tr, acc, wt)
    import org.opensim.modeling.*
    ik = InverseKinematicsTool();
    ik.set_model_file(modelFile);
    ik.set_marker_file(trcFile);
    ik.set_output_motion_file(outMot);
    ik.setStartTime(tr(1)); ik.setEndTime(tr(2));
    ik.set_accuracy(acc);
    ts = IKTaskSet();
    for i = 1:numel(markers)
        t = IKMarkerTask(); t.setName(markers{i});
        t.setApply(true); t.setWeight(wt);
        ts.cloneAndAppend(t);
    end
    ik.set_IKTaskSet(ts);
    ik.run();
    if ~exist(outMot,'file'), error('IK did not create:\n%s', outMot); end
end

function computeMarkerErrorSTO(modelFile, trcFile, ikMot, markers, stoFile)
    import org.opensim.modeling.*
    model = Model(modelFile); state = model.initSystem();
    cs = model.getCoordinateSet(); ms = model.getMarkerSet();
    trc = readTRCLocal(trcFile); mot = readOpenSimStorageLocal(ikMot);
    if strcmpi(trc.units,'mm')
        for f = fieldnames(trc.coords)'
            trc.coords.(f{1}) = trc.coords.(f{1}) / 1000;
        end
    end
    valid = {};
    for i = 1:numel(markers)
        tf = matlab.lang.makeValidName(markers{i});
        hasT = isfield(trc.coords, tf);
        try, ms.get(markers{i}); hasM=true; catch, hasM=false; end
        if hasT && hasM, valid{end+1} = markers{i}; end %#ok<AGROW>
    end
    if isempty(valid), error('No valid markers.'); end
    nF = numel(mot.time);
    errs = nan(nF, numel(valid));
    inDeg = detectInDegrees(mot.headerLines);
    labs  = mot.labels(2:end);
    for f = 1:nF
        for c = 1:numel(labs)
            try, coord = cs.get(labs{c}); catch, continue; end
            val = mot.data(f, c+1);
            if inDeg && isRotCoord(coord, labs{c}), val = deg2rad(val); end
            coord.setValue(state, val);
        end
        model.realizePosition(state);
        for m = 1:numel(valid)
            mPos = getMarkerPos(ms, valid{m}, state);
            tf   = matlab.lang.makeValidName(valid{m});
            ePos = interp1Marker(trc.time, trc.coords.(tf), mot.time(f));
            if all(isfinite(mPos)) && all(isfinite(ePos))
                errs(f,m) = norm(mPos - ePos);
            end
        end
    end
    writeSTO(stoFile, mot.time, valid, errs);
end

function tf = isRotCoord(coord, name)
    if endsWith(name,'_tx')||endsWith(name,'_ty')||endsWith(name,'_tz'), tf=false; return; end
    try, tf=contains(lower(char(coord.getMotionType().toString())),'rotational');
    catch, tf=true; end
end

function xyz = getMarkerPos(ms, name, state)
    mk = ms.get(name);
    try, p=mk.getLocationInGround(state);
    catch, fr=mk.getParentFrame(); p=fr.findStationLocationInGround(state,mk.get_location()); end
    xyz = [p.get(0), p.get(1), p.get(2)];
end

function out = interp1Marker(t, xyz, tq)
    out = nan(1,3);
    for k=1:3
        y=xyz(:,k); v=isfinite(t)&isfinite(y);
        if sum(v)>=2, out(k)=interp1(t(v),y(v),tq,'linear','extrap'); end
    end
end

function writeSTO(path, time, markers, errs)
    fid = fopen(path,'w');
    if fid<0, error('Cannot write:\n%s',path); end
    cl = onCleanup(@()fclose(fid));
    [~,n,e] = fileparts(path);
    fprintf(fid,'%s%s\nversion=1\nnRows=%d\nnColumns=%d\ninDegrees=no\nendheader\n', ...
        n,e,numel(time),numel(markers)+1);
    fprintf(fid,'%s\n',strjoin([{'time'}, markers(:)'],'\t'));
    % FIX: previous version had N+2 format specs but only N+1 values,
    % so MATLAB silently dropped the \n -> all 161 rows ended up on one line.
    % Now we write each row explicitly with a guaranteed newline.
    for r = 1:numel(time)
        fprintf(fid, '%.8f', time(r));
        fprintf(fid, '\t%.8f', errs(r, :));
        fprintf(fid, '\n');
    end
end

function trc = readTRCLocal(f)
    lines = readlines(f); lines = strip(lines,'right');
    hdr = strsplit(char(lines(2)),sprintf('\t'),'CollapseDelimiters',false);
    vals= strsplit(char(lines(3)),sprintf('\t'),'CollapseDelimiters',false);
    units='mm'; iu=find(strcmpi(hdr,'Units'),1);
    if ~isempty(iu)&&iu<=numel(vals), units=strtrim(vals{iu}); end
    pts = strsplit(char(lines(4)),sprintf('\t'),'CollapseDelimiters',false);
    mns={}; i=3;
    while i<=numel(pts), nm=strtrim(pts{i}); if ~isempty(nm), mns{end+1}=nm; end; i=i+3; end %#ok<AGROW>
    dl=lines(6:end); dl=dl(strlength(strtrim(dl))>0); nr=numel(dl);
    nc=2+3*numel(mns); data=nan(nr,nc);
    for r=1:nr
        v=strsplit(char(dl(r)),sprintf('\t'),'CollapseDelimiters',false);
        for c=1:min(numel(v),nc), data(r,c)=str2double(v{c}); end
    end
    trc.units=units; trc.markerNames=mns; trc.time=data(:,2); trc.coords=struct();
    for m=1:numel(mns), c0=3+(m-1)*3;
        trc.coords.(matlab.lang.makeValidName(mns{m}))=data(:,c0:c0+2); end
end

function S = readOpenSimStorageLocal(f)
    txt=fileread(f); lines=regexp(txt,'\r\n|\n|\r','split');
    ei=find(strcmp(strtrim(lines),'endheader'),1);
    if isempty(ei), error('No endheader in %s',f); end
    ll=strtrim(lines{ei+1});
    if contains(ll,sprintf('\t')), labs=strsplit(ll,sprintf('\t'),'CollapseDelimiters',false);
    else, labs=regexp(ll,'\s+','split'); end
    dl=lines(ei+2:end); dl=dl(~cellfun(@isempty,strtrim(dl)));
    data=nan(numel(dl),numel(labs));
    for r=1:numel(dl)
        row=strtrim(dl{r});
        if contains(row,sprintf('\t')), pts=strsplit(row,sprintf('\t'),'CollapseDelimiters',false);
        else, pts=regexp(row,'\s+','split'); end
        for c=1:min(numel(pts),numel(labs)), data(r,c)=str2double(pts{c}); end
    end
    S.headerLines=lines(1:ei); S.labels=labs; S.data=data; S.time=data(:,1);
end

function v = detectInDegrees(hdr)
    v=false;
    for i=1:numel(hdr)
        l=lower(strtrim(hdr{i}));
        if contains(l,'indegrees=yes'), v=true; return;
        elseif contains(l,'indegrees=no'), v=false; return; end
    end
end

function plotAndSummarizeSteps(pairs, names, folder, doPlot, maxPP)
    gRows={}; mRows={};
    for i=1:size(pairs,1)
        ini=pairs{i,1}; fin=pairs{i,2};
        if isempty(ini)||isempty(fin)||~exist(ini,'file')||~exist(fin,'file'), continue; end
        I=readOpenSimStorageLocal(ini); F=readOpenSimStorageLocal(fin);
        [cm,iI,iF]=intersect(string(I.labels(2:end)),string(F.labels(2:end)),'stable');
        Ei=I.data(:,iI+1); Ef=F.data(:,iF+1);
        n=min(size(Ei,1),size(Ef,1)); Ei=Ei(1:n,:); Ef=Ef(1:n,:); t=I.time(1:n);
        gRows(end+1,:)={i,names{i},...
            mean(Ei(:),'omitnan')*1e3, mean(Ef(:),'omitnan')*1e3, (mean(Ef(:),'omitnan')-mean(Ei(:),'omitnan'))*1e3,...
            sqrt(mean(Ei(:).^2,'omitnan'))*1e3, sqrt(mean(Ef(:).^2,'omitnan'))*1e3, (sqrt(mean(Ef(:).^2,'omitnan'))-sqrt(mean(Ei(:).^2,'omitnan')))*1e3,...
            nanmax(Ei(:))*1e3, nanmax(Ef(:))*1e3, ini, fin};
        for m=1:numel(cm)
            yi=Ei(:,m); yf=Ef(:,m);
            mRows(end+1,:)={i,names{i},char(cm(m)),...
                mean(yi,'omitnan')*1e3, mean(yf,'omitnan')*1e3, (mean(yf,'omitnan')-mean(yi,'omitnan'))*1e3,...
                sqrt(mean(yi.^2,'omitnan'))*1e3, sqrt(mean(yf.^2,'omitnan'))*1e3, (sqrt(mean(yf.^2,'omitnan'))-sqrt(mean(yi.^2,'omitnan')))*1e3,...
                nanmax(yi)*1e3, nanmax(yf)*1e3};
        end
        if doPlot
            try, plotStepTimeSeries(t,Ei,Ef,cm,folder,i,maxPP); catch ME, warning(ME.message); end
            try, plotBarChange(cm, (mean(Ef,1,'omitnan')-mean(Ei,1,'omitnan'))*1e3,...
                fullfile(folder,sprintf('step_%02d_marker_mean_error_changes.png',i)),...
                sprintf('Step %d mean error change',i)); catch ME, warning(ME.message); end
        end
    end
    if ~isempty(gRows)
        G=cell2table(gRows,'VariableNames',{'Step','StepName','InitialMean_mm','FinalMean_mm','MeanChange_mm','InitialRMS_mm','FinalRMS_mm','RMSChange_mm','InitialMax_mm','FinalMax_mm','InitialErrorFile','FinalErrorFile'});
        writetable(G,fullfile(folder,'JMP_global_step_error_summary.csv')); disp(G);
        if doPlot
            try
                fig=figure('Visible','off','Color','w');
                bar([G.InitialMean_mm, G.FinalMean_mm]); grid on;
                xlabel('JMP step'); ylabel('Mean error [mm]');
                title('Global mean error before/after each step');
                legend({'Initial','Final'},'Location','best');
                saveas(fig,fullfile(folder,'JMP_global_mean_error_summary.png')); close(fig);
            catch; end
        end
    end
    if ~isempty(mRows)
        M=cell2table(mRows,'VariableNames',{'Step','StepName','Marker','InitialMean_mm','FinalMean_mm','MeanChange_mm','InitialRMS_mm','FinalRMS_mm','RMSChange_mm','InitialMax_mm','FinalMax_mm'});
        writetable(M,fullfile(folder,'JMP_marker_error_summary.csv'));
    end
end

function plotStepTimeSeries(t,Ei,Ef,cm,folder,step,maxPP)
    nM=numel(cm); nP=ceil(nM/maxPP);
    for pg=1:nP
        i1=(pg-1)*maxPP+1; i2=min(pg*maxPP,nM); idx=i1:i2;
        fig=figure('Visible','off','Color','w','Position',[100 100 1200 800]);
        for k=1:numel(idx)
            m=idx(k); subplot(ceil(numel(idx)/2),2,k);
            plot(t,Ei(:,m)*1e3,'LineWidth',1); hold on; grid on;
            plot(t,Ef(:,m)*1e3,'LineWidth',1.2);
            title(strrep(char(cm(m)),'_','\_')); xlabel('t [s]'); ylabel('mm');
            legend({'Initial','Final'},'Location','best');
        end
        sgtitle(sprintf('Step %d marker errors - page %d',step,pg));
        saveas(fig,fullfile(folder,sprintf('step_%02d_marker_errors_page_%02d.png',step,pg))); close(fig);
    end
end

function plotBarChange(markers, values, outFile, ttl)
    fig=figure('Visible','off','Color','w','Position',[100 100 1200 500]);
    bar(values); grid on; yline(0,'k--');
    xticks(1:numel(markers)); xticklabels(strrep(cellstr(markers),'_','\_'));
    xtickangle(45); ylabel('Final-Initial mean [mm]'); title(ttl);
    saveas(fig,outFile); close(fig);
end
