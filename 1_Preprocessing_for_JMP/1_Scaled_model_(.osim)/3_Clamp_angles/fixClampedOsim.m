function fixClampedOsim(osimFile, outputFile)
% FIXCLAMPEDOSIM  Forces <clamped>true</clamped> on key lower-limb joint
%   coordinates that came with clamped=false (inherited from the generic
%   RCNL2025.osim model), so that IK cannot produce non-physiological
%   joint angles (like the -102 degree ankle_angle seen in SUBJ11).
%
%   The XML is edited as TEXT (not via the API), for the same reason as
%   in generarIKSetup: it avoids depending on uncertain method names
%   across OpenSim versions, and the result is easy to verify by eye.
%
%   Pelvis coordinates (pelvis_tx, pelvis_tilt, etc.) are NOT touched,
%   nor are coordinates already set to locked=true (mtp_angle, pro_sup)
%   - those should remain as they are.
%
% Arguments:
%   osimFile    - path to the .osim file to fix (e.g. 'SUBJ11_scaled.osim')
%   outputFile  - output path (optional). If omitted, overwrites the
%                 original, saving a .bak copy first
%
% Example:
%   fixClampedOsim('SUBJ11_scaled.osim')                   % overwrite (with backup)
%   fixClampedOsim('SUBJ11_scaled.osim', 'SUBJ11_fix.osim') % new file

    if nargin < 2 || isempty(outputFile)
        outputFile = osimFile;
        makeBackup = true;
    else
        makeBackup = false;
    end

    if ~isfile(osimFile)
        error('File does not exist: %s', osimFile);
    end

    % --- Lower-limb joint coordinates to fix ---
    % Add more names here if you find other coordinates with the same issue.
    coordsToFix = {
        'hip_flexion_r','hip_adduction_r','hip_rotation_r', ...
        'hip_flexion_l','hip_adduction_l','hip_rotation_l', ...
        'ankle_angle_r','ankle_angle_l', ...
        'subtalar_angle_r','subtalar_angle_l'
    };

    txt = fileread(osimFile);
    nChanges = 0;

    for i = 1:numel(coordsToFix)
        name = coordsToFix{i};
        pattern = sprintf('(?s)(<Coordinate name="%s">.*?)<clamped>false</clamped>(.*?</Coordinate>)', name);
        [txt, count] = regexprep_count(txt, pattern, '$1<clamped>true</clamped>$2');
        if count > 0
            fprintf('  %s: clamped false -> true\n', name);
            nChanges = nChanges + count;
        else
            fprintf('  %s: no change (not found, or already true)\n', name);
        end
    end

    if nChanges == 0
        warning('No changes were made. Check that the coordinate names match those in your model.');
        return
    end

    if makeBackup
        [~, name, ext] = fileparts(osimFile);
        backupFile = fullfile(fileparts(osimFile), [name '_original_backup' ext]);
        if ~isfile(backupFile)
            copyfile(osimFile, backupFile);
            fprintf('Backup copy saved to: %s\n', backupFile);
        end
    end

    fid = fopen(outputFile, 'w');
    fwrite(fid, txt);
    fclose(fid);

    fprintf('\nTotal coordinates fixed: %d\n', nChanges);
    fprintf('Fixed model saved to: %s\n', outputFile);
end

function [txt, count] = regexprep_count(txt, pattern, replacement)
    % Same as regexprep, but also returns how many times it was applied
    tokens = regexp(txt, pattern, 'once');
    count = ~isempty(tokens);
    txt = regexprep(txt, pattern, replacement, 'once');
end
