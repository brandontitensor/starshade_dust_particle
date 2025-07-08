function processCalibrationPairWithThreshold(in_dir_1, in_dir_2, threshold_dir, threshold_value) {
    // Get and sort file lists (these are now brightness-corrected images)
    ls_1 = getFileList(in_dir_1);
    ls_2 = getFileList(in_dir_2);
    Array.sort(ls_1);
    Array.sort(ls_2);
    
    // Filter to image files
    image_files_1 = filterImageFiles(ls_1);
    image_files_2 = filterImageFiles(ls_2);
    
    // Setup output directories for this threshold (following original calibration structure)
    folderName = File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2);
    out_dir = threshold_dir + folderName + "/";
    processed_dir = out_dir + "Processed Images/";
    
    // Create all subdirectories (using original calibration naming)
    createAllCalibrationSubdirectories(out_dir, processed_dir);
    
    // Process image pairs using the full calibration workflow
    num_pairs = minOf(image_files_1.length, image_files_2.length);
    
    for (i = 0; i < num_pairs; i++) {
        showProgress(i+1, num_pairs);
        
        if (processCalibrationImagePairSingleWithThreshold(in_dir_1, in_dir_2, image_files_1[i], image_files_2[i], 
                                                          processed_dir, threshold_value)) {
            // Success - continue
        } else {
            logError("Failed to process pair: " + image_files_1[i] + " & " + image_files_2[i], processed_dir);
        }
        
        // Cleanup memory every few iterations
        if (i % 5 == 0) {
            run("Close All");
            run("Collect Garbage");
        }
    }
    
    // Enhanced summary generation (from original calibration script)
    addOptimizedSummaryData(out_dir, in_dir_1, in_dir_2);
    
    // Save results for this pair
    saveResultsTablesForThreshold(out_dir, in_dir_1, in_dir_2, threshold_value);
}

function processCalibrationImagePairSingleWithThreshold(in_dir_1, in_dir_2, file1_name, file2_name, processed_dir, threshold_value) {
    file1 = File.getNameWithoutExtension(file1_name);
    file2 = File.getNameWithoutExtension(file2_name);
    fullFileName = file1 + "minus" + file2;
    
    print("  Processing: " + file1_name + " & " + file2_name + " with threshold " + threshold_value);
    
    // Check if input files exist
    if (!File.exists(in_dir_1 + file1_name)) {
        print("    First file not found: " + in_dir_1 + file1_name);
        return false;
    }
    if (!File.exists(in_dir_2 + file2_name)) {
        print("    Second file not found: " + in_dir_2 + file2_name);
        return false;
    }
    
    // Load and prepare first image (brightness-corrected)
    print("    Opening first image: " + in_dir_1 + file1_name);
    open(in_dir_1 + file1_name);
    if (nImages() == 0) {
        print("    Failed to open first image");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit clean/8bit" + file1);
    title1 = getTitle();
    print("    First image loaded as: " + title1);
    
    // Load and prepare second image (brightness-corrected)
    print("    Opening second image: " + in_dir_2 + file2_name);
    open(in_dir_2 + file2_name);
    if (nImages() != 2) {
        print("    Failed to open second image (total images: " + nImages() + ")");
        close("*");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit dirty/8bit" + file2);
    title2 = getTitle();
    print("    Second image loaded as: " + title2);
    
    // Check that both images are still open
    if (!isOpen(title1) || !isOpen(title2)) {
        print("    One or both images not accessible for registration");
        print("      Title1 open: " + isOpen(title1));
        print("      Title2 open: " + isOpen(title2));
        close("*");
        return false;
    }
    
    print("    Starting registration...");
    
    // Perform registration with error checking (same as original calibration script)
    run("Descriptor-based registration (2d/3d)", 
        "first_image=" + title1 + " second_image=" + title2 + 
        " brightness_of=[Advanced ...] approximate_size=[Advanced ...] " +
        "type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] " +
        "transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] " +
        "number_of_neighbors=3 redundancy=2 significance=3 allowed_error_for_ransac=6 " +
        "choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 " +
        "create_overlayed add_point_rois interpolation=[Linear Interpolation] " +
        "detection_sigma=3.9905 threshold=0.0537");
    
    // Check registration success
    fused_title = "Fused " + file1 + " & " + file2;
    print("    Looking for fused image: " + fused_title);
    print("    Current open images: " + nImages());
    
    // List all open images for debugging
    if (nImages() > 0) {
        print("    Open image titles:");
        for (img = 1; img <= nImages(); img++) {
            selectImage(img);
            print("      " + img + ": " + getTitle());
        }
    }
    
    if (!isOpen(fused_title)) {
        print("    Registration failed - fused image not found");
        close("*");
        return false;
    }
    
    print("    Registration successful, continuing with processing...");
    
    // Continue with optimized processing pipeline
    result = processCalibrationFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1, file2, threshold_value);
    
    if (result) {
        print("    Successfully processed pair: " + fullFileName);
    } else {
        print("    Failed during post-registration processing: " + fullFileName);
    }
    
    return result;
}

function processCalibrationFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1, file2, threshold_value) {
    selectWindow(fused_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
    
    // Split channels
    run("Split Channels");
    
    c1_title = "C1-" + fused_title;
    c2_title = "C2-" + fused_title;
    
    if (!isOpen(c1_title) || !isOpen(c2_title)) {
        return false;
    }
    
    // Save split channels
    selectWindow(c1_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Split/C1Fused/C1-Fused " + file1 + " & " + file2);
    
    selectWindow(c2_title);
    saveAs("jpg", processed_dir + "Split/C2Fused/C2-Fused " + file1 + " & " + file2);
    
    // Calculate difference with correct syntax
    imageCalculator("Difference create", c1_title, c2_title);
    
    // The result window name follows ImageJ convention
    diff_title = "Result of " + c1_title;
    
    if (!isOpen(diff_title)) {
        return false;
    }
    
    // Process difference image with optimized cropping AND THRESHOLD TESTING
    return processOptimizedDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value);
}

function processOptimizedDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value) {
    selectWindow(diff_title);
    saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
    
    // Get dimensions and calculate crop in one step (same as original)
    getDimensions(width, height, channels, slices, frames);
    new_width = floor(width * 0.8);
    new_x = floor(width * 0.1);
    new_height = floor(height * 0.8);
    new_y = floor(height * 0.1);
    
    // Apply crop
    run("Specify...", "width=" + new_width + " height=" + new_height + " x=" + new_x + " y=" + new_y);
    run("Crop");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Save progressive versions (following original calibration script exactly)
    saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
    run("8-bit");
    saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
    
    // Apply threshold and analyze (THIS IS THE KEY DIFFERENCE - TESTING DIFFERENT THRESHOLDS)
    // Original script used setThreshold(62, 255) - we're testing different values
    setThreshold(threshold_value, 255);
    saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName);
    run("Convert to Mask");
    saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName);
    
    // Set measurements and analyze particles (same as original calibration processing)
    run("Set Measurements...", "area bounding redirect=None decimal=3");
    run("Analyze Particles...", "show=Masks display exclude include summarize");
    
    // Save final results (same as original calibration script)
    saveAs("jpg", processed_dir + "Finished/" + fullFileName);
    edgeFileName = "Edge" + fullFileName;
    saveAs("jpg", processed_dir + "Edge/" + edgeFileName);
    
    return true;
}

// ============================================================================
// STEP 3: Full Calibration Image Processing with Threshold Testing
// ============================================================================

function createAllCalibrationSubdirectories(out_dir, processed_dir) {
    File.makeDirectory(out_dir);
    File.makeDirectory(processed_dir);
    
    // Use the same subdirectory names as the original calibration script
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", 
                      "Split/C1Fused", "Split/C2Fused", "Difference", "Crop", 
                      "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", 
                      "Finished", "Edge", "Errors");
                      
    for (i = 0; i < subdirs.length; i++) {
        File.makeDirectory(processed_dir + subdirs[i]);
    }
}

