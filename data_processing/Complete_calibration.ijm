// Comprehensive Starshade Edge Contamination Analysis Script
// This script combines four separate scripts:
// 1. Registration and difference calculation
// 2. Image dimension measurement
// 3. Edge coordinate extraction
// 4. Particle qualification

// Global variables
var parentDir;

macro "Run Complete Workflow" {
    // Ask user to select parent directory containing Bef_ii and Aft_ii folders
    parentDir = getDirectory("Choose the parent directory containing Bef_ii and Aft_ii folders");
    if (!File.exists(parentDir)) {
        exit("Invalid parent directory selected");
    }
    
    // Step 1: Run registration and difference calculation
    print("Step 1: Running registration and difference calculation...");
    runRegistrationAndDifference(parentDir);
    
    // Step 2: Measure image dimensions and update summary files
    print("Step 2: Measuring image dimensions and updating summary files...");
    updateImageDimensions(parentDir);
    
    // Step 3: Extract edge coordinates
    print("Step 3: Extracting edge coordinates...");
    extractEdgeCoordinates(parentDir);
    
    // Step 4: Qualify edge particles
    print("Step 4: Qualifying edge particles...");
    mapAndQualifyParticles(parentDir);
    
    print("Complete workflow finished successfully!");
}

//==================================================
// STEP 1: REGISTRATION AND DIFFERENCE CALCULATION
//==================================================

function runRegistrationAndDifference(parent_dir) {
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
                print("Processing image pair: " + bef_folder + " and " + aft_folder);
                processImagePair(parent_dir + bef_folder, parent_dir + aft_folder);
            } else {
                print("Error: Matching 'After' folder not found for " + bef_folder);
            }
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
    out_dir = parentDir + "Edge Measurements/" + folderName + "/";
    File.makeDirectory(out_dir);
    processed_dir = out_dir + "Processed Images/";
    File.makeDirectory(processed_dir);
    
    // Create necessary subdirectories including new Edge directory
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", "Split/C1Fused", "Split/C2Fused", "Difference", "Edge", "Crop", "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", "Finished", "Errors", "EdgeCoordinates");
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

//==================================================
// STEP 2: IMAGE DIMENSION MEASUREMENT
//==================================================

