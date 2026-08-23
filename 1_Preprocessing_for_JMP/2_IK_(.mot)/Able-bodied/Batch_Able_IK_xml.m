%% Batch_Able_IK_xml (con recorte por eventos de marcha)
% IK para todos los sujetos SANOS (Able-bodied), recortando cada trial a
% la ventana de marcha en estado estacionario (primer -> ultimo heel-strike)
% leida de gait_trim_windows.csv.

import org.opensim.modeling.*

% --- Rutas (ajusta a tu estructura real) ---
carpetaTRC    = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/Able-bodied/';
carpetaSalida = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/Able-bodied_IK_out/';
plantilla     = fullfile(carpetaTRC, 'IK_xml_template.xml');
csvRecorte    = 'C:/Users/lucia/Desktop/TFG/1_Preprocessing_for_JMP/2_IK_(.mot)/gait_trim_windows.csv';

% --- Comprobaciones ---
if ~isfolder(carpetaTRC);  error('No existe: %s', carpetaTRC); end
if ~isfile(plantilla);     error('No existe la plantilla: %s', plantilla); end

% --- Cargar la tabla de recorte (si existe) ---
if isfile(csvRecorte)
    trimTable = readtable(csvRecorte);
    fprintf('Tabla de recorte cargada: %d trials.\n', height(trimTable));
else
    warning('No se encontro %s. Se usara el trial completo para todos.', csvRecorte);
    trimTable = [];
end

% --- Descubrir sujetos ---
listadoSujetos = dir(carpetaTRC);
sujetoDirs = listadoSujetos([listadoSujetos.isdir] & ~ismember({listadoSujetos.name}, {'.', '..'}));
fprintf('Detectados %d sujetos en %s\n', numel(sujetoDirs), carpetaTRC);

for i = 1:numel(sujetoDirs)
    sujetoID      = sujetoDirs(i).name;
    carpetaSujeto = fullfile(carpetaTRC, sujetoID);

    modelFile = fullfile(carpetaSujeto, [sujetoID '_scaled.osim']);
    if ~isfile(modelFile)
        warning('Sin modelo escalado para %s, se omite.', sujetoID);
        continue
    end

    listadoWalks = dir(carpetaSujeto);
    walkDirs = listadoWalks([listadoWalks.isdir] & ...
        ~ismember({listadoWalks.name}, {'.', '..', 'Geometry'}));

    for w = 1:numel(walkDirs)
        trialLabel  = walkDirs(w).name;
        carpetaWalk = fullfile(carpetaSujeto, trialLabel);
        salidaWalk  = fullfile(carpetaSalida, sujetoID, trialLabel);

        trcFiles = dir(fullfile(carpetaWalk, '*.trc'));
        if isempty(trcFiles)
            warning('Sin .trc en %s, se omite.', carpetaWalk);
            continue
        end
        trcFile = fullfile(carpetaWalk, trcFiles(1).name);

        try
            generarIKSetup(plantilla, sujetoID, trialLabel, trcFile, ...
                modelFile, salidaWalk, trimTable);
        catch ME
            fprintf(2, 'FALLO en %s/%s: %s\n', sujetoID, trialLabel, ME.message);
        end
    end
end
