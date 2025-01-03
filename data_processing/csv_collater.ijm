// Clear any existing results
run("Clear Results");

// Get the parent directory containing the Threshold Analysis folder
parent_dir = getDirectory("Choose the directory containing the Threshold Analysis folder");
threshold_dir = parent_dir + "Threshold Analysis/";

if (!File.exists(threshold_dir)) {
    exit("Error: Threshold Analysis folder not found in " + parent_dir);
}

// Create output file
output_file = parent_dir + "combined_particle_analysis.csv";
f = File.open(output_file);

// Write header (assuming standard particle analysis measurements)
// Modify these column names if your particle analysis includes different measurements
print(f, "Image,Threshold,Particle_ID,Area,BX,BY,Width,Height");

// Get list of all image directories
image_dirs = getFileList(threshold_dir);
particle_count = 0;

// Process each image directory
for (i = 0; i < image_dirs.length; i++) {
    if (endsWith(image_dirs[i], "/") && !endsWith(image_dirs[i], "results/")) {
        image_name = substring(image_dirs[i], 0, lengthOf(image_dirs[i])-1);
        image_dir = threshold_dir + image_dirs[i];
        
        // Get list of threshold directories
        threshold_dirs = getFileList(image_dir);
        
        // Process each threshold directory
        for (t = 0; t < threshold_dirs.length; t++) {
            if (startsWith(threshold_dirs[t], "threshold_")) {
                thresh_dir = image_dir + threshold_dirs[t];
                
                // Extract threshold value from directory name
                thresh_value = substring(threshold_dirs[t], 9, indexOf(threshold_dirs[t], "/"));
                
                // Look for results CSV file
                results_files = getFileList(thresh_dir);
                for (r = 0; r < results_files.length; r++) {
                    if (endsWith(results_files[r], "_results.csv") && !endsWith(results_files[r], "summary.csv")) {
                        results_path = thresh_dir + results_files[r];
                        
                        // Read and process results file
                        lines = split(File.openAsString(results_path), "\n");
                        
                        // Skip header row
                        for (line = 1; line < lines.length; line++) {
                            if (lengthOf(lines[line]) > 0) {
                                values = split(lines[line], ",");
                                
                                // Write data with image name, threshold, and particle ID
                                particle_count++;
                                data_line = image_name + "," + 
                                          thresh_value + "," + 
                                          particle_count;
                                
                                // Add all measurements from the original file
                                for (v = 0; v < values.length; v++) {
                                    data_line = data_line + "," + values[v];
                                }
                                
                                print(f, data_line);
                            }
                        }
                    }
                }
            }
        }
        showProgress(i + 1, image_dirs.length);
    }
}

File.close(f);

// Print completion message
print("\nProcessing complete!");
print("Total particles processed: " + particle_count);
print("Results saved to: " + output_file);