function updateImageDimensions(parentFolder) {
    setBatchMode(true);
    subfolders = getSubfolders(parentFolder);

    for (i=0; i<subfolders.length; i++) {
        subfolder = subfolders[i];
        if (matches(File.getName(subfolder), "Bef_.*minus Aft_.*")) {
            finishedImagesPath = subfolder + "Processed Images" + File.separator + "Finished" + File.separator;
            edgeImagesPath = subfolder + "Processed Images" + File.separator + "Edge" + File.separator;
            summaryFilePath = findSummaryFile(subfolder);
            
            if (summaryFilePath == "") {
                print("No summary file found in " + subfolder);
                continue;
            }
            
            summaryFile = File.openAsString(summaryFilePath);
            
            // Process images
            finishedImageList = getFileList(finishedImagesPath);
            Table.create("Dimension Data");
            rowIndex = 0;
            
            for (j=0; j<finishedImageList.length; j++) {
                if (endsWith(finishedImageList[j], ".tif") || endsWith(finishedImageList[j], ".jpg") || 
                    endsWith(finishedImageList[j], ".png")) {
                    // Get Finished image dimensions
                    finishedImagePath = finishedImagesPath + finishedImageList[j];
                    finishedDimensions = getImageDimensions(finishedImagePath);
                    
                    // Get corresponding Edge image dimensions
                    edgeFilename = getEdgeFilename(finishedImageList[j]);
                    edgeImagePath = edgeImagesPath + edgeFilename;
                    edgeDimensions = getImageDimensions(edgeImagePath);
                    
                    // Calculate differences
                    widthDiff = finishedDimensions[0] - edgeDimensions[0];
                    heightDiff = finishedDimensions[1] - edgeDimensions[1];
                    
                    // Store data in table
                    Table.set("image_name", rowIndex, finishedImageList[j]);
                    Table.set("edge_image_name", rowIndex, edgeFilename);
                    Table.set("finished_width", rowIndex, finishedDimensions[0]);
                    Table.set("finished_height", rowIndex, finishedDimensions[1]);
                    Table.set("edge_width", rowIndex, edgeDimensions[0]);
                    Table.set("edge_height", rowIndex, edgeDimensions[1]);
                    Table.set("width_difference", rowIndex, widthDiff);
                    Table.set("height_difference", rowIndex, heightDiff);
                    rowIndex++;
                }             
            }
            
            // Update summary file with dimension data
            summaryLines = split(summaryFile, "\n");
            
            // Get all column data
            imageNameColumn = Table.getColumn("image_name");
            edgeImageNameColumn = Table.getColumn("edge_image_name");
            finishedWidthColumn = Table.getColumn("finished_width");
            finishedHeightColumn = Table.getColumn("finished_height");
            edgeWidthColumn = Table.getColumn("edge_width");
            edgeHeightColumn = Table.getColumn("edge_height");
            widthDiffColumn = Table.getColumn("width_difference");
            heightDiffColumn = Table.getColumn("height_difference");
            
            // Add new column headers
            headerFields = split(summaryLines[0], ",");
            newHeaders = newArray("image_name", "edge_image_name", "finished_width", "finished_height", 
                                "edge_width", "edge_height", "width_difference", "height_difference");
            headerFields = Array.concat(headerFields, newHeaders);
            summaryLines[0] = String.join(headerFields, ",");
            
            // Update each row with new data
            for (k=1; k<summaryLines.length; k++) {
                summaryFields = split(summaryLines[k], ",");
                
                if (k-1 < imageNameColumn.length) {
                    newData = newArray(imageNameColumn[k-1], edgeImageNameColumn[k-1],
                                    finishedWidthColumn[k-1], finishedHeightColumn[k-1], 
                                    edgeWidthColumn[k-1], edgeHeightColumn[k-1], 
                                    widthDiffColumn[k-1], heightDiffColumn[k-1]);
                } else {
                    newData = newArray("", "", "", "", "", "", "", "");
                }
                
                summaryFields = Array.concat(summaryFields, newData);
                summaryLines[k] = String.join(summaryFields, ",");
            }
            
            // Save updated summary file
            updatedSummary = String.join(summaryLines, "\n");
            updatedSummaryPath = substring(summaryFilePath, 0, lastIndexOf(summaryFilePath, ".")) + "_updated.csv";
            File.saveString(updatedSummary, updatedSummaryPath);
            
            // Clear the table for the next iteration
            Table.reset("Dimension Data");
        }
    }
    setBatchMode(false);
    print("Image dimension measurements completed");
}

function getSubfolders(dir) {
    subfolders = newArray(0);
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        if (endsWith(list[i], "/"))
            subfolders = Array.concat(subfolders, dir + list[i]);
    }
    return subfolders;
}

function findSummaryFile(dir) {
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        if (startsWith(list[i], "Summary")) {
            return dir + list[i];
        }
    }
    return "";
}

function getImageDimensions(imagePath) {
    dimensions = newArray(2);
    if (File.exists(imagePath)) {
        open(imagePath);
        imageId = getImageID();
        selectImage(imageId);
        dimensions[0] = getWidth();
        dimensions[1] = getHeight();
        close();
    } else {
        dimensions[0] = 0;
        dimensions[1] = 0;
    }
    return dimensions;
}

function getEdgeFilename(finishedName) {
    // Replace "Difference" with "Edge" at the start of the filename
    if (startsWith(finishedName, "Difference")) {
        return "Edge" + substring(finishedName, 10); // "Difference" is 10 characters
    }
    return finishedName; // Return unchanged if doesn't start with "Difference"
}

//==================================================
// STEP 3: EDGE COORDINATE EXTRACTION
//==================================================

