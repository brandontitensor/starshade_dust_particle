// Clear any existing results
run("Clear Results");

// Get the parent directory containing the Surface_Analysis folder
parent_dir = getDirectory("Choose the directory containing the Surface_Analysis folder");

// Find the Surface_Analysis folder
folder_list = getFileList(parent_dir);
surface_analysis_folder = "";

for (i = 0; i < folder_list.length; i++) {
    if (startsWith(folder_list[i], "Surface_Analysis_")) {
        // If we find multiple folders, keep the most recent one
        if (surface_analysis_folder == "" || folder_list[i] > surface_analysis_folder) {
            surface_analysis_folder = folder_list[i];
        }
    }
}

if (surface_analysis_folder == "") {
    exit("Error: No Surface_Analysis folder found in " + parent_dir);
}

threshold_dir = parent_dir + surface_analysis_folder + "Threshold_Analysis/";
if (!File.exists(threshold_dir)) {
    exit("Error: Threshold_Analysis folder not found in " + surface_analysis_folder);
}

// Create output file
output_file = parent_dir + surface_analysis_folder + "combined_surface_analysis.csv";
f = File.open(output_file);

// Write header
print(f, "Folder,Image,Threshold,Area,Perim.,BX,BY,Width,Height,Circ.,Feret,FeretX,FeretY,FeretAngle,MinFeret,AR,Round,Solidity");

// Get list of all threshold directories
threshold_list = getFileList(threshold_dir);
particle_count = 0;

// Process each threshold directory
for (t = 0; t < threshold_list.length; t++) {
    if (startsWith(threshold_list[t], "threshold_")) {
        thresh_dir = threshold_dir + threshold_list[t];
        
        // Extract threshold value
        thresh_value = substring(threshold_list[t], 10, indexOf(threshold_list[t], "/"));
        
        // Get list of CSV files in this threshold directory
        file_list = getFileList(thresh_dir);
        
        // Process each CSV file
        for (f_idx = 0; f_idx < file_list.length; f_idx++) {
            if (endsWith(file_list[f_idx], ".csv")) {
                results_path = thresh_dir + file_list[f_idx];
                
                // Extract folder and image names from filename
                file_base = getFilenameWithoutExtension(file_list[f_idx]);
                folder_name = substring(file_base, 0, indexOf(file_base, "_"));
                image_name = substring(file_base, indexOf(file_base, "_") + 1);
                
                // Read and process results file
                lines = split(File.openAsString(results_path), "\n");
                
                // Skip header row
                for (line = 1; line < lines.length; line++) {
                    if (lengthOf(lines[line]) > 0) {
                        values = split(lines[line], ",");
                        
                        if (values.length >= 1) {  // Check if line has data
                            particle_count++;
                            
                            // Construct data line
                            data_line = folder_name + "," + 
                                      image_name + "," + 
                                      thresh_value;
                            
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
        showProgress(t + 1, threshold_list.length);
    }
}

File.close(f);

// Print completion message
print("\nProcessing complete!");
print("Total particles measured: " + particle_count);
print("Results saved to: " + output_file);

function getFilenameWithoutExtension(filename) {
    dot_index = lastIndexOf(filename, ".");
    if (dot_index != -1)
        return substring(filename, 0, dot_index);
    return filename;
}