function addOptimizedSummaryData(comparison_folder, bef_folder_name, aft_folder_name) {
    // Check if Summary table exists
    if (!isOpen("Summary")) {
        print("Summary table not found - skipping enhanced data addition");
        return;
    }
    
    num_summary_rows = Table.size("Summary");
    
    if (num_summary_rows == 0) {
        print("Summary table is empty - cannot add additional data");
        return;
    }
    
    print("Adding dimension analysis and median brightness data to summary...");
    
    // Batch add all columns at once (same as original calibration script)
    column_names = newArray("image_name", "edge_image_name", "finished_width", "finished_height",
                           "edge_width", "edge_height", "width_difference", "height_difference",
                           "Pre_Brightness_Lower", "Pre_Brightness_Upper", "Pre_Brightness_Entire",
                           "Post_Brightness_Lower", "Post_Brightness_Upper", "Post_Brightness_Entire");
    
    for (col = 0; col < column_names.length; col++) {
        for (row = 0; row < num_summary_rows; row++) {
            Table.set(column_names[col], row, 0, "Summary");
        }
    }
    
    // Fill data efficiently
    addOptimizedDimensionData(comparison_folder, num_summary_rows);
    addOptimizedMedianData(File.getParent(comparison_folder) + "/", num_summary_rows);
}

function addOptimizedDimensionData(comparison_folder, num_summary_rows) {
    processed_images_path = comparison_folder + "Processed Images/";
    finishedImagesPath = processed_images_path + "Finished/";
    edgeImagesPath = processed_images_path + "Edge/";
    
    if (!File.isDirectory(finishedImagesPath) || !File.isDirectory(edgeImagesPath)) {
        return;
    }
    
    // Cache dimension data for batch processing
    finishedImageList = getFileList(finishedImagesPath);
    
    for (row = 0; row < Math.min(num_summary_rows, finishedImageList.length); row++) {
        if (isImageFile(finishedImageList[row])) {
            finishedImagePath = finishedImagesPath + finishedImageList[row];
            edgeFilename = getEdgeFilename(finishedImageList[row]);
            edgeImagePath = edgeImagesPath + edgeFilename;
            
            if (File.exists(edgeImagePath)) {
                finishedDims = getImageDimensions(finishedImagePath);
                edgeDims = getImageDimensions(edgeImagePath);
                
                // Store all dimension data at once
                Table.set("image_name", row, finishedImageList[row], "Summary");
                Table.set("edge_image_name", row, edgeFilename, "Summary");
                Table.set("finished_width", row, finishedDims[0], "Summary");
                Table.set("finished_height", row, finishedDims[1], "Summary");
                Table.set("edge_width", row, edgeDims[0], "Summary");
                Table.set("edge_height", row, edgeDims[1], "Summary");
                Table.set("width_difference", row, finishedDims[0] - edgeDims[0], "Summary");
                Table.set("height_difference", row, finishedDims[1] - edgeDims[1], "Summary");
            }
        }
    }
}

function addOptimizedMedianData(out_dir, num_summary_rows) {
    // Load median info from brightness standardization step
    // Get the analysis directory from the current out_dir path
    analysis_dir_path = out_dir;
    while (!endsWith(analysis_dir_path, "Calibration_Threshold_Analysis/")) {
        analysis_dir_path = File.getParent(analysis_dir_path) + "/";
        if (lengthOf(analysis_dir_path) < 10) break; // Safety check
    }
    
    brightness_dir = analysis_dir_path + "Brightness_Corrected/";
    median_info = loadGlobalMedianInfo(brightness_dir);
    if (median_info.length == 0) return;
    
    // Parse and cache all median data
    bef_data_cache = newArray(0);
    
    for (i = 0; i < median_info.length; i++) {
        if (median_info[i] != "") {
            info_parts = split(median_info[i], "|");
            if (info_parts.length >= 8 && startsWith(info_parts[0], "Bef_")) {
                bef_data_cache = Array.concat(bef_data_cache, median_info[i]);
            }
        }
    }
    
    // Batch update all median columns
    for (row = 0; row < Math.min(num_summary_rows, bef_data_cache.length); row++) {
        bef_parts = split(bef_data_cache[row], "|");
        if (bef_parts.length >= 8) {
            Table.set("Pre_Brightness_Lower", row, parseFloat(bef_parts[3]), "Summary");
            Table.set("Pre_Brightness_Upper", row, parseFloat(bef_parts[2]), "Summary");
            Table.set("Pre_Brightness_Entire", row, parseFloat(bef_parts[4]), "Summary");
            Table.set("Post_Brightness_Lower", row, parseFloat(bef_parts[6]), "Summary");
            Table.set("Post_Brightness_Upper", row, parseFloat(bef_parts[5]), "Summary");
            Table.set("Post_Brightness_Entire", row, parseFloat(bef_parts[7]), "Summary");
        }
    }
}

function saveResultsTablesForThreshold(out_dir, in_dir_1, in_dir_2, threshold_value) {
    base_name = File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2);
    
    if (isOpen("Results")) {
        Table.save(out_dir + "Particles " + base_name + ".csv", "Results");
        Table.reset("Results");
        print("Saved Results table");
    } else {
        print("No Results table to save");
    }
    
    if (isOpen("Summary")) {
        Table.save(out_dir + "Summary " + base_name + "_updated.csv", "Summary");
        Table.reset("Summary");
        print("Saved Summary table");
    } else {
        print("No Summary table to save");
    }
}

function loadGlobalMedianInfo(out_dir) {
    median_file_path = out_dir + "median_brightness_data.txt";
    
    if (File.exists(median_file_path)) {
        file_content = File.openAsString(median_file_path);
        if (file_content != "") {
            return split(file_content, "\n");
        }
    }
    
    return newArray(0);
}

function getImageDimensions(imagePath) {
    dimensions = newArray(2);
    if (File.exists(imagePath)) {
        open(imagePath);
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
    // More efficient string replacement
    if (startsWith(finishedName, "Difference")) {
        return "Edge" + substring(finishedName, 10); // "Difference" is 10 characters
    }
    return "Edge" + finishedName;
}

function logError(message, processed_dir) {
    print("Error: " + message);
    // Simple error logging to avoid file read issues
    error_log_path = processed_dir + "Errors/error_log.txt";
    File.makeDirectory(processed_dir + "Errors/");
    File.append("Error: " + message + "\n", error_log_path);
}

// ============================================================================
// STEP 4: Dimension Analysis for All Thresholds
// ============================================================================

function cachedAnalyzeDimensionsForAllThresholds(analysis_dir) {
    print("Running dimension analysis for all thresholds...");
    
    // Get all threshold directories
    threshold_dirs = getFileList(analysis_dir);
    
    for (i = 0; i < threshold_dirs.length; i++) {
        if (startsWith(threshold_dirs[i], "Threshold_") && endsWith(threshold_dirs[i], "/")) {
            threshold_dir = analysis_dir + threshold_dirs[i];
            print("  Processing dimension analysis for: " + threshold_dirs[i]);
            
            // Get all comparison folders within this threshold directory
            comparison_folders = getFileList(threshold_dir);
            
            for (j = 0; j < comparison_folders.length; j++) {
                if (endsWith(comparison_folders[j], "/")) {
                    comparison_folder = threshold_dir + comparison_folders[j];
                    summaryFilePath = findSummaryFile(comparison_folder);
                    
                    if (summaryFilePath == "") continue;
                    
                    // Check if already processed
                    updatedSummaryPath = substring(summaryFilePath, 0, lastIndexOf(summaryFilePath, ".")) + "_updated.csv";
                    if (File.exists(updatedSummaryPath)) {
                        print("    Skipping already processed folder: " + comparison_folders[j]);
                        continue;
                    }
                    
                    processCachedDimensionAnalysis(comparison_folder, summaryFilePath, updatedSummaryPath);
                }
            }
        }
    }
    
    print("Cached dimension analysis complete for all thresholds.");
}

function findSummaryFile(dir) {
    list = getFileList(dir);
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "Summary")) {
            return dir + list[i];
        }
    }
    return "";
}

