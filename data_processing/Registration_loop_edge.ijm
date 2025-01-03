// Image Registration and Difference
// Process multiple pairs of before and after folders in a parent directory
// Handles unmatched filenames between before and after folders
// Macro to add "0" before file extension in Bef_ii folders
run("Close All");

// User selects the parent directory containing Bef_ii folders
parent_dir = getDirectory("Choose the parent directory containing Bef_ii folders");

// Get list of all folders within the parent directory
folder_list = getFileList(parent_dir);

// Loop through folders to find Bef_ii folders
for (i = 0; i < folder_list.length; i++) {
    if (startsWith(folder_list[i], "Bef_")) {
        processFolder(parent_dir + folder_list[i]);
    }
}

function processFolder(folder_path) {
    // Get list of files in the folder
    file_list = getFileList(folder_path);
    
    // Loop through each file
    for (i = 0; i < file_list.length; i++) {
        old_name = file_list[i];
        
        // Check if the file has an extension
        dot_index = lastIndexOf(old_name, ".");
        if (dot_index != -1) {
            // Construct new name with "0" before the extension
            new_name = substring(old_name, 0, dot_index) + "0" + substring(old_name, dot_index);
            
            // Rename the file
            File.rename(folder_path + old_name, folder_path + new_name);
            print("Renamed: " + old_name + " to " + new_name);
        }
    }
    print("Processed folder: " + folder_path);
}

print("Renaming complete!");


run("Close All");

// User selects the parent directory containing all before and after folders
parent_dir = getDirectory("Choose the parent directory containing all before and after folders");

// Get list of all folders within the parent directory
folder_list = getFileList(parent_dir);

// Create Edge Measurements folder in the parent directory if it doesn't exist
if (File.isDirectory(parent_dir + "Edge Measurements") == 0) {
    File.makeDirectory(parent_dir + "Edge Measurements");
}

// Loop through folders to find matching Bef_ii and Aft_ii pairs
for (i = 0; i < folder_list.length; i++) {
    if (startsWith(folder_list[i], "Bef_")) {
        bef_folder = folder_list[i];
        aft_folder = "Aft_" + substring(bef_folder, 4);
        
        if (File.exists(parent_dir + aft_folder)) {
            processImagePair(parent_dir + bef_folder, parent_dir + aft_folder);
            
            // After processing each pair, measure lengths of finished images
            measureFinishedImageLengths(out_dir);
        } else {
            print("Error: Matching 'After' folder not found for " + bef_folder);
        }
    }
}

