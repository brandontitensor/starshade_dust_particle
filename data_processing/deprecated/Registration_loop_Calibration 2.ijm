// Image Registration and Difference
// Process multiple pairs of before and after folders in a parent directory
// Handles unmatched filenames between before and after folders

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
    
    // Create necessary subdirectories including new Edge directory
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", "Split/C1Fused", "Split/C2Fused", "Difference", "Edge", "Crop", "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", "Finished", "Errors");
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
                fusedTitle = "Fused " + file1 + " & " + file2;
                if (isOpen(fusedTitle)) {
                    run("Set Scale...", "distance=240 known=50 unit=micron");
                    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
                    
                    // Split channels
                    run("Split Channels");
                    c1Title = "C1-Fused " + file1 + " & " + file2;
                    c2Title = "C2-Fused " + file1 + " & " + file2;
                    
                    if (isOpen(c1Title) && isOpen(c2Title)) {
                        run("Set Scale...", "distance=240 known=50 unit=micron");
                        selectWindow(c1Title);
                        saveAs(".jpg", processed_dir + "/Split/C1Fused/C1-Fused " + file1 + " & " + file2);
                        c1SavedTitle = getTitle();
                        selectWindow(c2Title);
                        saveAs(".jpg", processed_dir + "/Split/C2Fused/C2-Fused " + file1 + " & " + file2);
                        c2SavedTitle = getTitle();
                        
                        // Edge Detection Block
                        if (isOpen(c1SavedTitle) && isOpen(c2SavedTitle)) {
                            // Create edge image using AND operation and addition
                            imageCalculator("AND create", c1SavedTitle, c2SavedTitle);
                            edgeResultTitle = getTitle();
                            if (isOpen(edgeResultTitle)) {
                                run("Set Scale...", "distance=240 known=50 unit=micron");
                                
                                // Add C1 and C2 to the result
                                imageCalculator("Add", edgeResultTitle, c1SavedTitle);
                                imageCalculator("Add", edgeResultTitle, c2SavedTitle);
                                
                                // Save the edge image
                                saveAs("jpg", processed_dir + "Edge/Edge" + fullFileName);
                                edge_title = getTitle();
                            } else {
                                logError("Failed to create edge image for " + fullFileName, processed_dir);
                                continue;
                            }
                        } else {
                            logError("Channel images not available for edge detection for " + fullFileName, processed_dir);
                            continue;
                        }
                        
                         // Save edge coordinates using the edge image
                                if (isOpen(edge_title)) {
                                    selectWindow(edge_title);
                                    run("8-bit");
									run("Convert to Mask");
                                    saveAllEdgeCoordinates(processed_dir + "EdgeCoordinates/", fullFileName);
                                } else {
                                    logError("Edge image not available for coordinate detection for " + fullFileName, processed_dir);
                                }
                        
                        // Difference Calculation Block
                        if (isOpen(c1SavedTitle) && isOpen(c2SavedTitle)) {
                            // Calculate difference for particle analysis
                            imageCalculator("Difference create", c1SavedTitle, c2SavedTitle);
                            diffTitle = getTitle();
                            
                            if (isOpen(diffTitle)) {
                                saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
                                
                                // Get image dimensions
                                getDimensions(width, height, channels, slices, frames);
                                
                                // Calculate crop parameters for top and bottom only
                                new_height = floor(height * 0.8);
                                new_y = floor(height * 0.1);
                                
                                // Crop the image
                                makeRectangle(0, new_y, width, new_height);
                                run("Crop");
                                run("Set Scale...", "distance=240 known=50 unit=micron");
                                saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
                                run("8-bit");
                                saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
                                setThreshold(95, 255);
                                run("Convert to Mask");
                                saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName);
                                saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName);  
                                run("Set Measurements...", "area bounding redirect=None decimal=3");
                                run("Analyze Particles...", "  show=Masks display exclude include summarize");
                                saveAs("jpg", processed_dir + "Finished/" + fullFileName);
                            } else {
                                logError("Failed to create difference image for " + fullFileName, processed_dir);
                            }
                        } else {
                            logError("Channel images not available for difference calculation for " + fullFileName, processed_dir);
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

// [Previous helper functions remain unchanged]
function logError(message, processed_dir) {
    print("Error: " + message);
    File.append("Error: " + message + "\n", processed_dir + "Errors/error_log.txt");
}


function saveAllEdgeCoordinates(dir, fileName) {
    // Create directory if it doesn't exist
    if (File.isDirectory(dir) == 0) {
        File.makeDirectory(dir);
    }
    
    // Get image dimensions
    width = getWidth();
    height = getHeight();
    
    // Create a file to save the CSV data
    f = File.open(dir + "edge_coordinates_" + fileName + ".csv");
    
    // Write column headers
    print(f, "X,Y");
    
    // Iterate through each column (X coordinate)
    for (x = 0; x < width; x++) {
        // Get the initial value
        if (getPixel(x, 0) == 0) {
            previousValue = 1;
        } else {
            previousValue = 0;
        }
        
        for (y = 1; y < height; y++) {  // Start from 1 to compare with previous
            value = getPixel(x, y);
            if (value == 0) {
                currentValue = 1;
            } else {
                currentValue = 0;
            }
            
            // Check if we've transitioned from black to white
            if (previousValue == 0 && currentValue == 1) {
                print(f, x + "," + y);
            }
            
            previousValue = currentValue;
        }
    }
    
    // Close the file
    File.close(f);
}