function processCachedDimensionAnalysis(subfolder, summaryFilePath, updatedSummaryPath) {
    finishedImagesPath = subfolder + "Processed Images" + File.separator + "Finished" + File.separator;
    edgeImagesPath = subfolder + "Processed Images" + File.separator + "Edge" + File.separator;
    
    finishedImageList = getFileList(finishedImagesPath);
    if (finishedImageList.length == 0) return;
    
    // Cache all dimension data first
    Table.create("Dimension Data");
    rowIndex = 0;
    
    for (j = 0; j < finishedImageList.length; j++) {
        if (isImageFile(finishedImageList[j])) {
            finishedImagePath = finishedImagesPath + finishedImageList[j];
            edgeFilename = getEdgeFilename(finishedImageList[j]);
            edgeImagePath = edgeImagesPath + edgeFilename;
            
            finishedDimensions = getImageDimensions(finishedImagePath);
            edgeDimensions = getImageDimensions(edgeImagePath);
            
            // Store all data at once
            Table.set("image_name", rowIndex, finishedImageList[j]);
            Table.set("edge_image_name", rowIndex, edgeFilename);
            Table.set("finished_width", rowIndex, finishedDimensions[0]);
            Table.set("finished_height", rowIndex, finishedDimensions[1]);
            Table.set("edge_width", rowIndex, edgeDimensions[0]);
            Table.set("edge_height", rowIndex, edgeDimensions[1]);
            Table.set("width_difference", rowIndex, finishedDimensions[0] - edgeDimensions[0]);
            Table.set("height_difference", rowIndex, finishedDimensions[1] - edgeDimensions[1]);
            rowIndex++;
        }
    }
    
    if (rowIndex > 0) {
        updateSummaryFileOptimized(summaryFilePath, updatedSummaryPath);
    }
    
    Table.reset("Dimension Data");
}

function updateSummaryFileOptimized(summaryFilePath, updatedSummaryPath) {
    summaryFile = File.openAsString(summaryFilePath);
    summaryLines = split(summaryFile, "\n");
    
    if (summaryLines.length <= 1) return;
    
    // Get all column data from cache
    imageNameColumn = Table.getColumn("image_name");
    edgeImageNameColumn = Table.getColumn("edge_image_name");
    finishedWidthColumn = Table.getColumn("finished_width");
    finishedHeightColumn = Table.getColumn("finished_height");
    edgeWidthColumn = Table.getColumn("edge_width");
    edgeHeightColumn = Table.getColumn("edge_height");
    widthDiffColumn = Table.getColumn("width_difference");
    heightDiffColumn = Table.getColumn("height_difference");
    
    // Batch update summary file
    headerFields = split(summaryLines[0], ",");
    newHeaders = newArray("image_name", "edge_image_name", "finished_width", "finished_height", 
                         "edge_width", "edge_height", "width_difference", "height_difference");
    headerFields = Array.concat(headerFields, newHeaders);
    summaryLines[0] = String.join(headerFields, ",");
    
    // Update all rows efficiently
    for (k = 1; k < summaryLines.length; k++) {
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
    File.saveString(updatedSummary, updatedSummaryPath);
}// Complete Calibration Processing Threshold Analysis from Bef/Aft Folders
// Runs the full calibration processing pipeline (brightness standardization + registration + difference + threshold analysis)
// Tests different thresholds to find optimal value for calibration edge detection

setBatchMode(true);
run("Close All");

// User selects the parent directory containing Bef_xx and Aft_xx folders
parent_dir = getDirectory("Choose the parent directory containing Bef_xx and Aft_xx folders");
print("=== CALIBRATION PROCESSING THRESHOLD ANALYSIS ===");
print("Parent directory: " + parent_dir);

// Test range of thresholds around the current calibration threshold (62)
test_thresholds = newArray(45, 50, 55, 58, 59, 60, 61, 62, 63, 64, 65, 70, 75, 80);

// Find all Bef/Aft folder pairs
folder_pairs = buildProcessingQueue(parent_dir);
if (folder_pairs.length == 0) {
    print("No matching Bef_xx and Aft_xx folder pairs found!");
    exit();
}

print("Found " + folder_pairs.length + " folder pairs to process");
print("Testing " + test_thresholds.length + " threshold values: " + arrayToString(test_thresholds));

// Create main output directory
analysis_dir = parent_dir + "Calibration_Threshold_Analysis/";
File.makeDirectory(analysis_dir);

// Arrays to store results across all thresholds
var all_results = newArray(0);
var summary_data = newArray(0);
var qualification_results = newArray(0);

// STEP 1: File Renaming (only needs to be done once)
print("\n=== STEP 1: BATCH RENAMING FILES ===");
batchRenameBefFiles(parent_dir, folder_pairs);

// STEP 2: Brightness Standardization (only needs to be done once)
print("\n=== STEP 2: BRIGHTNESS STANDARDIZATION ===");
brightness_out_dir = analysis_dir + "Brightness_Corrected/";
File.makeDirectory(brightness_out_dir);
optimizedStandardizeBrightness(parent_dir, folder_pairs, brightness_out_dir);

// STEP 3: Process each threshold with the full calibration pipeline
for (t = 0; t < test_thresholds.length; t++) {
    current_threshold = test_thresholds[t];
    print("\n=== PROCESSING THRESHOLD: " + current_threshold + " (" + (t+1) + "/" + test_thresholds.length + ") ===");
    
    // Create output directory for this threshold
    threshold_dir = analysis_dir + "Threshold_" + current_threshold + "/";
    File.makeDirectory(threshold_dir);
    
    // Clear global results for this threshold
    if (isOpen("Results")) {
        Table.reset("Results");
    }
    if (isOpen("Summary")) {
        Table.reset("Summary");
    }
    
    // Process each folder pair with current threshold using FULL calibration pipeline
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        print("Processing pair " + (i+1) + "/" + folder_pairs.length + ": " + bef_folder + " vs " + aft_folder);
        
        // Run complete calibration processing with current threshold
        processCalibrationPairWithThreshold(brightness_out_dir + bef_folder, brightness_out_dir + aft_folder, 
                                          threshold_dir, current_threshold);
        
        // Memory management
        if (i % 3 == 0) {
            run("Collect Garbage");
        }
    }
    
    // Save results for this threshold
    saveThresholdResults(threshold_dir, current_threshold, folder_pairs.length);
    
    // Run calibration-specific analysis for this threshold
    runCalibrationAnalysisForThreshold(threshold_dir, current_threshold);
    
    // Calculate summary statistics for this threshold
    calculateThresholdSummary(current_threshold);
}

// STEP 4: Dimension Analysis for all thresholds
print("\n=== STEP 4: DIMENSION ANALYSIS FOR ALL THRESHOLDS ===");
cachedAnalyzeDimensionsForAllThresholds(analysis_dir);

// Create final analysis files
createFinalCalibrationAnalysis(analysis_dir);

print("\n=== CALIBRATION THRESHOLD ANALYSIS COMPLETE ===");
print("Results saved to: " + analysis_dir);
print("Review both quantitative data and visual results to select optimal threshold.");

setBatchMode(false);

// ============================================================================
// MAIN PROCESSING FUNCTIONS
// ============================================================================

function buildProcessingQueue(parent_dir) {
    folder_list = getFileList(parent_dir);
    folder_pairs = newArray(0);
    
    for (i = 0; i < folder_list.length; i++) {
        if (startsWith(folder_list[i], "Bef_")) {
            bef_folder = folder_list[i];
            aft_folder = "Aft_" + substring(bef_folder, 4);
            
            if (File.exists(parent_dir + aft_folder)) {
                folder_pairs = Array.concat(folder_pairs, bef_folder + "|" + aft_folder);
            }
        }
    }
    return folder_pairs;
}

// ============================================================================
// STEP 1: File Renaming (from original calibration script)
// ============================================================================

function batchRenameBefFiles(parent_dir, folder_pairs) {
    // Process all Bef folders in one pass
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        optimizedProcessFolder(parent_dir + bef_folder);
    }
    print("Batch file renaming complete!");
}

