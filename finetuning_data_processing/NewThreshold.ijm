run("Close All");

// User selects the parent directory containing the Edge Measurements folder
parent_dir = getDirectory("Choose the parent directory containing Edge Measurements folder");

// Get list of all folders within the Edge Measurements directory
edge_measurement_dir = parent_dir + "Edge Measurements/";
if (!File.exists(edge_measurement_dir)) {
    exit("Error: Edge Measurements folder not found in " + parent_dir);
}

folder_list = getFileList(edge_measurement_dir);

// Process each Bef_## minus Aft_## folder
for (folder_idx = 0; folder_idx < folder_list.length; folder_idx++) {
    if (startsWith(folder_list[folder_idx], "Bef_")) {
        current_folder = edge_measurement_dir + folder_list[folder_idx];
        processFolder(current_folder);
    }
}

function processFolder(measurement_dir) {
    // Get the processed images directory
    processed_dir = measurement_dir + "Processed Images/";
    
    // Check if the Crop folder exists
    if (!File.exists(processed_dir + "Crop/")) {
        print("Error: Crop folder not found in " + processed_dir);
        return;
    }
    
    // Create necessary output directories if they don't exist
    subdirs = newArray("Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", "Finished");
    for (i = 0; i < subdirs.length; i++) {
        if (File.isDirectory(processed_dir + subdirs[i]) == 0) {
            File.makeDirectory(processed_dir + subdirs[i]);
        }
    }
    
    // Get list of images in the Crop folder
    crop_files = getFileList(processed_dir + "Crop/");
    
    // Process each image
    for (i = 0; i < crop_files.length; i++) {
        if (endsWith(crop_files[i], ".jpg") || endsWith(crop_files[i], ".tif")) {
            showProgress(i+1, crop_files.length);
            
            // Open the cropped image
            open(processed_dir + "Crop/" + crop_files[i]);
            file_name = File.nameWithoutExtension;
            
            // Convert to 8-bit
            run("8-bit");
            run("Set Scale...", "distance=240 known=50 unit=micron");
            saveAs("jpg", processed_dir + "Crop8bit/" + file_name);
            
            // Apply threshold
            setThreshold(15, 255);
            run("Convert to Mask");
            saveAs("jpg", processed_dir + "Crop8BitThreshold/" + file_name);
            saveAs("jpg", processed_dir + "Crop8BitThresholdMask/" + file_name);
            
            // Analyze particles
            run("Set Measurements...", "area bounding redirect=None decimal=3");
            run("Analyze Particles...", "show=Masks display exclude include summarize");
            saveAs("jpg", processed_dir + "Finished/" + file_name);
            
            // Close all images
            run("Close All");
        }
    }
    
    // Save results tables
    dir_name = File.getName(measurement_dir);
    Table.save(measurement_dir + "Particles_Reanalysis_" + dir_name + ".csv", "Results");
    Table.save(measurement_dir + "Summary_Reanalysis_" + dir_name + ".csv", "Summary");
    close("Results");
    close("Summary");
}