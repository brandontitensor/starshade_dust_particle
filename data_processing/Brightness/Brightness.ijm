// Median Intensity Measurement Script - ImageJ Macro
// Measures median intensity in different regions of each image
// Works with Bef_ii and Aft_ii folder structure
// Uses Results table data for CSV output

setBatchMode(true);
run("Close All");

// Set measurements to include median
run("Set Measurements...", "median redirect=None decimal=3");
run("Clear Results");

// User selects the parent directory containing all before and after folders
parent_dir = getDirectory("Choose the parent directory containing all before and after folders");

// Get list of all folders within the parent directory
folder_list = getFileList(parent_dir);

// Arrays to store file information for matching with Results table
var file_info = newArray(0);  // Will store "folder_name|file_name" for each measurement

// Loop through all folders (both Bef_ii and Aft_ii)
for (i = 0; i < folder_list.length; i++) {
    if (startsWith(folder_list[i], "Bef_") || startsWith(folder_list[i], "Aft_")) {
        current_folder = folder_list[i];
        folder_path = parent_dir + current_folder;
        
        // Process all images in the current folder
        processFolder(folder_path, current_folder);
    }
}

// Now extract data from Results table and create CSV
setBatchMode(false);
createCSVFromResults();

print("Median intensity measurements complete!");

function processFolder(folder_path, folder_name) {
    file_list = getFileList(folder_path);
    Array.sort(file_list);
    
    print("Processing folder: " + folder_name);
    
    for (j = 0; j < file_list.length; j++) {
        current_file = file_list[j];
        
        // Check if it's an image file
        if (endsWith(current_file, ".jpg") || endsWith(current_file, ".jpeg") || 
            endsWith(current_file, ".tif") || endsWith(current_file, ".tiff") || 
            endsWith(current_file, ".png") || endsWith(current_file, ".bmp")) {
            
            showProgress(j+1, file_list.length);
            
            // Open the image
            open(folder_path + current_file);
            image_title = getTitle();
            
            // Get image dimensions
            getDimensions(width, height, channels, slices, frames);
            
            // Measure entire image median
            run("Select All");
            run("Measure");
            file_info = Array.concat(file_info, folder_name + "|" + current_file + "|entire");
            print("Added to file_info: " + folder_name + "|" + current_file + "|entire");
            
            // Measure top 40% median
            top_40_height = floor(height * 0.4);
            makeRectangle(0, 0, width, top_40_height);
            run("Measure");
            file_info = Array.concat(file_info, folder_name + "|" + current_file + "|upper40");
            print("Added to file_info: " + folder_name + "|" + current_file + "|upper40");
            
            // Measure top 30% median
            top_30_height = floor(height * 0.3);
            makeRectangle(0, 0, width, top_30_height);
            run("Measure");
            file_info = Array.concat(file_info, folder_name + "|" + current_file + "|upper30");
            print("Added to file_info: " + folder_name + "|" + current_file + "|upper30");
            
            // Measure bottom 30% median
            bottom_30_height = floor(height * 0.3);
            bottom_y = height - bottom_30_height;
            makeRectangle(0, bottom_y, width, bottom_30_height);
            run("Measure");
            file_info = Array.concat(file_info, folder_name + "|" + current_file + "|lower30");
            print("Added to file_info: " + folder_name + "|" + current_file + "|lower30");
            
            print("Processed: " + folder_name + "/" + current_file);
            
            // Close the image
            close(image_title);
        }
    }
}

function createCSVFromResults() {
    // Get number of measurements
    num_results = nResults;
    print("Total measurements in Results table: " + num_results);
    print("File info array length: " + file_info.length);
    
    if (num_results == 0) {
        print("No results to process!");
        return;
    }
    
    if (file_info.length == 0) {
        print("ERROR: File info array is empty!");
        print("This means the measurements were made but file tracking failed.");
        return;
    }
    
    // Create output file
    csv_path = parent_dir + "Median_Intensity_Results.csv";
    
    // Write CSV header
    File.saveString("Folder Name,File Name,Upper 40% Median,Upper 30% Median,Lower 30% Median,Entire Image Median\n", csv_path);
    
    // Process results in groups of 4 (entire, upper40, upper30, lower30)
    for (i = 0; i < num_results && i < file_info.length; i += 4) {
        if (i + 3 < num_results && i + 3 < file_info.length) {
            // Extract folder and file name from first measurement of this group
            info_parts = split(file_info[i], "|");
            if (info_parts.length >= 2) {
                folder_name = info_parts[0];
                file_name = info_parts[1];
                
                // Get median values from Results table
                entire_median = getResult("Median", i);      // entire image
                upper_40_median = getResult("Median", i + 1); // upper 40%
                upper_30_median = getResult("Median", i + 2); // upper 30%
                lower_30_median = getResult("Median", i + 3); // lower 30%
                
                // Write row to CSV
                csv_row = folder_name + "," + file_name + "," + 
                         upper_40_median + "," + upper_30_median + "," + 
                         lower_30_median + "," + entire_median;
                File.append(csv_row, csv_path);
                
                print("Added to CSV: " + folder_name + "/" + file_name);
            } else {
                print("ERROR: Could not parse file info: " + file_info[i]);
            }
        }
    }
    
    print("CSV file created: " + csv_path);
    
    // Verify file exists
    if (File.exists(csv_path)) {
        print("CSV file successfully saved!");
    } else {
        print("ERROR: CSV file was not created!");
    }
}