function optimizedProcessFolder(folder_path) {
    // Get all files at once and batch process
    file_list = getFileList(folder_path);
    rename_operations = newArray(0);
    
    // Build rename operation list first
    for (i = 0; i < file_list.length; i++) {
        old_name = file_list[i];
        dot_index = lastIndexOf(old_name, ".");
        if (dot_index != -1) {
            new_name = substring(old_name, 0, dot_index) + "0" + substring(old_name, dot_index);
            rename_operations = Array.concat(rename_operations, old_name + "|" + new_name);
        }
    }
    
    // Execute all renames in batch
    for (i = 0; i < rename_operations.length; i++) {
        operation = split(rename_operations[i], "|");
        if (File.exists(folder_path + operation[0]) && !File.exists(folder_path + operation[1])) {
            File.rename(folder_path + operation[0], folder_path + operation[1]);
        }
    }
    
    print("Batch processed folder: " + folder_path + " (" + rename_operations.length + " files)");
}

// ============================================================================
// STEP 2: Brightness Standardization (from original calibration script)
// ============================================================================

function optimizedStandardizeBrightness(parent_dir, folder_pairs, out_dir) {
    // Set measurements once globally
    run("Set Measurements...", "area center perimeter bounding fit shape feret's skewness area_fraction median redirect=None decimal=3");
    
    // Create output directory structure
    File.makeDirectory(out_dir);
    
    // Process all folders with optimized memory management
    all_median_info = newArray(0);
    
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        // Process both folders in sequence to maintain memory locality
        bef_median_info = optimizedProcessBrightnessFolder(parent_dir + bef_folder, bef_folder, out_dir);
        aft_median_info = optimizedProcessBrightnessFolder(parent_dir + aft_folder, aft_folder, out_dir);
        
        all_median_info = Array.concat(all_median_info, bef_median_info);
        all_median_info = Array.concat(all_median_info, aft_median_info);
        
        // Periodic memory cleanup
        if (i % 5 == 0) {
            run("Collect Garbage");
        }
    }
    
    // Store all median info once
    storeGlobalMedianInfo(all_median_info, out_dir);
    print("Optimized brightness standardization complete!");
}

function optimizedProcessBrightnessFolder(folder_path, folder_name, out_dir) {
    file_list = getFileList(folder_path);
    Array.sort(file_list);
    
    // Pre-filter to image files only
    image_files = newArray(0);
    for (i = 0; i < file_list.length; i++) {
        if (isImageFile(file_list[i])) {
            image_files = Array.concat(image_files, file_list[i]);
        }
    }
    
    if (image_files.length == 0) {
        print("No image files found in " + folder_name);
        return newArray(0);
    }
    
    print("Processing brightness for folder: " + folder_name + " (" + image_files.length + " images)");
    
    // Pre-create output directory
    corrected_image_path = out_dir + folder_name + "/";
    File.makeDirectory(corrected_image_path);
    
    median_info = newArray(0);
    
    for (j = 0; j < image_files.length; j++) {
        current_file = image_files[j];
        showProgress(j+1, image_files.length);
        
        // Optimized image processing
        open(folder_path + current_file);
        image_title = getTitle();
        
        // Get dimensions once
        getDimensions(width, height, channels, slices, frames);
        
        // Calculate region parameters once
        upper_30_height = floor(height * 0.3);
        lower_30_height = floor(height * 0.3);
        lower_y = height - lower_30_height;
        
        // Batch measure all regions
        original_medians = batchMeasureRegions(width, height, upper_30_height, lower_y, lower_30_height);
        
        // Apply optimized transformation
        run("32-bit");
        optimizedApplyTransformation(original_medians[0], original_medians[1]);
        
        // Batch measure post-transformation
        post_medians = batchMeasureRegions(width, height, upper_30_height, lower_y, lower_30_height);
        
        // Store median information efficiently
        median_info = Array.concat(median_info, 
            folder_name + "|" + current_file + "|" + 
            original_medians[0] + "|" + original_medians[1] + "|" + original_medians[2] + "|" +
            post_medians[0] + "|" + post_medians[1] + "|" + post_medians[2]);
        
        // Save and cleanup
        run("8-bit");
        saveAs("jpg", corrected_image_path + current_file);
        close("*");
        
        // Clear results periodically
        if (j % 10 == 0) {
            run("Clear Results");
        }
    }
    
    // Final cleanup
    run("Clear Results");
    return median_info;
}

function batchMeasureRegions(width, height, upper_30_height, lower_y, lower_30_height) {
    medians = newArray(3);
    
    // Measure upper 30% region
    makeRectangle(0, 0, width, upper_30_height);
    run("Measure");
    medians[0] = getResult("Median", nResults-1);
    
    // Measure lower 30% region
    makeRectangle(0, lower_y, width, lower_30_height);
    run("Measure");
    medians[1] = getResult("Median", nResults-1);
    
    // Measure entire image
    run("Select All");
    run("Measure");
    medians[2] = getResult("Median", nResults-1);
    
    return medians;
}

function optimizedApplyTransformation(upper_median, lower_median) {
    // Skip transformation if regions are identical
    if (upper_median == lower_median) {
        return;
    }
    
    target_light = 200;
    target_dark = 10;
    threshold = (upper_median + lower_median) / 2;
    
    print("Applying optimized threshold-based transformation:");
    print("  Upper median: " + upper_median + ", Lower median: " + lower_median);
    print("  Threshold: " + threshold);
    
    // Get current image info
    original_title = getTitle();
    getDimensions(width, height, channels, slices, frames);
    
    // Create a more efficient pixel-wise transformation
    run("Duplicate...", "title=result_image");
    result_title = getTitle();
    
    // Process in blocks for better performance
    block_size = 50;
    for (y = 0; y < height; y += block_size) {
        for (x = 0; x < width; x += block_size) {
            // Process block
            end_y = Math.min(y + block_size, height);
            end_x = Math.min(x + block_size, width);
            
            for (by = y; by < end_y; by++) {
                for (bx = x; bx < end_x; bx++) {
                    selectWindow(original_title);
                    pixel_value = getPixel(bx, by);
                    
                    if (pixel_value >= threshold) {
                        new_value = target_light;
                    } else {
                        new_value = target_dark;
                    }
                    
                    selectWindow(result_title);
                    setPixel(bx, by, new_value);
                }
            }
        }
        
        // Show progress for blocks
        if (y % 200 == 0) {
            showProgress(y, height);
        }
    }
    
    // Copy result back to original
    selectWindow(result_title);
    run("Select All");
    run("Copy");
    
    selectWindow(original_title);
    run("Select All");
    run("Paste");
    
    // Clean up
    selectWindow(result_title);
    close();
    selectWindow(original_title);
    
    print("  Optimized transformation complete");
}

function storeGlobalMedianInfo(median_info, out_dir) {
    median_file_path = out_dir + "median_brightness_data.txt";
    
    // Build single string and write once (much faster than multiple appends)
    output_string = "";
    for (i = 0; i < median_info.length; i++) {
        output_string += median_info[i] + "\n";
    }
    
    File.saveString(output_string, median_file_path);
    print("Stored median brightness data for " + median_info.length + " images");
}

function processCalibrationPairWithThreshold(in_dir_1, in_dir_2, threshold_dir, threshold_value) {
    // Get and sort file lists
    ls_1 = getFileList(in_dir_1);
    ls_2 = getFileList(in_dir_2);
    Array.sort(ls_1);
    Array.sort(ls_2);
    
    // Filter to image files
    image_files_1 = filterImageFiles(ls_1);
    image_files_2 = filterImageFiles(ls_2);
    
    // Setup output directories for this threshold
    folderName = File.getNameWithoutExtension(in_dir_1) + "_minus_" + File.getNameWithoutExtension(in_dir_2);
    out_dir = threshold_dir + folderName + "/";
    processed_dir = out_dir + "Processed_Images/";
    
    // Create all subdirectories
    createAllSubdirectories(out_dir, processed_dir);
    
    // Process image pairs
    num_pairs = minOf(image_files_1.length, image_files_2.length);
    
    for (i = 0; i < num_pairs; i++) {
        showProgress(i+1, num_pairs);
        
        processCalibrationImagePairSingleWithThreshold(in_dir_1, in_dir_2, image_files_1[i], image_files_2[i], 
                                                      processed_dir, threshold_value);
        
        // Cleanup memory
        if (i % 5 == 0) {
            run("Close All");
            run("Collect Garbage");
        }
    }
    
    // Save results for this pair
    saveResultsTables(out_dir, in_dir_1, in_dir_2, threshold_value);
}

