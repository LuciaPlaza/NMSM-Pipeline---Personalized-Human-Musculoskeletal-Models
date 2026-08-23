%% Batch_Stroke_IK_xml (con recorte por eventos de marcha)
% IK para todos los sujetos STROKE (TVCxx), recortando cada trial a
% la ventana de marcha en estado estacionario (primer -> ultimo heel-strike)
% leida de gait_trim_windows.csv. Misma logica que Batch_Able_IK_xml,
% ya validada en sanos.
%
% Diferencias respecto al de sanos:
%   - Rutas apuntan a Stroke/ en vez de Able-bodied/
%   - Usa la plantilla de Stroke (26 marcadores, incluye R_Psis/L_Psis)
%   - Los sujetos son TVCxx en vez de SUBJxx, y los nombres de .trc no
%     siguen un patron fijo (se buscan por extension, como ya haciamos)

import org.opensim.modeling.*

% --- Rutas (ajusta si difieren de tu estructura real) ---
carpetaTRC    = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/Stroke/';
carpetaSalida = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/Stroke_IK_out/';
plantilla     = fullfile(carpetaTRC, 'IK_xml_template.xml');   % plantilla PROPIA de Stroke (26 marcadores)
csvRecorte    = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/gait_trim_windows.csv';

% --- Comprobaciones tempranas ---
if ~isfolder(carpetaTRC);  error('No existe: %s', carpetaTRC); end
if ~isfile(plantilla);     error('No existe la plantilla: %s', plantilla); end

% --- Cargar la tabla de recorte (comun a sanos y stroke, un unico CSV) ---
if isfile(csvRecorte)
    trimTable = readtable(csvRecorte);
    fprintf('Tabla de recorte cargada: %d trials.\n', height(trimTable));
else
    warning('No se encontro %s. Se usara el trial completo para todos.', csvRecorte);
    trimTable = [];
end

% --- Descubrir sujetos (TVCxx) ---
listadoSujetos = dir(carpetaTRC);
sujetoDirs = listadoSujetos([listadoSujetos.isdir] & ~ismember({listadoSujetos.name}, {'.', '..'}));
fprintf('Detectados %d sujetos en %s\n', numel(sujetoDirs), carpetaTRC);

for i = 1:numel(sujetoDirs)
    sujetoID      = sujetoDirs(i).name;                   % p.ej. 'TVC04'
    carpetaSujeto = fullfile(carpetaTRC, sujetoID);

    modelFile = fullfile(carpetaSujeto, [sujetoID '_scaled.osim']);
    if ~isfile(modelFile)
        warning('Sin modelo escalado para %s, se omite.', sujetoID);
        continue
    end

    listadoWalks = dir(carpetaSujeto);
    walkDirs = listadoWalks([listadoWalks.isdir] & ...
        ~ismember({listadoWalks.name}, {'.', '..', 'Geometry'}));

    if isempty(walkDirs)
        warning('Sin subcarpetas Walk_x en %s, se omite sujeto.', carpetaSujeto);
        continue
    end

    for w = 1:numel(walkDirs)
        trialLabel  = walkDirs(w).name;                    % p.ej. 'Walk_2'
        carpetaWalk = fullfile(carpetaSujeto, trialLabel);
        salidaWalk  = fullfile(carpetaSalida, sujetoID, trialLabel);

        % --- Buscar el .trc por extension (el nombre no sigue un patron fijo) ---
        trcFiles = dir(fullfile(carpetaWalk, '*.trc'));

        if isempty(trcFiles)
            warning('Sin .trc en %s, se omite trial.', carpetaWalk);
            continue
        elseif numel(trcFiles) > 1
            warning('Mas de un .trc en %s, se usa el primero (%s).', carpetaWalk, trcFiles(1).name);
        end

        trcFile = fullfile(carpetaWalk, trcFiles(1).name);

        try
            generarIKSetup(plantilla, sujetoID, trialLabel, trcFile, ...
                modelFile, salidaWalk, trimTable);
        catch ME
            fprintf(2, 'FALLO en %s/%s: %s\n', sujetoID, trialLabel, ME.message);
            if ~isempty(ME.stack)
                fprintf(2, '  -> en archivo: %s (linea %d)\n', ME.stack(1).file, ME.stack(1).line);
            end
        end
    end
end
