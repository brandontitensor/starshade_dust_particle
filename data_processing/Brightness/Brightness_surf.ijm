// Surface Median Intensity Measurement Script - ImageJ Macro
// Measures median intensity for entire image in surface analysis
// Follows the same structure as the edge brightness measurement script
// Works with folder structure and creates CSV output

setBatchMode(true);
run("Close All");

// Set measurements to include median
run("Set Measurements...", "median redirect=None decimal=3");
run("Clear Results");

// User selects the directory containing folders with images
in = getDirectory("Choose a directory containing folders with images");

// Get list of all folders within the directory
folder_list = getFileList(in);

// Arrays to store file information for matching with Results table
var file_info = newArray(0);  // Will store "folder_name|file_name" for each measurement

// Loop through all folders
for (i = 0; i < folder_list.length; i++) {
    if (File.isDirectory(in + folder_list[i])) {
        current_folder = folder_list[i];
        folder_path = in + current_folder;
        
        // Process all images in the current folder
        processFolder(folder_path, current_folder);
    }
}

// Now extract data from Results table and create CSV
setBatchMode(false);
createCSVFromResults();

print("Surface median intensity measurements complete!");

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
            
            // Set scale to match surface analysis
            run("Set Scale...", "distance=240 known=50 unit=micron");
            
            // Get image dimensions for random box placement
            getDimensions(width, height, channels, slices, frames);
            
            // Measure entire image median (no conversion to 8-bit)
            run("Select All");
            run("Measure");
            file_info = Array.concat(file_info, folder_name + "|" + current_file + "|entire");
            print("Added to file_info: " + folder_name + "|" + current_file + "|entire");
            
            // Define 7 fixed random positions for 60x60 pixel boxes
            // Positions are calculated to ensure boxes stay within image bounds
            box_size = 60;
            margin = box_size / 2; // Ensure boxes don't go outside image
            
            // Fixed random positions (same for every image)
            box_positions = newArray(14); // 7 boxes * 2 coordinates (x,y)
            box_positions[0] = floor(width * 0.15); box_positions[1] = floor(height * 0.2);   // Sample1
            box_positions[2] = floor(width * 0.7);  box_positions[3] = floor(height * 0.15);  // Sample2
            box_positions[4] = floor(width * 0.3);  box_positions[5] = floor(height * 0.45);  // Sample3
            box_positions[6] = floor(width * 0.8);  box_positions[7] = floor(height * 0.6);   // Sample4
            box_positions[8] = floor(width * 0.1);  box_positions[9] = floor(height * 0.75);  // Sample5
            box_positions[10] = floor(width * 0.55); box_positions[11] = floor(height * 0.3); // Sample6
            box_positions[12] = floor(width * 0.4);  box_positions[13] = floor(height * 0.8); // Sample7
            
            // Measure each of the 7 sample boxes
            for (k = 0; k < 7; k++) {
                x_pos = box_positions[k * 2];
                y_pos = box_positions[k * 2 + 1];
                
                // Ensure the box stays within image bounds
                if (x_pos + box_size > width) x_pos = width - box_size;
                if (y_pos + box_size > height) y_pos = height - box_size;
                if (x_pos < 0) x_pos = 0;
                if (y_pos < 0) y_pos = 0;
                
                // Create rectangle selection and measure
                makeRectangle(x_pos, y_pos, box_size, box_size);
                run("Measure");
                file_info = Array.concat(file_info, folder_name + "|" + current_file + "|sample" + (k+1));
                print("Added to file_info: " + folder_name + "|" + current_file + "|sample" + (k+1));
            }
            
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
    csv_path = in + "Surface_Median_Intensity_Results.csv";
    
    // Write CSV header
    File.saveString("Folder Name,File Name,Entire Image Median,Sample1 Median,Sample2 Median,Sample3 Median,Sample4 Median,Sample5 Median,Sample6 Median,Sample7 Median\n", csv_path);
    
    // Process results in groups of 8 (entire + 7 samples)
    for (i = 0; i < num_results && i < file_info.length; i += 8) {
        if (i + 7 < num_results && i + 7 < file_info.length) {
            // Extract folder and file name from first measurement of this group
            info_parts = split(file_info[i], "|");
            if (info_parts.length >= 2) {
                folder_name = info_parts[0];
                file_name = info_parts[1];
                
                // Get median values from Results table
                entire_median = getResult("Median", i);      // entire image
                sample1_median = getResult("Median", i + 1); // sample1
                sample2_median = getResult("Median", i + 2); // sample2
                sample3_median = getResult("Median", i + 3); // sample3
                sample4_median = getResult("Median", i + 4); // sample4
                sample5_median = getResult("Median", i + 5); // sample5
                sample6_median = getResult("Median", i + 6); // sample6
                sample7_median = getResult("Median", i + 7); // sample7
                
                // Write row to CSV
                csv_row = folder_name + "," + file_name + "," + 
                         entire_median + "," + sample1_median + "," + sample2_median + "," + 
                         sample3_median + "," + sample4_median + "," + sample5_median + "," + 
                         sample6_median + "," + sample7_median;
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