function processCalibrationImagePairSingleWithThreshold(in_dir_1, in_dir_2, file1_name, file2_name, processed_dir, threshold_value) {
    file1 = File.getNameWithoutExtension(file1_name);
    file2 = File.getNameWithoutExtension(file2_name);
    fullFileName = file1 + "minus" + file2;
    
    print("  Processing: " + file1_name + " & " + file2_name + " with threshold " + threshold_value);
    
    // Check if input files exist
    if (!File.exists(in_dir_1 + file1_name) || !File.exists(in_dir_2 + file2_name)) {
        print("    Input files not found, skipping");
        return false;
    }
    
    // Load and prepare first image
    open(in_dir_1 + file1_name);
    if (nImages() == 0) {
        print("    Failed to open first image");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit clean/8bit" + file1);
    title1 = getTitle();
    
    // Load and prepare second image
    open(in_dir_2 + file2_name);
    if (nImages() != 2) {
        close("*");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit dirty/8bit" + file2);
    title2 = getTitle();
    
    // Perform registration (same as calibration pipeline)
    print("    Starting registration...");
    run("Descriptor-based registration (2d/3d)", 
        "first_image=" + title1 + " second_image=" + title2 + 
        " brightness_of=[Advanced ...] approximate_size=[Advanced ...] " +
        "type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] " +
        "transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] " +
        "number_of_neighbors=3 redundancy=2 significance=3 allowed_error_for_ransac=6 " +
        "choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 " +
        "create_overlayed add_point_rois interpolation=[Linear Interpolation] " +
        "detection_sigma=3.9905 threshold=0.0537");
    
    // Check registration success
    fused_title = "Fused " + file1 + " & " + file2;
    if (!isOpen(fused_title)) {
        print("    Registration failed");
        close("*");
        return false;
    }
    
    // Process fused image with specific threshold (calibration workflow)
    processCalibrationFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1, file2, threshold_value);
    
    return true;
}

function processCalibrationFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1, file2, threshold_value) {
    selectWindow(fused_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
    
    // Split channels
    run("Split Channels");
    
    c1_title = "C1-" + fused_title;
    c2_title = "C2-" + fused_title;
    
    if (!isOpen(c1_title) || !isOpen(c2_title)) {
        return false;
    }
    
    // Save split channels
    selectWindow(c1_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Split/C1Fused/C1-Fused " + file1 + " & " + file2);
    
    selectWindow(c2_title);
    saveAs("jpg", processed_dir + "Split/C2Fused/C2-Fused " + file1 + " & " + file2);
    
    // Calculate difference
    imageCalculator("Difference create", c1_title, c2_title);
    diff_title = "Result of " + c1_title;
    
    if (!isOpen(diff_title)) {
        return false;
    }
    
    // Process difference image with specific threshold (calibration workflow)
    processCalibrationDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value);
    
    return true;
}

function processCalibrationDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value) {
    selectWindow(diff_title);
    saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
    
    // Get dimensions and calculate crop (same as calibration pipeline)
    getDimensions(width, height, channels, slices, frames);
    new_width = floor(width * 0.8);
    new_x = floor(width * 0.1);
    new_height = floor(height * 0.8);
    new_y = floor(height * 0.1);
    
    // Apply crop
    run("Specify...", "width=" + new_width + " height=" + new_height + " x=" + new_x + " y=" + new_y);
    run("Crop");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Save progressive versions (following original calibration script exactly)
    saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
    run("8-bit");
    saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
    
    // Apply the specific threshold being tested (KEY DIFFERENCE - THIS IS WHAT WE'RE TESTING)
    // Note: Original script used setThreshold(62, 255) - we're testing different values
    setThreshold(threshold_value, 255);
    saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName + "_threshold_" + threshold_value);
    
    // Convert to mask (this creates the binary mask)
    run("Convert to Mask");
    saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName + "_mask_" + threshold_value);
    
    // Set measurements and analyze particles (this creates the Edge image)
    run("Set Measurements...", "area bounding redirect=None decimal=3");
    run("Analyze Particles...", "show=Masks display exclude include summarize");
    
    // According to original script, there should now be a "Mask of..." window
    // This is the actual Edge image that gets processed for coordinates
    mask_window_title = "Mask of " + diff_title;
    if (isOpen(mask_window_title)) {
        selectWindow(mask_window_title);
        saveAs("jpg", processed_dir + "Finished/" + fullFileName + "_threshold_" + threshold_value);
        
        // THIS is the correct Edge image - the result of "Analyze Particles"
        edgeFileName = "Edge" + fullFileName + "_threshold_" + threshold_value;
        saveAs("jpg", processed_dir + "Edge/" + edgeFileName);
        
        print("    Created edge image: " + edgeFileName + " from window: " + mask_window_title);
    } else {
        // Fallback: if the expected window name is different, use current active window
        saveAs("jpg", processed_dir + "Finished/" + fullFileName + "_threshold_" + threshold_value);
        edgeFileName = "Edge" + fullFileName + "_threshold_" + threshold_value;
        saveAs("jpg", processed_dir + "Edge/" + edgeFileName);
        
        print("    Created edge image: " + edgeFileName + " (fallback method)");
        print("    Available windows: " + nImages());
        if (nImages() > 0) {
            for (w = 1; w <= nImages(); w++) {
                selectImage(w);
                print("      Window " + w + ": " + getTitle());
            }
        }
    }
    
    return true;
}

function runCalibrationAnalysisForThreshold(threshold_dir, threshold_value) {
    print("  Running calibration-specific analysis for threshold " + threshold_value + "...");
    
    // Get all comparison folders for this threshold
    folder_list = getFileList(threshold_dir);
    
    for (i = 0; i < folder_list.length; i++) {
        if (endsWith(folder_list[i], "/")) {
            comparison_folder = threshold_dir + folder_list[i];
            
            // Extract sample number from folder name
            folder_name = substring(folder_list[i], 0, lengthOf(folder_list[i]) - 1);
            if (indexOf(folder_name, "_minus_") != -1) {
                sample_start = indexOf(folder_name, "Bef_") + 4;
                sample_end = indexOf(folder_name, "_minus_");
                if (sample_start > 3 && sample_end > sample_start) {
                    sample_number = substring(folder_name, sample_start, sample_end);
                    
                    // Run calibration edge coordinate extraction
                    extractCalibrationEdgeCoordinates(comparison_folder, threshold_value);
                    
                    // Map particles to slices and qualify them
                    mapParticlesToSlicesForThreshold(comparison_folder, sample_number, threshold_value);
                    qualifyCalibrationParticlesForThreshold(comparison_folder, sample_number, threshold_value);
                }
            }
        }
    }
}

