function generarIKSetup(plantillaXML, sujetoID, trialLabel, trcFile, modelFile, carpetaSalida, trimTable)
% GENERARIKSETUP  Genera y ejecuta un IK para un sujeto/trial concreto,
%   usando el modelo YA ESCALADO del sujeto y (opcionalmente) recortando
%   el trial a la ventana de marcha en estado estacionario definida por
%   los eventos de contacto (primer heel-strike -> ultimo heel-strike).
%
%   Los campos time_range, marker_file y output_motion_file se editan
%   como TEXTO sobre la plantilla XML; el IKTaskSet se mantiene intacto.
%
% Argumentos:
%   plantillaXML  - ruta al XML de IK que sirve de plantilla (aporta el IKTaskSet)
%   sujetoID      - p.ej. 'SUBJ11'
%   trialLabel    - p.ej. 'Walk_2' (para nombrar los ficheros de salida)
%   trcFile       - ruta COMPLETA al .trc de ese trial
%   modelFile     - ruta COMPLETA al .osim escalado de ESE sujeto
%   carpetaSalida - carpeta donde escribir el .mot y el .xml resultantes
%   trimTable     - (opcional) tabla leida de gait_trim_windows.csv con
%                   columnas trc_file, tStart_TRC, tEnd_TRC. Si se pasa y
%                   contiene el .trc actual, se recorta a esa ventana.
%                   Si se omite o no hay match, se usa el trial completo.

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

    % --- Rango temporal: por defecto, todo el TRC ---
    trcData = TimeSeriesTableVec3(trcFile);
    % double(...) fuerza conversion a tipo nativo de MATLAB: el valor que
    % devuelve la API de OpenSim funciona con sprintf pero no es compatible
    % con max()/min(), que es mas estricto con los tipos.
    t0 = double(trcData.getIndependentColumn().get(0));
    tf = double(trcData.getIndependentColumn().get(trcData.getNumRows() - 1));
    fuenteTiempo = 'trial completo';

    % --- Si hay tabla de recorte, buscar la ventana de este .trc ---
    if nargin >= 7 && ~isempty(trimTable)
        [~, trcName, trcExt] = fileparts(trcFile);
        trcBaseName = [trcName trcExt];

        % Conversion defensiva: readtable puede importar texto como cell,
        % string o categorical segun la version de MATLAB. cellstr(string(...))
        % normaliza cualquiera de esos tipos a cell array de char, evitando
        % el error "Second input array is an invalid data type" en strcmp.
        trcFileColumn = cellstr(string(trimTable.trc_file));

        idx = find(strcmp(trcFileColumn, trcBaseName), 1);
        if ~isempty(idx)
            % Conversion defensiva: si readtable importo estas columnas
            % como texto (p.ej. por formato regional/decimal al abrir el
            % CSV en Excel), str2double(string(...)) las fuerza a double.
            % Si ya eran double, esto no cambia su valor.
            tStart = str2double(string(trimTable.tStart_TRC(idx)));
            tEnd   = str2double(string(trimTable.tEnd_TRC(idx)));
            if ~isnan(tStart) && ~isnan(tEnd) && tEnd > tStart
                % Asegurar que la ventana cae dentro del TRC real
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

    % --- Editar la plantilla como texto ---
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

    % --- Ejecutar el IK ---
    ikTool = InverseKinematicsTool(setupOut);
    ikTool.setModel(Model(modelFile));
    ikTool.run();

    fprintf('IK completado: %s (t = %.2f - %.2f s, %s)\n', ...
        nombreBase, t0, tf, fuenteTiempo);
end
