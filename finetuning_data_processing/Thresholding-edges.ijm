run("Close All");

// User selects the parent directory containing the Edge Measurements folder
parent_dir = getDirectory("Choose the parent directory containing Edge Measurements folder");
edge_measurement_dir = parent_dir + "Edge Measurements/";

if (!File.exists(edge_measurement_dir)) {
    exit("Error: Edge Measurements folder not found in " + parent_dir);
}

// Create threshold analysis directory
threshold_dir = parent_dir + "Threshold Analysis/";
File.makeDirectory(threshold_dir);

// Get all image paths from all subfolders
all_image_paths = getAllImagePaths(edge_measurement_dir);
total_images = all_image_paths.length;
sample_size = Math.ceil(total_images * 0.1); // 10% of total images

// Randomly select images
selected_images = randomlySelectImages(all_image_paths, sample_size);

// Create arrays for threshold values and results
threshold_values = newArray(18); // From 5 to 120 in steps of 5
for (i = 0; i < threshold_values.length; i++) {
    threshold_values[i] = 0 + (i * 5);
}

// Process each selected image with different thresholds
for (img_idx = 0; img_idx < selected_images.length; img_idx++) {
    showProgress(img_idx + 1, selected_images.length);
    current_image = selected_images[img_idx];
    image_name = File.getName(current_image);
    base_name = File.nameWithoutExtension;
    
    // Create directory for this image
    image_dir = threshold_dir + base_name + "/";
    File.makeDirectory(image_dir);
    
    // Open the image
    open(current_image);
    original = getTitle();
    
    // Convert to 8-bit if not already
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Process each threshold value
    for (t = 0; t < threshold_values.length; t++) {
        thresh = threshold_values[t];
        
        // Create directory for this threshold if it doesn't exist
        thresh_dir = image_dir + "threshold_" + thresh + "/";
        File.makeDirectory(thresh_dir);
        
        // Duplicate image for this threshold
        selectWindow(original);
        run("Duplicate...", "title=thresh_" + thresh);
        
        // Apply threshold
        setThreshold(thresh, 255);
        run("Convert to Mask");
        
        // Save thresholded image
        saveAs("jpg", thresh_dir + "threshold_" + thresh + "_" + base_name);
        
        // Analyze particles
        run("Set Measurements...", "area bounding redirect=None decimal=3");
        run("Analyze Particles...", "show=Masks display exclude include summarize");
        
        // Save particle mask
        saveAs("jpg", thresh_dir + "particles_" + thresh + "_" + base_name);
        
        // Save results for this threshold
        if (nResults > 0) {
            Table.save(thresh_dir + "particles_" + thresh + "_results.csv", "Results");
            Table.save(thresh_dir + "particles_" + thresh + "_summary.csv", "Summary");
        }
        
        // Clear results for next threshold
        run("Clear Results");
        run("Close All");
        
        // Reopen original for next threshold
        open(current_image);
        run("8-bit");
        run("Set Scale...", "distance=240 known=50 unit=micron");
    }
    run("Close All");
}

// Create summary of all analyses
generateAnalysisSummary(threshold_dir, threshold_values);

function getAllImagePaths(dir) {
    list = getFileList(dir);
    image_paths = newArray(0);
    
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "Bef_")) {
            current_dir = dir + list[i];
            crop_dir = current_dir + "Processed Images/Crop/";
            
            if (File.exists(crop_dir)) {
                crop_files = getFileList(crop_dir);
                for (j = 0; j < crop_files.length; j++) {
                    if (endsWith(crop_files[j], ".jpg") || endsWith(crop_files[j], ".tif")) {
                        image_paths = Array.concat(image_paths, crop_dir + crop_files[j]);
                    }
                }
            }
        }
    }
    return image_paths;
}

function randomlySelectImages(image_paths, sample_size) {
    // Create array for selected images
    selected = newArray(sample_size);
    total = image_paths.length;
    
    // Create array of indices and shuffle it
    indices = newArray(total);
    for (i = 0; i < total; i++) {
        indices[i] = i;
    }
    
    // Fisher-Yates shuffle
    for (i = total-1; i > 0; i--) {
        j = floor(random * (i + 1));
        temp = indices[i];
        indices[i] = indices[j];
        indices[j] = temp;
    }
    
    // Take first sample_size elements
    for (i = 0; i < sample_size; i++) {
        selected[i] = image_paths[indices[i]];
    }
    
    return selected;
}

function generateAnalysisSummary(threshold_dir, threshold_values) {
    // Create summary file
    f = File.open(threshold_dir + "threshold_analysis_summary.csv");
    print(f, "Image,Threshold,ParticleCount,TotalArea,AverageSize");
    
    // Get list of all image directories
    image_dirs = getFileList(threshold_dir);
    
    // Process each image directory
    for (i = 0; i < image_dirs.length; i++) {
        if (endsWith(image_dirs[i], "/")) {
            image_name = substring(image_dirs[i], 0, lengthOf(image_dirs[i])-1);
            
            // Process each threshold for this image
            for (t = 0; t < threshold_values.length; t++) {
                thresh = threshold_values[t];
                results_path = threshold_dir + image_dirs[i] + "threshold_" + thresh + "/particles_" + thresh + "_summary.csv";
                
                if (File.exists(results_path)) {
                    // Read and process summary file
                    lines = split(File.openAsString(results_path), "\n");
                    if (lines.length > 1) {
                        values = split(lines[1], ",");
                        if (values.length >= 3) {
                            count = values[0];
                            total_area = values[1];
                            average_size = values[2];
                            print(f, image_name + "," + thresh + "," + count + "," + total_area + "," + average_size);
                        }
                    }
                }
            }
        }
    }
    File.close(f);
}