function extractCalibrationEdgeCoordinates(comparison_folder, threshold_value) {
    processed_images_path = comparison_folder + "Processed_Images/";
    edge_path = processed_images_path + "Edge/";
    
    print("    Extracting edge coordinates from: " + edge_path);
    
    // Create shorter folder name for edge coordinates
    new_edge_dir = processed_images_path + "EdgeCoords_T" + threshold_value + "/";
    File.makeDirectory(new_edge_dir);
    
    // Check if Edge folder exists and process files
    if (!File.exists(edge_path)) {
        print("    Edge folder does not exist: " + edge_path);
        return;
    }
    
    edge_files = getFileList(edge_path);
    print("    Found " + edge_files.length + " files in Edge folder");
    
    // Process each edge image file
    edge_files_processed = 0;
    for (j = 0; j < edge_files.length; j++) {
        if (endsWith(toLowerCase(edge_files[j]), ".tif") || 
            endsWith(toLowerCase(edge_files[j]), ".jpg") || 
            endsWith(toLowerCase(edge_files[j]), ".png") || 
            endsWith(toLowerCase(edge_files[j]), ".bmp")) {
            
            print("    Processing edge file: " + edge_files[j]);
            
            // Open and process image
            full_path = edge_path + edge_files[j];
            if (!File.exists(full_path)) {
                print("      File does not exist: " + full_path);
                continue;
            }
            
            open(full_path);
            original_title = getTitle();
            print("      Opened image: " + original_title);
            
            // Check if image is already binary or needs conversion
            run("8-bit");
            
            // Get some pixel statistics to understand the image
            run("Set Measurements...", "min redirect=None decimal=3");
            run("Measure");
            if (nResults > 0) {
                min_val = getResult("Min", nResults-1);
                max_val = getResult("Max", nResults-1);
                print("      Image pixel range: " + min_val + " to " + max_val);
                run("Clear Results");
            }
            
            // Convert to mask (ensure binary)
            run("Convert to Mask");
            
            // Get image dimensions
            width = getWidth();
            height = getHeight();
            print("      Image dimensions: " + width + " x " + height);
            
            // Find edge coordinates using same method as calibration script
            max_y = newArray(width);
            Array.fill(max_y, -1);
            
            // Process columns to find last edge transitions
            edge_transitions_found = 0;
            for (x = 0; x < width; x++) {
                last_edge = -1;
                transitions_in_column = 0;
                
                for (y = 0; y < height; y++) {
                    current_pixel = getPixel(x, y);
                    if (y > 0) {
                        previous_pixel = getPixel(x, y-1);
                        // Check for both black-to-white and white-to-black transitions
                        if ((previous_pixel == 0 && current_pixel == 255) || 
                            (previous_pixel == 255 && current_pixel == 0)) {
                            last_edge = y;
                            transitions_in_column++;
                        }
                    }
                }
                if (last_edge > -1) {
                    max_y[x] = last_edge;
                    edge_transitions_found++;
                }
                
                // Debug first few columns
                if (x < 5) {
                    print("        Column " + x + ": " + transitions_in_column + " transitions, last edge at y=" + last_edge);
                }
            }
            
            print("      Found edge coordinates in " + edge_transitions_found + " columns out of " + width);
            
            // Create shorter output filename - remove threshold suffix
            base_name = substring(edge_files[j], 0, lastIndexOf(edge_files[j], "."));
            // Remove any existing threshold info from base name
            if (indexOf(base_name, "_threshold_") != -1) {
                base_name = substring(base_name, 0, indexOf(base_name, "_threshold_"));
            }
            output_file = new_edge_dir + base_name + "_edges.csv";
            
            // Write results
            buffer = "X,Y\n";
            coord_count = 0;
            for (x = 0; x < width; x++) {
                if (max_y[x] >= 0) {
                    buffer = buffer + x + "," + max_y[x] + "\n";
                    coord_count++;
                }
            }
            
            // Write buffer to file
            File.saveString(buffer, output_file);
            print("      Extracted " + coord_count + " edge coordinates to: " + output_file);
            
            // Clean up
            close();
            edge_files_processed++;
        } else {
            print("    Skipping non-image file: " + edge_files[j]);
        }
    }
    
    print("    Processed " + edge_files_processed + " edge image files");
}

function mapParticlesToSlicesForThreshold(comparison_folder, sample_number, threshold_value) {
    // Find particles and summary files with threshold suffix
    particles_file = comparison_folder + "Particles_Bef_" + sample_number + "_minus_Aft_" + sample_number + "_threshold_" + threshold_value + ".csv";
    summary_file = comparison_folder + "Summary_Bef_" + sample_number + "_minus_Aft_" + sample_number + "_threshold_" + threshold_value + ".csv";
    
    if (!File.exists(particles_file) || !File.exists(summary_file)) {
        print("    Required files not found for slice mapping (threshold " + threshold_value + ")");
        return;
    }
    
    // Read files
    particle_lines = split(File.openAsString(particles_file), "\n");
    summary_lines = split(File.openAsString(summary_file), "\n");
    
    if (particle_lines.length < 2 || summary_lines.length < 2) {
        print("    Invalid file format for slice mapping (threshold " + threshold_value + ")");
        return;
    }
    
    // Get Count and Slice columns from summary file
    summary_headers = split(summary_lines[0], ",");
    count_index = -1;
    slice_name_index = -1;
    for (i = 0; i < summary_headers.length; i++) {
        if (summary_headers[i] == "Count") count_index = i;
        if (summary_headers[i] == "Slice") slice_name_index = i;
    }
    
    if (count_index == -1 || slice_name_index == -1) {
        print("    Required columns not found in summary file (threshold " + threshold_value + ")");
        return;
    }
    
    // Create arrays to store valid slices and their cumulative counts
    valid_slices = newArray(1000);
    cumulative_counts = newArray(1000);
    current_total = 0;
    max_valid_slice = -1;
    
    // Process summary data to get valid slices and their cumulative counts
    for (i = 1; i < summary_lines.length; i++) {
        summary_data = split(summary_lines[i], ",");
        if (summary_data.length <= count_index || summary_data.length <= slice_name_index) {
            continue;
        }
        
        // Extract slice identifier from the filename in summary
        slice_name = summary_data[slice_name_index];
        slice_num = extractSliceNumberFromCalibrationFile(slice_name);
        
        if (slice_num == -1 || slice_num >= valid_slices.length) continue;
        
        current_count = parseInt(summary_data[count_index]);
        if (isNaN(current_count)) continue;
        
        // Record valid slice and its cumulative count
        valid_slices[slice_num] = true;
        current_total += current_count;
        cumulative_counts[slice_num] = current_total;
        if (slice_num > max_valid_slice) max_valid_slice = slice_num;
    }
    
    // Add Slice column if it doesn't exist
    if (indexOf(particle_lines[0], "Slice") == -1) {
        particle_lines[0] = particle_lines[0] + ",Slice";
    }
    
    // Process each particle
    new_particle_lines = newArray(particle_lines.length);
    new_particle_lines[0] = particle_lines[0];
    
    for (i = 1; i < particle_lines.length; i++) {
        slice_number = -1;
        particle_index = i;
        
        // Find appropriate slice for this particle
        for (j = 0; j <= max_valid_slice; j++) {
            if (valid_slices[j] && particle_index <= cumulative_counts[j]) {
                slice_number = j;
                break;
            }
        }
        
        // Add slice number to particle data
        if (slice_number == -1) {
            if (endsWith(particle_lines[i], ",")) {
                new_particle_lines[i] = particle_lines[i] + "0";
            } else {
                new_particle_lines[i] = particle_lines[i] + ",0";
            }
        } else {
            if (endsWith(particle_lines[i], ",")) {
                new_particle_lines[i] = particle_lines[i] + slice_number;
            } else {
                new_particle_lines[i] = particle_lines[i] + "," + slice_number;
            }
        }
    }
    
    // Save updated particles file
    File.saveString(String.join(new_particle_lines, "\n"), particles_file);
    print("    Mapped particles to slices for threshold " + threshold_value);
}

