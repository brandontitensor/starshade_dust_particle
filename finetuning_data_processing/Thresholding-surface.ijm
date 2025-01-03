run("Close All");

// User selects the directory containing the surface folders
input_dir = getDirectory("Choose the directory containing surface folders");

// Create main output directory with timestamp
output_dir = input_dir + "Surface_Analysis_" + getDateTime() + "/";
File.makeDirectory(output_dir);
File.makeDirectory(output_dir + "Threshold_Analysis/");

// Get list of all folders and collect surface files
folder_list = getFileList(input_dir);
surface_files = newArray(0);
surface_paths = newArray(0);

// Collect all image files from the Surf folders
for (folder_idx = 0; folder_idx < folder_list.length; folder_idx++) {
    if (endsWith(folder_list[folder_idx], "Surf/")) {
        current_folder = input_dir + folder_list[folder_idx];
        file_list = getFileList(current_folder);
        
        for (file_idx = 0; file_idx < file_list.length; file_idx++) {
            if (endsWith(toLowerCase(file_list[file_idx]), ".jpg") || 
                endsWith(toLowerCase(file_list[file_idx]), ".jpeg") || 
                endsWith(toLowerCase(file_list[file_idx]), ".tif") || 
                endsWith(toLowerCase(file_list[file_idx]), ".tiff") || 
                endsWith(toLowerCase(file_list[file_idx]), ".png")) {
                surface_files = Array.concat(surface_files, file_list[file_idx]);
                surface_paths = Array.concat(surface_paths, current_folder + file_list[file_idx]);
            }
        }
    }
}

print("Total files found: " + surface_files.length);

// Calculate number of files for 1% sample
sample_size = Math.ceil(surface_files.length * 0.01);
sampled_indices = randomlySelectIndices(surface_files.length, sample_size);

// Set up analysis parameters
setBatchMode(true);
run("Set Measurements...", "area center perimeter bounding fit shape feret's skewness area_fraction redirect=None decimal=3");

// Create array for threshold values (5 to 120 in steps of 5)
threshold_values = newArray(24);
for (i = 0; i < threshold_values.length; i++) {
    threshold_values[i] = 5 + (i * 5);
}

// Process each selected image
for (i = 0; i < sampled_indices.length; i++) {
    showProgress(i + 1, sampled_indices.length);
    current_idx = sampled_indices[i];
    current_file = surface_files[current_idx];
    current_path = surface_paths[current_idx];
    
    // Get parent folder name
    parent_folder = File.getParent(current_path);
    parent_name = File.getName(parent_folder);
    base_name = getFilenameWithoutExtension(current_file);
    
    print("Processing " + (i+1) + " of " + sampled_indices.length + ": " + parent_name + "/" + current_file);
    
    // Open and prepare original image
    open(current_path);
    original_id = getImageID();
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=microns");
    
    // Process each threshold
    for (t = 0; t < threshold_values.length; t++) {
        thresh = threshold_values[t];
        thresh_dir = output_dir + "Threshold_Analysis/threshold_" + thresh + "/";
        File.makeDirectory(thresh_dir);
        
        // Duplicate image for threshold analysis
        selectImage(original_id);
        run("Duplicate...", "title=thresh_" + thresh);
        
        // Apply threshold and analyze
        setThreshold(thresh, 255);
        run("Convert to Mask");
        
        // Analyze particles and save results
        run("Analyze Particles...", "display clear");
        
        // Save the Results table (particle measurements)
        if (nResults > 0) {
            Table.save(thresh_dir + parent_name + "_" + base_name + ".csv");
        }
        
        // Clean up
        run("Clear Results");
        close(); // Close the thresholded image
    }
    
    // Close original image
    selectImage(original_id);
    close();
}

// Final cleanup
run("Close All");
cleanupWindows();

showMessage("Analysis Complete!\nProcessed " + sampled_indices.length + " files");

function getDateTime() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return "" + year + "_" + (month+1) + "_" + dayOfMonth + "_" + hour + "_" + minute + "_" + second;
}

function randomlySelectIndices(total_size, sample_size) {
    indices = newArray(total_size);
    selected = newArray(sample_size);
    
    // Initialize indices array
    for (i = 0; i < total_size; i++) {
        indices[i] = i;
    }
    
    // Fisher-Yates shuffle
    for (i = total_size-1; i > 0; i--) {
        j = floor(random * (i + 1));
        temp = indices[i];
        indices[i] = indices[j];
        indices[j] = temp;
    }
    
    // Take first sample_size elements
    for (i = 0; i < sample_size; i++) {
        selected[i] = indices[i];
    }
    
    return selected;
}

function cleanupWindows() {
    list = getList("window.titles");
    for (i=0; i<list.length; i++) {
        selectWindow(list[i]);
        run("Close");
    }
}

function getFilenameWithoutExtension(filename) {
    dot_index = lastIndexOf(filename, ".");
    if (dot_index != -1)
        return substring(filename, 0, dot_index);
    return filename;
}