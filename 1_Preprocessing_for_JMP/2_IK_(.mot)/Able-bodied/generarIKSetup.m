function generarIKSetup(plantillaXML, sujetoID, trialLabel, trcFile, modelFile, carpetaSalida, trimTable)
% GENERARIKSETUP  Generates and runs IK for a specific subject/trial,
%   using the subject's ALREADY SCALED model and, optionally, trimming
%   the trial to the steady-state gait window defined by contact events
%   (first heel-strike -> last heel-strike).
%
%   The time_range, marker_file, and output_motion_file fields are edited
%   as TEXT in the XML template; the IKTaskSet remains unchanged.
%
% Arguments:
%   plantillaXML  - path to the IK XML file used as a template (provides the IKTaskSet)
%   sujetoID      - e.g. 'SUBJ11'
%   trialLabel    - e.g. 'Walk_2' (used to name the output files)
%   trcFile       - FULL path to the .trc file for that trial
%   modelFile     - FULL path to the scaled .osim model for THAT subject
%   carpetaSalida - folder where the resulting .mot and .xml files are written
%   trimTable     - (optional) table read from gait_trim_windows.csv with
%                   columns trc_file, tStart_TRC, tEnd_TRC. If provided and
%                   it contains the current .trc file, the trial is trimmed
%                   to that window. If omitted or no match is found, the
%                   complete trial is used.

    import org.opensim.modeling.*

    if ~isfile(trcFile)
        warning('No existe el TRC: %s, se omite.', trcFile);
        return
    end
    if ~isfile(modelFile)
        warning('No existe el modelo escalado: %s, se omite %s.', modelFile, sujetoID);
        return
    end
    if ~isfile(plantillaXML)
        warning('No existe la plantilla XML: %s, se omite.', plantillaXML);
        return
    end

    if ~isfolder(carpetaSalida)
        mkdir(carpetaSalida);
    end

    nombreBase = sprintf('%s_%s', sujetoID, trialLabel);
    outMotFile = fullfile(carpetaSalida, [nombreBase '_IK.mot']);
    setupOut   = fullfile(carpetaSalida, [nombreBase '_IK_setup.xml']);

    % --- Time range: by default, the complete TRC ---
    trcData = TimeSeriesTableVec3(trcFile);
    % double(...) forces conversion to a native MATLAB type: the value
    % returned by the OpenSim API works with sprintf but is not compatible
    % with max()/min(), which is stricter about data types.
    t0 = double(trcData.getIndependentColumn().get(0));
    tf = double(trcData.getIndependentColumn().get(trcData.getNumRows() - 1));
    fuenteTiempo = 'trial completo';

    % --- If a trimming table is available, find the window for this .trc file ---
    if nargin >= 7 && ~isempty(trimTable)
        [~, trcName, trcExt] = fileparts(trcFile);
        trcBaseName = [trcName trcExt];

        % Defensive conversion: readtable may import text as cell, string,
        % or categorical depending on the MATLAB version. cellstr(string(...))
        % normalizes any of these types to a cell array of char, preventing
        % the "Second input array is an invalid data type" error in strcmp.
        trcFileColumn = cellstr(string(trimTable.trc_file));

        idx = find(strcmp(trcFileColumn, trcBaseName), 1);
        if ~isempty(idx)
            % Defensive conversion: if readtable imported these columns
            % as text (e.g. because of regional/decimal formatting when the
            % CSV was opened in Excel), str2double(string(...)) forces them
            % to double. If they are already double, their values are unchanged.
            tStart = str2double(string(trimTable.tStart_TRC(idx)));
            tEnd   = str2double(string(trimTable.tEnd_TRC(idx)));
            if ~isnan(tStart) && ~isnan(tEnd) && tEnd > tStart
                % Ensure that the trimming window falls within the actual TRC range
                t0 = max(tStart, t0);
                tf = min(tEnd, tf);
                fuenteTiempo = 'recorte por eventos (HS->HS)';
            else
                warning('Ventana de recorte invalida para %s, se usa trial completo.', trcBaseName);
            end
        else
            warning('Sin entrada de recorte para %s, se usa trial completo.', trcBaseName);
        end
    end

    % --- Edit the template as text ---
    txt = fileread(plantillaXML);
    trcFileFwd    = strrep(trcFile, '\', '/');
    outMotFileFwd = strrep(outMotFile, '\', '/');

    txt = regexprep(txt, '<time_range>.*?</time_range>', ...
        sprintf('<time_range>%.6f %.6f</time_range>', t0, tf));
    txt = regexprep(txt, '<marker_file>.*?</marker_file>', ...
        sprintf('<marker_file>%s</marker_file>', trcFileFwd));
    txt = regexprep(txt, '<output_motion_file>.*?</output_motion_file>', ...
        sprintf('<output_motion_file>%s</output_motion_file>', outMotFileFwd));

    fid = fopen(setupOut, 'w');
    if fid == -1
        error('No se pudo escribir %s', setupOut);
    end
    fwrite(fid, txt);
    fclose(fid);

    % --- Run IK ---
    ikTool = InverseKinematicsTool(setupOut);
    ikTool.setModel(Model(modelFile));
    ikTool.run();

    fprintf('IK completado: %s (t = %.2f - %.2f s, %s)\n', ...
        nombreBase, t0, tf, fuenteTiempo);
end