function qualifyCalibrationParticlesForThreshold(comparison_folder, sample_number, threshold_value) {
    // Find files with threshold suffix
    particles_file = comparison_folder + "Particles_Bef_" + sample_number + "_minus_Aft_" + sample_number + "_threshold_" + threshold_value + ".csv";
    edge_coord_dir = comparison_folder + "Processed_Images/EdgeCoords_T" + threshold_value + "/";
    
    print("    Looking for particles file: " + particles_file);
    print("    Looking for edge coord dir: " + edge_coord_dir);
    
    if (!File.exists(particles_file)) {
        print("    Particles file not found: " + particles_file);
        return false;
    }
    if (!File.exists(edge_coord_dir)) {
        print("    Edge coordinates directory not found: " + edge_coord_dir);
        return false;
    }
    
    // Read particles file
    particle_lines = split(File.openAsString(particles_file), "\n");
    if (particle_lines.length < 2) {
        print("    Invalid particles file format (threshold " + threshold_value + ")");
        return false;
    }
    
    print("    Found " + (particle_lines.length - 1) + " particles to process");
    
    // Get header indices
    particle_headers = split(particle_lines[0], ",");
    bx_index = -1;
    by_index = -1;
    height_index = -1;
    width_index = -1;
    slice_index = -1;
    is_qualified_index = -1;
    
    for (i = 0; i < particle_headers.length; i++) {
        if (particle_headers[i] == "BX") bx_index = i;
        if (particle_headers[i] == "BY") by_index = i;
        if (particle_headers[i] == "Height") height_index = i;
        if (particle_headers[i] == "Width") width_index = i;
        if (particle_headers[i] == "Slice") slice_index = i;
        if (particle_headers[i] == "IsQualified") is_qualified_index = i;
    }
    
    if (bx_index == -1 || by_index == -1 || height_index == -1 || width_index == -1 || slice_index == -1) {
        print("    Required columns not found in particles file (threshold " + threshold_value + ")");
        print("    Available headers: " + String.join(particle_headers, ", "));
        return false;
    }
    
    // Add IsQualified column if it doesn't exist
    if (is_qualified_index == -1) {
        particle_headers = Array.concat(particle_headers, "IsQualified");
        is_qualified_index = particle_headers.length - 1;
        particle_lines[0] = String.join(particle_headers, ",");
        print("    Added IsQualified column");
    }
    
    // Load edge coordinates using array approach
    edge_coords = newArray(1000);
    for (i = 0; i < edge_coords.length; i++) {
        edge_coords[i] = "";
    }
    
    coord_files = getFileList(edge_coord_dir);
    print("    Found " + coord_files.length + " coordinate files in directory");
    
    // Process edge coordinate files
    coords_loaded = 0;
    for (i = 0; i < coord_files.length; i++) {
        if (endsWith(coord_files[i], ".csv")) {
            print("    Processing coordinate file: " + coord_files[i]);
            slice_num = extractSliceNumberFromCalibrationFile(coord_files[i]);
            print("    Extracted slice number: " + slice_num);
            
            if (slice_num == -1 || slice_num >= edge_coords.length) {
                print("    Invalid slice number, skipping: " + slice_num);
                continue;
            }
            
            edge_data = split(File.openAsString(edge_coord_dir + coord_files[i]), "\n");
            if (edge_data.length < 2) {
                print("    No edge data in file, skipping");
                continue;
            }
            
            coord_array = newArray(edge_data.length - 1);
            for (j = 1; j < edge_data.length; j++) {
                coords = split(edge_data[j], ",");
                if (coords.length >= 2) {
                    scaled_x = parseFloat(coords[0]) * (50.0/240.0);
                    scaled_y = parseFloat(coords[1]) * (50.0/240.0);
                    coord_array[j-1] = d2s(scaled_x,6) + "," + d2s(scaled_y,6);
                }
            }
            edge_coords[slice_num] = String.join(coord_array, ";");
            coords_loaded++;
            print("    Loaded " + (edge_data.length - 1) + " coordinates for slice " + slice_num);
        }
    }
    
    print("    Total coordinate sets loaded: " + coords_loaded);
    
    // Process each particle
    new_particle_lines = newArray(particle_lines.length);
    new_particle_lines[0] = particle_lines[0];
    qualified_count = 0;
    
    for (i = 1; i < particle_lines.length; i++) {
        particle_data = split(particle_lines[i], ",");
        
        // Ensure particle data has enough elements
        while (particle_data.length < particle_headers.length) {
            particle_data = Array.concat(particle_data, "");
        }
        
        if (particle_data.length <= maxOf(bx_index, by_index) || 
            particle_data.length <= maxOf(height_index, width_index)) {
            new_particle_lines[i] = particle_lines[i];
            continue;
        }
        
        // Get particle data
        bx = parseFloat(particle_data[bx_index]);
        by = parseFloat(particle_data[by_index]);
        height = parseFloat(particle_data[height_index]);
        width = parseFloat(particle_data[width_index]);
        slice = parseInt(particle_data[slice_index]);
        
        particle_top = by + height;
        particle_left = bx;
        particle_right = bx + width;
        
        is_qualified = false;
        
        // Debug first few particles
        if (i <= 3) {
            print("    Particle " + i + ": slice=" + slice + ", coords available=" + (edge_coords[slice] != ""));
            print("      Position: left=" + d2s(particle_left,2) + ", right=" + d2s(particle_right,2) + ", top=" + d2s(particle_top,2));
        }
        
        // Check qualification against edge coordinates
        if (!isNaN(slice) && slice >= 0 && slice < edge_coords.length && edge_coords[slice] != "") {
            edge_points = split(edge_coords[slice], ";");
            
            for (p = 0; p < edge_points.length; p++) {
                if (edge_points[p] == "") continue;
                
                coords = split(edge_points[p], ",");
                if (coords.length < 2) continue;
                
                edge_x = parseFloat(coords[0]);
                edge_y = parseFloat(coords[1]);
                
                if (!isNaN(edge_x) && !isNaN(edge_y)) {
                    // Check qualification criteria
                    horizontal_overlap = (edge_x >= particle_left && edge_x <= particle_right);
                    vertical_proximity = ((particle_top + 2) >= edge_y);
                    
                    if (horizontal_overlap && vertical_proximity) {
                        is_qualified = true;
                        if (i <= 3) {
                            print("      QUALIFIED: edge at (" + d2s(edge_x,2) + "," + d2s(edge_y,2) + ")");
                        }
                        break;
                    }
                }
            }
        } else {
            if (i <= 3) {
                print("      No edge coordinates available for slice " + slice);
            }
        }
        
        // Update particle data with qualification status
        particle_data[is_qualified_index] = "" + is_qualified;
        if (is_qualified) qualified_count++;
        
        // Join particle data back into line
        new_particle_lines[i] = String.join(particle_data, ",");
    }
    
    // Save updated particles file
    File.saveString(String.join(new_particle_lines, "\n"), particles_file);
    
    // Store qualification results for analysis
    qualification_line = threshold_value + "," + sample_number + "," + qualified_count + "," + (particle_lines.length-1);
    qualification_results = Array.concat(qualification_results, qualification_line);
    
    print("    Qualified particles for threshold " + threshold_value + ": " + qualified_count + "/" + (particle_lines.length-1));
    return true;
}

function extractSliceNumberFromCalibrationFile(filename) {
    // Use the exact method from the original calibration script
    edge_match = indexOf(filename, "caliwaferedge");
    if (edge_match == -1) return -1;
    
    // Extract number string after "caliwaferedge" (length 13)
    number_str = substring(filename, edge_match + 13, edge_match + 21);
    if (lengthOf(number_str) >= 7) {
        // Take substring starting at position 6 (like original script)
        slice_str = substring(number_str, 6);
        slice_num = parseInt(slice_str);
        if (!isNaN(slice_num)) {
            return slice_num;
        }
    }
    
    return -1;
}

// ============================================================================
// ANALYSIS AND SUMMARY FUNCTIONS
// ============================================================================

function saveThresholdResults(threshold_dir, threshold_value, num_pairs) {
    if (isOpen("Results")) {
        Table.save(threshold_dir + "All_Particles_Threshold_" + threshold_value + ".csv", "Results");
        
        // Store results for global analysis
        if (nResults > 0) {
            for (r = 0; r < nResults; r++) {
                area = getResult("Area", r);
                bx = getResult("BX", r);
                by = getResult("BY", r);
                width = getResult("Width", r);
                height = getResult("Height", r);
                
                result_line = threshold_value + "," + (r+1) + "," + area + "," + bx + "," + by + "," + width + "," + height;
                all_results = Array.concat(all_results, result_line);
            }
        }
    }
    
    if (isOpen("Summary")) {
        Table.save(threshold_dir + "Summary_Threshold_" + threshold_value + ".csv", "Summary");
    }
}

function calculateThresholdSummary(threshold_value) {
    if (isOpen("Results") && nResults > 0) {
        total_particles = nResults;
        total_area = 0;
        min_area = getResult("Area", 0);
        max_area = getResult("Area", 0);
        
        for (r = 0; r < nResults; r++) {
            area = getResult("Area", r);
            total_area += area;
            if (area < min_area) min_area = area;
            if (area > max_area) max_area = area;
        }
        avg_area = total_area / total_particles;
        
        summary_line = threshold_value + "," + total_particles + "," + 
                      d2s(total_area, 3) + "," + d2s(avg_area, 3) + "," + 
                      d2s(min_area, 3) + "," + d2s(max_area, 3);
        summary_data = Array.concat(summary_data, summary_line);
        
        print("Threshold " + threshold_value + " summary: " + total_particles + 
              " particles, avg area: " + d2s(avg_area, 2));
    } else {
        summary_line = threshold_value + ",0,0,0,0,0";
        summary_data = Array.concat(summary_data, summary_line);
        print("Threshold " + threshold_value + " summary: No particles detected");
    }
}