function extractEdgeCoordinates(mainDir) {
    // Enable batch mode for better performance
    setBatchMode(true);

    // Get list of all items in main directory
    mainList = getFileList(mainDir);

    // Initialize counters for summary
    totalFolders = 0;
    totalImages = 0;

    // Loop through main directory to find "Bef_# minus Aft_#" folders
    for (i = 0; i < mainList.length; i++) {
        folderName = mainList[i];
        if (matches(folderName, "Bef_.*minus Aft_.*")) {
            totalFolders++;
            currentFolder = mainDir + folderName;
            processedImagesPath = currentFolder + "Processed Images" + File.separator;
            edgePath = processedImagesPath + "Edge" + File.separator;
            
            // Create NewEdgeCoordinates folder in Processed Images
            newEdgeDir = processedImagesPath + "NewEdgeCoordinates" + File.separator;
            File.makeDirectory(newEdgeDir);
            
            // Check if Edge folder exists and process files
            if (File.exists(edgePath)) {
                edgeFiles = getFileList(edgePath);
                
                // Process each image file
                for (j = 0; j < edgeFiles.length; j++) {
                    if (endsWith(toLowerCase(edgeFiles[j]), ".tif") || 
                        endsWith(toLowerCase(edgeFiles[j]), ".jpg") || 
                        endsWith(toLowerCase(edgeFiles[j]), ".png") || 
                        endsWith(toLowerCase(edgeFiles[j]), ".bmp")) {
                        
                        // Open and process image
                        open(edgePath + edgeFiles[j]);
                        run("8-bit");
                        run("Convert to Mask");
                        
                        // Get image dimensions and create pixel array
                        width = getWidth();
                        height = getHeight();
                        
                        // Get all pixels at once for faster processing
                        pixelArray = newArray(width * height);
                        for (y = 0; y < height; y++) {
                            for (x = 0; x < width; x++) {
                                pixelArray[x + y * width] = getPixel(x, y);
                            }
                        }
                        
                        // Create array for storing edge positions
                        maxY = newArray(width);
                        Array.fill(maxY, -1);
                        
                        // Process columns in parallel using macro functions
                        for (x = 0; x < width; x++) {
                            lastEdge = -1;
                            for (y = 0; y < height; y++) {
                                currentPixel = pixelArray[x + y * width];
                                if (y > 0) {
                                    previousPixel = pixelArray[x + (y-1) * width];
                                    // Check for both black-to-white and white-to-black transitions
                                    if ((previousPixel == 0 && currentPixel == 255) || 
                                        (previousPixel == 255 && currentPixel == 0)) {
                                        lastEdge = y;
                                    }
                                }
                            }
                            if (lastEdge > -1) {
                                maxY[x] = lastEdge;
                            }
                        }
                        
                        // Prepare output file
                        baseName = substring(edgeFiles[j], 0, lastIndexOf(edgeFiles[j], "."));
                        outputFile = newEdgeDir + baseName + "_edges.csv";
                        
                        // Write results using string buffer for faster I/O
                        buffer = "X,Y\n";
                        for (x = 0; x < width; x++) {
                            if (maxY[x] >= 0) {
                                buffer = buffer + x + "," + maxY[x] + "\n";
                            }
                        }
                        
                        // Write buffer to file at once
                        File.saveString(buffer, outputFile);
                        
                        // Clean up
                        close();
                        totalImages++;
                        
                        // Update progress every 10 images
                        if (totalImages % 10 == 0) {
                            showProgress(totalImages / lengthOf(edgeFiles));
                            print("Processing: " + folderName + " - Image " + totalImages);
                        }
                    }
                }
            } else {
                print("Warning: Edge folder not found in " + folderName);
            }
        }
    }

    // Disable batch mode
    setBatchMode(false);
    print("Edge coordinate extraction completed: Processed " + totalImages + " images across " + totalFolders + " folders");
}

//==================================================
// STEP 4: PARTICLE QUALIFICATION
//==================================================

