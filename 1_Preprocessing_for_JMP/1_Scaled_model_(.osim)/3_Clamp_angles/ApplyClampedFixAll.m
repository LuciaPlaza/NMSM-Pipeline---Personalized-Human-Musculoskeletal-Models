%% Apply_Clamped_Fix_All
% Loops through Able-bodied/ and Stroke/ and fixes clamped=true in each
% already-generated <subject>_scaled.osim, saving an automatic backup.

groupFolders = { ...
    'C:\Users\lucia\Desktop\TFG\1_Preprocessing_for_JMP\1_Scaled_model_(.osim)\3_Clamp_angles\Able-bodied'
    'C:\Users\lucia\Desktop\TFG\1_Preprocessing_for_JMP\1_Scaled_model_(.osim)\3_Clamp_angles\Stroke'
};

for g = 1:numel(groupFolders)
    groupFolder = groupFolders{g};
    subjectListing = dir(groupFolder);
    subjectDirs = subjectListing([subjectListing.isdir] & ~ismember({subjectListing.name}, {'.', '..'}));

    for i = 1:numel(subjectDirs)
        subjectID = subjectDirs(i).name;
        modelFile = fullfile(groupFolder, subjectID, [subjectID '_scaled.osim']);

        if ~isfile(modelFile)
            warning('No scaled model found: %s, skipping.', modelFile);
            continue
        end

        fprintf('\n=== %s ===\n', subjectID);
        try
            fixClampedOsim(modelFile);   % overwrites with automatic backup
        catch ME
            fprintf(2, 'FAILED on %s: %s\n', subjectID, ME.message);
        end
    end
end