function createFinalCalibrationAnalysis(analysis_dir) {
    print("\nCreating final calibration analysis files...");
    
    // Save detailed results
    detailed_csv = analysis_dir + "Detailed_Results_All_Thresholds.csv";
    detailed_header = "Threshold,Particle_Number,Area,BX,BY,Width,Height\n";
    File.saveString(detailed_header, detailed_csv);
    for (i = 0; i < all_results.length; i++) {
        File.append(all_results[i] + "\n", detailed_csv);
    }
    
    // Save threshold comparison
    comparison_csv = analysis_dir + "Threshold_Comparison_Summary.csv";
    comparison_header = "Threshold,Total_Particles,Total_Area,Average_Area,Min_Area,Max_Area\n";
    File.saveString(comparison_header, comparison_csv);
    for (i = 0; i < summary_data.length; i++) {
        File.append(summary_data[i] + "\n", comparison_csv);
    }
    
    // Save qualification results (calibration-specific)
    qualification_csv = analysis_dir + "Calibration_Edge_Qualification_Results.csv";
    qualification_header = "Threshold,Sample_Number,Qualified_Particles,Total_Particles\n";
    File.saveString(qualification_header, qualification_csv);
    for (i = 0; i < qualification_results.length; i++) {
        File.append(qualification_results[i] + "\n", qualification_csv);
    }
    
    // Create comprehensive calibration report
    report_path = analysis_dir + "Calibration_Threshold_Analysis_Report.txt";
    report_content = "COMPLETE CALIBRATION PROCESSING THRESHOLD ANALYSIS REPORT\n";
    report_content += "=========================================================\n\n";
    report_content += "Analysis Date: " + getCurrentDateTime() + "\n";
    report_content += "Folder Pairs Processed: " + folder_pairs.length + "\n";
    report_content += "Thresholds Tested: " + arrayToString(test_thresholds) + "\n\n";
    
    report_content += "CALIBRATION PROCESSING PIPELINE:\n";
    report_content += "1. Image registration (Descriptor-based 2D)\n";
    report_content += "2. Channel splitting and difference calculation\n";
    report_content += "3. Cropping (80% of original size)\n";
    report_content += "4. Threshold application (VARIABLE PARAMETER)\n";
    report_content += "5. Mask conversion and particle analysis\n";
    report_content += "6. Calibration edge coordinate extraction\n";
    report_content += "7. Particle-to-slice mapping\n";
    report_content += "8. Calibration edge qualification\n\n";
    
    report_content += "THRESHOLD PERFORMANCE SUMMARY:\n";
    for (i = 0; i < summary_data.length; i++) {
        parts = split(summary_data[i], ",");
        if (parts.length >= 4) {
            threshold = parts[0];
            particles = parts[1];
            avg_area = parts[3];
            report_content += "Threshold " + threshold + ": " + particles + " particles, avg area: " + avg_area + " μm²\n";
        }
    }
    
    report_content += "\nCALIBRATION EDGE QUALIFICATION ANALYSIS:\n";
    report_content += "Shows how many particles qualify as 'on calibration edge' for each threshold:\n";
    for (i = 0; i < qualification_results.length; i++) {
        parts = split(qualification_results[i], ",");
        if (parts.length >= 4) {
            threshold = parts[0];
            sample = parts[1];
            qualified = parts[2];
            total = parts[3];
            percentage = (parseFloat(qualified) / parseFloat(total)) * 100;
            report_content += "Threshold " + threshold + " (Sample " + sample + "): " + qualified + "/" + total + 
                            " (" + d2s(percentage, 1) + "%) qualified as calibration edge particles\n";
        }
    }
    
    report_content += "\nOUTPUT STRUCTURE:\n";
    report_content += "- Threshold_X/ folders: Complete processing results for each threshold\n";
    report_content += "- Edge/ subfolders: Final edge detection results for visual comparison\n";
    report_content += "- EdgeCoords_TX/ folders: Extracted edge coordinates per threshold (shortened names)\n";
    report_content += "- Detailed_Results_All_Thresholds.csv: All particle measurements\n";
    report_content += "- Threshold_Comparison_Summary.csv: Summary statistics by threshold\n";
    report_content += "- Calibration_Edge_Qualification_Results.csv: Edge qualification analysis\n\n";
    
    report_content += "CALIBRATION-SPECIFIC ANALYSIS:\n";
    report_content += "The qualification logic determines if a particle is 'on the calibration edge':\n";
    report_content += "1. Horizontal overlap: Edge coordinate X falls within particle boundaries\n";
    report_content += "2. Vertical proximity: Particle extends within 2 units of edge coordinate Y\n";
    report_content += "3. Qualification criteria: edge_x >= particle_left AND edge_x <= particle_right\n";
    report_content += "   AND (particle_top + 2) >= edge_y\n\n";
    
    report_content += "RECOMMENDATIONS:\n";
    report_content += "1. Compare Edge/ folders visually across different thresholds\n";
    report_content += "2. Analyze Threshold_Comparison_Summary.csv for quantitative trends\n";
    report_content += "3. Review Calibration_Edge_Qualification_Results.csv for edge detection quality\n";
    report_content += "4. Look for threshold with good calibration edge capture without excessive noise\n";
    report_content += "5. Consider consistency across different calibration samples\n";
    report_content += "6. Balance between sensitivity (detecting true calibration edges) and specificity\n";
    report_content += "7. Optimal threshold should show stable qualification rates across samples\n";
    
    File.saveString(report_content, report_path);
    
    print("Calibration analysis files created:");
    print("- " + detailed_csv);
    print("- " + comparison_csv);
    print("- " + qualification_csv);
    print("- " + report_path);
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function filterImageFiles(file_list) {
    image_files = newArray(0);
    for (i = 0; i < file_list.length; i++) {
        if (isImageFile(file_list[i])) {
            image_files = Array.concat(image_files, file_list[i]);
        }
    }
    return image_files;
}

function createAllSubdirectories(out_dir, processed_dir) {
    File.makeDirectory(out_dir);
    File.makeDirectory(processed_dir);
    
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", 
                      "Split/C1Fused", "Split/C2Fused", "Difference", "Crop", 
                      "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", 
                      "Finished", "Edge", "Errors");
                      
    for (i = 0; i < subdirs.length; i++) {
        File.makeDirectory(processed_dir + subdirs[i]);
    }
}

function saveResultsTables(out_dir, in_dir_1, in_dir_2, threshold_value) {
    base_name = File.getNameWithoutExtension(in_dir_1) + "_minus_" + File.getNameWithoutExtension(in_dir_2);
    
    if (isOpen("Results")) {
        Table.save(out_dir + "Particles_" + base_name + "_threshold_" + threshold_value + ".csv", "Results");
        Table.reset("Results");
    }
    
    if (isOpen("Summary")) {
        Table.save(out_dir + "Summary_" + base_name + "_threshold_" + threshold_value + ".csv", "Summary");
        Table.reset("Summary");
    }
}

function isImageFile(filename) {
    return (endsWith(filename, ".tif") || endsWith(filename, ".tiff") ||
            endsWith(filename, ".jpg") || endsWith(filename, ".jpeg") ||
            endsWith(filename, ".png") || endsWith(filename, ".bmp"));
}

function arrayToString(array) {
    result = "";
    for (i = 0; i < array.length; i++) {
        result += array[i];
        if (i < array.length - 1) result += ", ";
    }
    return result;
}

function getCurrentDateTime() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return year + "-" + IJ.pad(month+1,2) + "-" + IJ.pad(dayOfMonth,2) + " " + 
           IJ.pad(hour,2) + ":" + IJ.pad(minute,2) + ":" + IJ.pad(second,2);
}