function mapAndQualifyParticles(parentDir) {
    // Get list of all folders within the parent directory
    list = getFileList(parentDir);
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "Bef_")) {
            // First map particles to slices, then qualify them
            mapParticlesToSlices(parentDir + list[i]);
            qualifyEdgeParticles(parentDir + list[i]);
        }
    }
}

function qualifyEdgeParticles(folder) {
    // Extract sample number from the folder name
    folderName = File.getName(folder);
    if (indexOf(folderName, " minus") == -1) {
        print("Invalid folder name format: " + folderName);
        return;
    }
    sampleNumber = substring(folderName, 4, indexOf(folderName, " minus"));
    
    // Construct full paths
    particlesFile = folder + "Particles Bef_" + sampleNumber + " minus Aft_" + sampleNumber + ".csv";
    summaryFile = folder + "Summary Bef_" + sampleNumber + " minus Aft_" + sampleNumber + "_updated.csv";
    edgeCoordDir = folder + "Processed Images" + File.separator + "NewEdgeCoordinates" + File.separator;
    
    // Print paths for debugging
    print("Processing folder: " + folder);
    print("Particles file: " + particlesFile);
    print("Summary file: " + summaryFile);
    print("Edge coordinates directory: " + edgeCoordDir);
    
    // Get dimension differences from summary file
    dimensionDiffs = getDimensionDifferences(summaryFile);
    
    // Verify files exist
    if (!File.exists(particlesFile) || !File.exists(edgeCoordDir)) {
        print("Required files not found for sample " + sampleNumber);
        return;
    }

    // Read particles file
    particleLines = split(File.openAsString(particlesFile), "\n");
    if (particleLines.length < 2) {
        print("Invalid particles file format for sample " + sampleNumber);
        return;
    }

    // Get header indices for particles file
    particleHeaders = split(particleLines[0], ",");
    bxIndex = -1;
    byIndex = -1;
    heightIndex = -1;
    widthIndex = -1;
    sliceIndex = -1;
    for (i = 0; i < particleHeaders.length; i++) {
        if (particleHeaders[i] == "BX") bxIndex = i;
        if (particleHeaders[i] == "BY") byIndex = i;
        if (particleHeaders[i] == "Height") heightIndex = i;
        if (particleHeaders[i] == "Width") widthIndex = i;
        if (particleHeaders[i] == "Slice") sliceIndex = i;
    }

    // Verify required columns exist
    if (bxIndex == -1 || byIndex == -1 || heightIndex == -1 || widthIndex == -1 || sliceIndex == -1) {
        print("Required columns not found in particles file");
        return;
    }

    // Add IsQualified column if it doesn't exist
    if (indexOf(particleLines[0], "IsQualified") == -1) {
        particleLines[0] = particleLines[0] + ",IsQualified";
    }

    // Load edge coordinates for each slice
    edgeCoords = newArray(1000);
    edgeFiles = getFileList(edgeCoordDir);
    
    // Get valid slices from particle data
    validSlices = newArray(1000);
    for (i = 1; i < particleLines.length; i++) {
        particleData = split(particleLines[i], ",");
        if (particleData.length <= maxOf(maxOf(bxIndex, byIndex), maxOf(heightIndex, sliceIndex))) {
            continue;
        }

        // Get particle data
        slice = parseInt(particleData[sliceIndex]);
        bx = parseFloat(particleData[bxIndex]);
        by = parseFloat(particleData[byIndex]);
        height = parseFloat(particleData[heightIndex]);
        width = parseFloat(particleData[widthIndex]);
        
        // Apply dimension differences if available for this slice
        if (dimensionDiffs[slice] != "") {
            diffs = split(dimensionDiffs[slice], ",");
            if (diffs.length >= 2) {
                widthDiff = parseFloat(diffs[0]);
                heightDiff = parseFloat(diffs[1]);
                
                // Apply half of the differences to coordinates, with scaling
                bx = bx + ((widthDiff * (-50.0/240.0)) / 2);
                by = by + ((heightDiff * (-50.0/240.0)) / 2);
            }
        }
        
        particleTop = by + height;
        particleLeft = bx;
        particleRight = bx + width;

        isQualified = false;

        // Skip if no edge data for this slice
        if (edgeCoords[slice] == "") {
            if (endsWith(particleLines[i], ",")) {
                newParticleLines[i] = particleLines[i] + "false";
            } else {
                newParticleLines[i] = particleLines[i] + ",false";
            }
            continue;
        }

        // Check qualification against edge coordinates
        edgePoints = split(edgeCoords[slice], ";");
        for (p = 0; p < edgePoints.length; p++) {
            if (edgePoints[p] == "") continue;
            
            coords = split(edgePoints[p], ",");
            if (coords.length < 2) continue;
            
            edgeX = parseFloat(coords[0]);
            edgeY = parseFloat(coords[1]);
            
            if (edgeX >= particleLeft && edgeX <= particleRight) {
                if ((particleTop + 2) >= edgeY) {
                    isQualified = true;
                    break;
                }
            }
        }

        // Update particle line with qualification status
        if (endsWith(particleLines[i], ",")) {
            newParticleLines[i] = particleLines[i] + isQualified;
        } else {
            newParticleLines[i] = particleLines[i] + "," + isQualified;
        }
    }

    // Save updated particles file
    File.saveString(String.join(newParticleLines, "\n"), particlesFile);
    print("Processed sample " + sampleNumber + ": Added qualification status with dimension adjustments");
}++) {
        particleData = split(particleLines[i], ",");
        if (particleData.length > sliceIndex) {
            slice = parseInt(particleData[sliceIndex]);
            validSlices[slice] = true;
        }
    }
    
    // Process edge coordinate files
    for (i = 0; i < edgeFiles.length; i++) {
        if (endsWith(edgeFiles[i], ".csv")) {
            sliceNum = extractSliceNumber(edgeFiles[i]);
            if (sliceNum == -1 || !validSlices[sliceNum]) continue;
            
            edgeData = split(File.openAsString(edgeCoordDir + edgeFiles[i]), "\n");
            if (edgeData.length < 2) continue;
            
            coordArray = newArray(edgeData.length - 1);
            for (j = 1; j < edgeData.length; j++) {
                coords = split(edgeData[j], ",");
                if (coords.length >= 2) {
                    scaledX = parseFloat(coords[0]) * (50.0/240.0);
                    scaledY = parseFloat(coords[1]) * (50.0/240.0);
                    coordArray[j-1] = d2s(scaledX,6) + "," + d2s(scaledY,6);
                }
            }
            edgeCoords[sliceNum] = String.join(coordArray, ";");
        }
    }

    // Process each particle
    newParticleLines = newArray(particleLines.length);
    newParticleLines[0] = particleLines[0];
    
    for (i = 1; i < particleLines.length; i++) {
        sliceNumber = -1;
        particleIndex = i;
        
        // Find appropriate slice for this particle
        for (j = 0; j <= maxValidSlice; j++) {
            if (validSlices[j] && particleIndex <= cumulativeCounts[j]) {
                sliceNumber = j;
                break;
            }
        }

        // Add slice number to particle data
        if (sliceNumber == -1) {
            print("Warning: Could not assign slice number to particle " + i);
            if (endsWith(particleLines[i], ",")) {
                newParticleLines[i] = particleLines[i] + "0";
            } else {
                newParticleLines[i] = particleLines[i] + ",0";
            }
        } else {
            if (endsWith(particleLines[i], ",")) {
                newParticleLines[i] = particleLines[i] + sliceNumber;
            } else {
                newParticleLines[i] = particleLines[i] + "," + sliceNumber;
            }
        }
    }

    // Save updated particles file
    File.saveString(String.join(newParticleLines, "\n"), particlesFile);
    print("Processed sample " + sampleNumber + ": Added slice numbers to particles");
}
    
    for (i = 1; i < particleLines.length; i