function processImagePair(in_dir_1, in_dir_2) {
    // Get list of all files within sample directories
    ls_1 = getFileList(in_dir_1);
    ls_2 = getFileList(in_dir_2);
    

    // Sort the file lists to ensure consistent ordering
    Array.sort(ls_1);
    Array.sort(ls_2);

    // Create output directory
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    folderName = File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2) + "_" + year + "_" + (month+1) + "_" + dayOfMonth + "_" + hour + "_" + minute + "_" + second;
    out_dir = parent_dir + "Edge Measurements/" + folderName + "/";
    File.makeDirectory(out_dir);
    processed_dir = out_dir + "Processed Images/";
    File.makeDirectory(processed_dir);
    
    // Create necessary subdirectories
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", "Split/C1Fused", "Split/C2Fused", "Difference", "Crop", "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", "Finished", "Errors");
    for (i = 0; i < subdirs.length; i++) {
        if (File.isDirectory(processed_dir + subdirs[i]) == 0) {
            File.makeDirectory(processed_dir + subdirs[i]);
        }
    }

    // Process each pair of images
    for (i = 0; i < ls_1.length && i < ls_2.length; i++) {
        showProgress(i+1, minOf(ls_1.length, ls_2.length));
        
        file1 = File.getNameWithoutExtension(ls_1[i]);
        file2 = File.getNameWithoutExtension(ls_2[i]);
        fullFileName = file1 + "minus" + file2;
        
        // Process clean (before) image
        if (File.exists(in_dir_1 + ls_1[i])) {
            open(in_dir_1 + ls_1[i]);
            run("8-bit");
            run("Set Scale...", "distance=240 known=50 unit=micron");
            saveAs("jpg", processed_dir + "8 bit clean/8bit" + file1);
            title1 = getTitle();
            
            // Process dirty (after) image
            if (File.exists(in_dir_2 + ls_2[i])) {
                open(in_dir_2 + ls_2[i]);
                run("8-bit");
                run("Set Scale...", "distance=240 known=50 unit=micron");
                saveAs("jpg", processed_dir + "8 bit dirty/8bit" + file2);
                title2 = getTitle();
                
                // Perform registration
                run("Descriptor-based registration (2d/3d)", "first_image=" + title1 + " second_image=" + title2 + " brightness_of=[Advanced ...] approximate_size=[Advanced ...] type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] number_of_neighbors=3 redundancy=2 significance=3 allowed_error_for_ransac=6 choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 create_overlayed add_point_rois interpolation=[Linear Interpolation] detection_sigma=3.9905 threshold=0.0537");
                
                // Check if registration was successful and continue processing
                if (isOpen("Fused " + file1 + " & " + file2)) {
                    run("Set Scale...", "distance=240 known=50 unit=micron");
                    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
                    
                    // Continue with channel splitting, difference calculation, and particle analysis
                    run("Split Channels");
                    if (isOpen("C1-Fused " + file1 + " & " + file2) && isOpen("C2-Fused " + file1 + " & " + file2)) {
                        run("Set Scale...", "distance=240 known=50 unit=micron");
						selectWindow("C1-Fused " + file1 + " & " + file2);
						saveAs(".jpg", processed_dir + "/Split/C1Fused/C1-Fused " + file1 + " & " + file2);
						selectWindow("C2-Fused " + file1 + " & " + file2);
						saveAs(".jpg", processed_dir + "/Split/C2Fused/C2-Fused " + file1 + " & " + file2);
						imageCalculator("Difference create", "C1-Fused " + file1 + " & " + file2,"C2-Fused " + file1 + " & " + file2);
                        
                        if (isOpen("Result of C1-Fused " + file1 + " & " + file2)) {
                            saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
                            
                            // Get image dimensions
                            getDimensions(width, height, channels, slices, frames);
                            
                            // Calculate crop parameters for middle 50%
                            new_width = floor(width * 0.75);
                            new_x = floor(width * 0.125);
                            new_height = floor(height * 0.75);
                            new_y = floor(height * 0.125);
                            
                            // Crop the image
                            run("Specify...", "width=" + new_width + " height=" + new_height + " x=" + new_x + " y=" + new_y);
                            run("Crop");
                            run("Set Scale...", "distance=240 known=50 unit=micron");
                            saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
                            run("8-bit");
                            saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
                            setThreshold(60, 255);
                            run("Threshold...");
                            saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName);
                            run("Convert to Mask");
                            saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName);
                            run("Set Measurements...", "area bounding redirect=None decimal=3");
                       		 run("Analyze Particles...", "  show=Masks display exclude include summarize");
                           	saveAs("jpg", processed_dir + "Finished/" + fullFileName);
                        } else {
                            logError("Failed to create difference image for " + fullFileName, processed_dir);
                        }
                    } else {
                        logError("Failed to split channels for " + fullFileName, processed_dir);
                    }
                } else {
                    logError("Registration failed for " + fullFileName, processed_dir);
                }
            } else {
                logError("Dirty file not found - " + in_dir_2 + ls_2[i], processed_dir);
            }
        } else {
            logError("Clean file not found - " + in_dir_1 + ls_1[i], processed_dir);
        }
        
        run("Close All");
    }
    
    // Save results tables
    Table.save(out_dir + "Particles " + File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2) + ".csv", "Results");
    Table.save(out_dir + "Summary " + File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2) + ".csv", "Summary");
    close("Results");
    close("Summary");
}

function logError(message, processed_dir) {
    print("Error: " + message);
    File.append("Error: " + message + "\n", processed_dir + "Errors/error_log.txt");
}

function measureFinishedImageLengths(out_dir) {
    finished_dir = out_dir + "Processed Images/Finished/";
    finished_files = getFileList(finished_dir);
    
    // Create a new results table for lengths
    Table.create("Lengths");
    
    for (i = 0; i < finished_files.length; i++) {
        if (endsWith(finished_files[i], ".jpg")) {
            open(finished_dir + finished_files[i]);
            
            // Get image dimensions
            getDimensions(width, height, channels, slices, frames);
            
            // Calculate length (assuming length is the larger dimension)
            length = maxOf(width, height);
            
            // Add to the Lengths table
            Table.set("Image Name", i, finished_files[i]);
            Table.set("Length (pixels)", i, length);
            
            close();
        }
    }
    
    // Save the Lengths table
    Table.save(out_dir + "Lengths.csv", "Lengths");
    Table.reset("Lengths");
}