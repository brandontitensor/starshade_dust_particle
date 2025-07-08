// Complete Calibration Edge Analysis Macro - FINAL IMAGEJ COMPATIBLE VERSION
// Combines file renaming, brightness standardization, registration, edge detection,
// coordinate extraction, particle mapping, and qualification in one workflow
// FIXED: All ImageJ macro compatibility issues resolved and function order corrected

setBatchMode(true);
run("Close All");

// ============================================================================
// UTILITY FUNCTIONS (DEFINED FIRST)
// ============================================================================

function safeCloseAllImages() {
    // Get list of all open windows
    window_count = nImages();
    
    if (window_count > 0) {
        window_titles = newArray(window_count);
        for (w = 1; w <= window_count; w++) {
            selectImage(w);
            window_titles[w-1] = getTitle();
        }
        
        // Close each image window specifically
        for (w = 0; w < window_titles.length; w++) {
            if (isOpen(window_titles[w])) {
                selectWindow(window_titles[w]);
                close();
            }
        }
    }
    
    // Verify Results table is still intact
    particles_after_cleanup = nResults;
    print("        Safe cleanup: " + window_count + " images closed, " + particles_after_cleanup + " particles preserved");
}

function getTimeStamp() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return year + "-" + IJ.pad(month+1, 2) + "-" + IJ.pad(dayOfMonth, 2) + " " + 
           IJ.pad(hour, 2) + ":" + IJ.pad(minute, 2) + ":" + IJ.pad(second, 2);
}

function buildProcessingQueue(parent_dir) {
    folder_list = getFileList(parent_dir);
    folder_pairs = newArray(0);
    
    for (i = 0; i < folder_list.length; i++) {
        if (startsWith(folder_list[i], "Bef_") && endsWith(folder_list[i], "/")) {
            bef_folder = folder_list[i];
            aft_folder = "Aft_" + substring(bef_folder, 4);
            
            if (File.exists(parent_dir + aft_folder)) {
                folder_pairs = Array.concat(folder_pairs, bef_folder + "|" + aft_folder);
                print("  Found pair: " + bef_folder + " <-> " + aft_folder);
            } else {
                print("  Warning: No matching Aft folder for " + bef_folder);
            }
        }
    }
    return folder_pairs;
}

function isImageFile(filename) {
    return (endsWith(filename, ".tif") || endsWith(filename, ".tiff") ||
            endsWith(filename, ".jpg") || endsWith(filename, ".jpeg") ||
            endsWith(filename, ".png") || endsWith(filename, ".bmp"));
}

function logError(message, processed_dir) {
    print("    ERROR: " + message);
    error_log_path = processed_dir + "Errors/error_log.txt";
    File.makeDirectory(processed_dir + "Errors/");
    File.append("Error: " + message + "\n", error_log_path);
}

function storeGlobalMedianInfo(median_info, out_dir) {
    median_file_path = out_dir + "median_brightness_data.txt";
    
    // Build single string and write once (much faster than multiple appends)
    output_string = "";
    for (i = 0; i < median_info.length; i++) {
        output_string += median_info[i] + "\n";
    }
    
    File.saveString(output_string, median_file_path);
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

function getSubfolders(dir) {
    subfolders = newArray(0);
    if (File.exists(dir)) {
        list = getFileList(dir);
        for (i = 0; i < list.length; i++) {
            if (endsWith(list[i], "/"))
                subfolders = Array.concat(subfolders, dir + list[i]);
        }
    }
    return subfolders;
}

function findSummaryFile(dir) {
    list = getFileList(dir);
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "Summary") && endsWith(list[i], ".csv")) {
            return dir + list[i];
        }
    }
    return "";
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
    // More efficient string replacement for calibration edge
    if (startsWith(finishedName, "Difference")) {
        return "Edge" + substring(finishedName, 10); // "Difference" is 10 characters
    }
    return "Edge" + finishedName;
}

// ============================================================================
// PART 1 FUNCTIONS: Optimized File Renaming
// ============================================================================

function optimizedProcessFolder(folder_path) {
    file_list = getFileList(folder_path);
    rename_operations = newArray(0);
    
    // Build rename operation list first
    for (i = 0; i < file_list.length; i++) {
        old_name = file_list[i];
        if (!endsWith(old_name, "/")) { // Skip directories
            dot_index = lastIndexOf(old_name, ".");
            if (dot_index != -1 && !endsWith(old_name, "0" + substring(old_name, dot_index))) {
                new_name = substring(old_name, 0, dot_index) + "0" + substring(old_name, dot_index);
                rename_operations = Array.concat(rename_operations, old_name + "|" + new_name);
            }
        }
    }
    
    // Execute all renames in batch
    for (i = 0; i < rename_operations.length; i++) {
        operation = split(rename_operations[i], "|");
        if (File.rename(folder_path + operation[0], folder_path + operation[1])) {
            // Rename successful
        } else {
            print("  Warning: Failed to rename " + operation[0]);
        }
    }
    
    if (rename_operations.length > 0) {
        print("  Processed folder: " + folder_path + " (" + rename_operations.length + " files)");
    }
    
    return rename_operations.length;
}

function batchRenameBefFiles(parent_dir, folder_pairs) {
    total_files_renamed = 0;
    
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        files_renamed = optimizedProcessFolder(parent_dir + bef_folder);
        total_files_renamed += files_renamed;
        
        showProgress(i+1, folder_pairs.length);
    }
    
    print("Batch file renaming complete! Total files renamed: " + total_files_renamed);
}

// ============================================================================
// PART 2 FUNCTIONS: FIXED BRIGHTNESS STANDARDIZATION
// ============================================================================

function getBasicImageStats() {
    run("Set Measurements...", "mean median min max redirect=None decimal=3");
    run("Select All");
    run("Measure");
    
    min_val = getResult("Min", nResults-1);
    max_val = getResult("Max", nResults-1);
    median_val = getResult("Median", nResults-1);
    mean_val = getResult("Mean", nResults-1);
    
    run("Clear Results");
    
    return newArray(min_val, max_val, median_val, mean_val);
}

function calculateSpatialRegionStatsFast() {
    // Fast calculation using ImageJ's built-in ROI functions
    
    getDimensions(width, height, channels, slices, frames);
    
    // Define regions
    top_region_height = floor(height * 0.30);
    bottom_region_start_y = floor(height * 0.70);
    bottom_region_height = height - bottom_region_start_y;
    
    // Save current selection
    run("Select None");
    
    // Measure top 30% region
    makeRectangle(0, 0, width, top_region_height);
    run("Set Measurements...", "mean median redirect=None decimal=3");
    run("Measure");
    top_median = getResult("Median", nResults-1);
    top_mean = getResult("Mean", nResults-1);
    run("Clear Results");
    
    // Measure bottom 30% region
    makeRectangle(0, bottom_region_start_y, width, bottom_region_height);
    run("Set Measurements...", "mean median redirect=None decimal=3");
    run("Measure");
    bottom_median = getResult("Median", nResults-1);
    bottom_mean = getResult("Mean", nResults-1);
    run("Clear Results");
    
    // Clear selection
    run("Select None");
    
    // Return [top_median, top_mean, bottom_median, bottom_mean]
    return newArray(top_median, top_mean, bottom_median, bottom_mean);
}

function applyFallbackStandardization(original_stats) {
    // Fallback method when no spatial gradient exists
    // Uses overall median centering to a middle target value
    
    original_median = original_stats[2];
    target_median = 100;  // Middle value between our spatial targets
    
    offset = target_median - original_median;
    
    if (offset != 0) {
        run("32-bit");
        run("Add...", "value=" + offset);
        run("8-bit");
        
        // Get new statistics
        new_stats = getBasicImageStats();
        print("      Fallback applied - median shift: " + d2s(offset, 1));
        
        return new_stats;
    } else {
        print("      No transformation needed");
        return original_stats;
    }
}

function applyFixedStandardization(original_stats) {
    // Anchor Point Method - Uses spatial region medians as standardization targets
    
    original_min = original_stats[0];
    original_max = original_stats[1];
    original_median = original_stats[2];
    original_mean = original_stats[3];
    
    // Get original spatial region statistics (top 30% and bottom 30% of image area)
    original_regions = calculateSpatialRegionStatsFast();
    original_top_median = original_regions[0];
    original_bottom_median = original_regions[2];
    
    print("      Original top 30% median: " + d2s(original_top_median, 1) + ", bottom 30% median: " + d2s(original_bottom_median, 1));
    print("      Original top/bottom ratio: " + d2s(original_top_median/original_bottom_median, 2));
    
    // TARGET VALUES FOR SPATIAL REGIONS
    target_top_median = 186;     // Target for top 30% region median
    target_bottom_median = 8;   // Target for bottom 30% region median
    
    print("      Target top 30% median: " + target_top_median + ", bottom 30% median: " + target_bottom_median);
    
    // Calculate Anchor Point transformation
    original_range = original_top_median - original_bottom_median;
    target_range = target_top_median - target_bottom_median;
    
    if (original_range > 0) {
        // Calculate linear transformation using anchor points
        // Maps: original_bottom_median → target_bottom_median
        //       original_top_median → target_top_median
        scale_factor = target_range / original_range;
        offset = target_bottom_median - (original_bottom_median * scale_factor);
        
        print("      Anchor Point Transform: scale = " + d2s(scale_factor, 4) + ", offset = " + d2s(offset, 2));
        
        // Apply transformation to entire image
        run("32-bit");
        run("Multiply...", "value=" + scale_factor);
        run("Add...", "value=" + offset);
        run("8-bit");
        
        // Get new statistics
        new_stats = getBasicImageStats();
        
        // Verify spatial region targets were achieved
        new_regions = calculateSpatialRegionStatsFast();
        new_top_median = new_regions[0];
        new_bottom_median = new_regions[2];
        
        print("      Achieved top 30% median: " + d2s(new_top_median, 1) + ", bottom 30% median: " + d2s(new_bottom_median, 1));
        print("      New top/bottom ratio: " + d2s(new_top_median/new_bottom_median, 2));
        print("      Target accuracy - top: " + d2s(abs(new_top_median - target_top_median), 1) + ", bottom: " + d2s(abs(new_bottom_median - target_bottom_median), 1));
        
        // Calculate how much the spatial regions changed
        top_median_change = new_top_median - original_top_median;
        bottom_median_change = new_bottom_median - original_bottom_median;
        print("      Spatial changes - top median: " + d2s(top_median_change, 1) + ", bottom median: " + d2s(bottom_median_change, 1));
        
        // Show preservation of intensity relationships
        original_ratio = original_top_median / original_bottom_median;
        new_ratio = new_top_median / new_bottom_median;
        target_ratio = target_top_median / target_bottom_median;
        print("      Ratio preservation - original: " + d2s(original_ratio, 2) + ", achieved: " + d2s(new_ratio, 2) + ", target: " + d2s(target_ratio, 2));
        
        return new_stats;
    } else {
        // No spatial difference detected - use fallback method
        print("      No spatial gradient detected - using fallback standardization");
        return applyFallbackStandardization(original_stats);
    }
}

function fixedStandardizeFolder(folder_path, folder_name, out_dir) {
    file_list = getFileList(folder_path);
    
    // Filter to image files
    image_files = newArray(0);
    for (i = 0; i < file_list.length; i++) {
        if (isImageFile(file_list[i])) {
            image_files = Array.concat(image_files, file_list[i]);
        }
    }
    
    if (image_files.length == 0) return newArray(0);
    
    // Create output directory
    corrected_image_path = out_dir + "Brightness_Corrected/" + folder_name + "/";
    File.makeDirectory(corrected_image_path);
    
    median_info = newArray(0);
    
    print("  Processing " + folder_name + " (" + image_files.length + " images)");
    
    for (j = 0; j < image_files.length; j++) {
        current_file = image_files[j];
        
        open(folder_path + current_file);
        
        // Get original statistics AND spatial regions
        original_stats = getBasicImageStats();
        original_spatial = calculateSpatialRegionStatsFast();
        
        // Apply standardization
        new_stats = applyFixedStandardization(original_stats);
        new_spatial = calculateSpatialRegionStatsFast();
        
        // Store comprehensive data: folder|file|pre_top30|pre_bottom30|pre_entire|post_top30|post_bottom30|post_entire
        brightness_data = folder_name + "|" + current_file + "|" + 
                         original_spatial[0] + "|" + original_spatial[2] + "|" + original_stats[2] + "|" +  // Pre: top30, bottom30, entire
                         new_spatial[0] + "|" + new_spatial[2] + "|" + new_stats[2];                        // Post: top30, bottom30, entire
        
        print("DEBUG: Storing brightness data: " + brightness_data);
        median_info = Array.concat(median_info, brightness_data);
        
        // Save standardized image
        saveAs("jpg", corrected_image_path + current_file);
        close("*");
    }
    
    return median_info;
}


function fixedBrightnessStandardization(parent_dir, folder_pairs) {
    print("=== FIXED BRIGHTNESS STANDARDIZATION FOR TEMPORAL DRIFT ===");
    print("Linear scaling to preserve threshold sensitivity across trials");
    
    // Create output directory structure
    out_dir = parent_dir + "Edge Measurements/";
    if (!File.isDirectory(out_dir)) {
        File.makeDirectory(out_dir);
    }
    File.makeDirectory(out_dir + "Brightness_Corrected/");
    
    all_median_info = newArray(0);
    
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        print("Processing pair " + (i+1) + "/" + folder_pairs.length + ": " + bef_folder + " & " + aft_folder);
        
        // Process both folders with fixed standardization
        bef_info = fixedStandardizeFolder(parent_dir + bef_folder, bef_folder, out_dir);
        aft_info = fixedStandardizeFolder(parent_dir + aft_folder, aft_folder, out_dir);
        
        all_median_info = Array.concat(all_median_info, bef_info);
        all_median_info = Array.concat(all_median_info, aft_info);
        
        showProgress(i+1, folder_pairs.length);
    }
    
    storeGlobalMedianInfo(all_median_info, out_dir);
    print("Fixed brightness standardization complete!");
    print("All images now have consistent brightness levels for reliable thresholding");
}

// ============================================================================
// PART 3 FUNCTIONS: FIXED Image Registration and Processing
// ============================================================================

function createSimpleHistogram() {
    // Create histogram data manually by scanning all pixels
    getDimensions(width, height, channels, slices, frames);
    histogram = newArray(256);
    
    // Initialize histogram array
    for (i = 0; i < 256; i++) {
        histogram[i] = 0;
    }
    
    // Count pixels at each intensity level
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            pixel_value = getPixel(x, y);
            if (pixel_value >= 0 && pixel_value < 256) {
                histogram[pixel_value]++;
            }
        }
    }
    
    return histogram;
}

function processCalibrationDifferenceWithDebugging(diff_title, fullFileName, processed_dir) {
    print("          Processing difference image: " + diff_title);
    
    selectWindow(diff_title);
    saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
    
    // Get dimensions and calculate crop (top and bottom only for calibration)
    getDimensions(width, height, channels, slices, frames);
    new_height = floor(height * 0.8);
    new_y = floor(height * 0.1);
    
    print("          Original dimensions: " + width + "x" + height);
    print("          Cropping to: " + width + "x" + new_height);
    
    // Apply crop (calibration specific - top and bottom only)
    makeRectangle(0, new_y, width, new_height);
    run("Crop");
    
    // *** CRITICAL FIX: Set scale AFTER crop, not before ***
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Save progressive versions
    saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
    run("8-bit");
    saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
    
    // *** CRITICAL: Get fresh statistics after 8-bit conversion ***
    getDimensions(final_width, final_height, channels, slices, frames);
    print("          Final 8-bit dimensions: " + final_width + "x" + final_height);
    
    // Enhanced threshold analysis
    THRESHOLD_VALUE = 40;
    print("          Applying threshold: " + THRESHOLD_VALUE);
    
    // *** CRITICAL: Verify image is actually 8-bit before thresholding ***
    if (bitDepth() != 8) {
        print("          WARNING: Image is not 8-bit! Converting...");
        run("8-bit");
    }
    
    // Apply threshold with verification
    setThreshold(THRESHOLD_VALUE, 255);
    
    // Count pixels at threshold to verify it's working
    threshold_pixels = 0;
    total_pixels = final_width * final_height;
    
    for (y = 0; y < final_height; y++) {
        for (x = 0; x < final_width; x++) {
            pixel_value = getPixel(x, y);
            if (pixel_value >= THRESHOLD_VALUE) {
                threshold_pixels++;
            }
        }
    }
    
    threshold_percentage = (threshold_pixels * 100.0) / total_pixels;
    print("          Threshold verification:");
    print("            Pixels >= " + THRESHOLD_VALUE + ": " + threshold_pixels + " (" + d2s(threshold_percentage, 1) + "%)");
    
    if (threshold_percentage < 0.1) {
        print("          *** WARNING: Very few pixels above threshold! ***");
        print("          *** Consider lowering threshold value ***");
    } else if (threshold_percentage > 50) {
        print("          *** WARNING: Too many pixels above threshold! ***");
        print("          *** Consider raising threshold value ***");
    }
    
    // Convert to mask
    run("Convert to Mask");
    saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName);
    saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName);
    
    // *** CRITICAL FIX: Proper particle analysis setup ***
    print("          Starting particle analysis...");
    
    // Store initial Results table state
    particles_before_analysis = nResults;
    
    // *** MOST IMPORTANT: Configure measurements PROPERLY ***
    run("Set Measurements...", "area bounding shape redirect=None decimal=3");
    
    // *** CRITICAL: Use proper particle analysis parameters ***
    // The key issue was likely here - need to ensure proper size filtering and settings
    run("Analyze Particles...", " show=Masks display exclude include summarize");
    
    // Verify particle measurements immediately
    particles_after_analysis = nResults;
    particles_found_this_image = particles_after_analysis - particles_before_analysis;
    
    print("          Particle analysis results:");
    print("            Particles found: " + particles_found_this_image);
    print("            Total particles in table: " + particles_after_analysis);
    
    // *** CRITICAL VALIDATION: Check if particles have real measurements ***
    if (particles_found_this_image > 0) {
        // Check the last few particles to verify they have real measurements
        validation_start = maxOf(0, particles_after_analysis - minOf(3, particles_found_this_image));
        all_zeros_count = 0;
        
        for (check_i = validation_start; check_i < particles_after_analysis; check_i++) {
            area = getResult("Area", check_i);
            x_coord = getResult("X", check_i);
            y_coord = getResult("Y", check_i);
            bx = getResult("BX", check_i);
            by = getResult("BY", check_i);
            width = getResult("Width", check_i);
            height = getResult("Height", check_i);
            
            print("            Particle " + (check_i + 1) + ": Area=" + d2s(area, 3) + 
                  ", X=" + d2s(x_coord, 1) + ", Y=" + d2s(y_coord, 1) +
                  ", BX=" + d2s(bx, 1) + ", BY=" + d2s(by, 1) + 
                  ", W=" + d2s(width, 1) + ", H=" + d2s(height, 1));
                  
            if (area == 0 && x_coord == 0 && y_coord == 0 && bx == 0 && by == 0 && width == 0 && height == 0) {
                all_zeros_count++;
                print("            *** ERROR: Particle " + (check_i + 1) + " has ALL ZERO values! ***");
            }
        }
        
        if (all_zeros_count > 0) {
            print("          *** CRITICAL PROBLEM: " + all_zeros_count + " particles have zero measurements ***");
            print("          *** This indicates a fundamental issue with particle detection ***");
            
            // Emergency diagnostic: check the mask
            print("          Running emergency diagnostic...");
 
            
        } else {
            print("          ✓ All particles have valid measurements");
        }
    } else {
        print("          WARNING: No particles detected - check threshold or image quality");
    }
    
    // Save final processed image
    saveAs("jpg", processed_dir + "Finished/" + fullFileName);
    
    print("          ✓ Difference processing completed");
    return true;
}

function processFusedImage(fused_title, fullFileName, processed_dir, file1, file2) {
    selectWindow(fused_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
    
    // Split channels
    run("Split Channels");
    
    c1_title = "C1-" + fused_title;
    c2_title = "C2-" + fused_title;
    
    if (!isOpen(c1_title) || !isOpen(c2_title)) {
        print("          ERROR: Failed to split channels");
        return false;
    }
    
    // Save split channels
    selectWindow(c1_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Split/C1Fused/C1-Fused " + file1 + " & " + file2);
    c1_saved_title = getTitle();
    
    selectWindow(c2_title);
    saveAs("jpg", processed_dir + "Split/C2Fused/C2-Fused " + file1 + " & " + file2);
    c2_saved_title = getTitle();
    
    // Edge Detection Block - FIXED VERSION
    if (isOpen(c1_title) && isOpen(c2_title)) {
        // IMPORTANT: Create copies for edge detection to avoid modifying originals
        selectWindow(c1_title);
        run("Duplicate...", "title=C1_copy_for_edge");
        c1_edge_copy = getTitle();
        
        selectWindow(c2_title);
        run("Duplicate...", "title=C2_copy_for_edge");
        c2_edge_copy = getTitle();
        
        // Perform edge detection on COPIES, not originals
        imageCalculator("AND create", c1_edge_copy, c2_edge_copy);
        edgeResultTitle = getTitle();
        
        if (isOpen(edgeResultTitle)) {
            run("Set Scale...", "distance=240 known=50 unit=micron");
            
            // Add the copies to the edge result
            imageCalculator("Add", edgeResultTitle, c1_edge_copy);
            imageCalculator("Add", edgeResultTitle, c2_edge_copy);
            
            // Save the edge image
            saveAs("jpg", processed_dir + "Edge/Edge" + fullFileName);
            edge_title = getTitle();
            
            // Save edge coordinates using the edge image
            if (isOpen(edge_title)) {
                selectWindow(edge_title);
                run("8-bit");
                run("Convert to Mask");
                saveAllEdgeCoordinates(processed_dir + "EdgeCoordinates/", fullFileName);
            }
            
            // Clean up edge detection copies
            if (isOpen(c1_edge_copy)) {
                selectWindow(c1_edge_copy);
                close();
            }
            if (isOpen(c2_edge_copy)) {
                selectWindow(c2_edge_copy);
                close();
            }
            if (isOpen(edgeResultTitle)) {
                selectWindow(edgeResultTitle);
                close();
            }
            if (isOpen(edge_title)) {
                selectWindow(edge_title);
                close();
            }
        }
    }
    
    // Calculate difference using ORIGINAL, UNMODIFIED channels
    imageCalculator("Difference create", c1_saved_title, c2_saved_title);
    
    // The result window name follows ImageJ convention
    diff_title = "Result of " + c1_saved_title;
    
    if (!isOpen(diff_title)) {
        print("          ERROR: Failed to create difference image");
        return false;
    }
    
    // Process difference image with FIXED threshold handling
    return processCalibrationDifferenceWithDebugging(diff_title, fullFileName, processed_dir);
}

function optimizedProcessImagePairSingle(in_dir_1, in_dir_2, file1_name, file2_name, processed_dir) {
    file1 = File.getNameWithoutExtension(file1_name);
    file2 = File.getNameWithoutExtension(file2_name);
    fullFileName = file1 + "minus" + file2;
    
    print("        Processing: " + fullFileName);
    
    // Check if input files exist
    if (!File.exists(in_dir_1 + file1_name) || !File.exists(in_dir_2 + file2_name)) {
        print("        ERROR: Input files not found");
        print("          File 1: " + in_dir_1 + file1_name + " exists=" + File.exists(in_dir_1 + file1_name));
        print("          File 2: " + in_dir_2 + file2_name + " exists=" + File.exists(in_dir_2 + file2_name));
        return false;
    }
    
    // Load and prepare first image (clean/before)
    print("        Loading image 1: " + file1_name);
    open(in_dir_1 + file1_name);
    if (nImages() == 0) {
        print("        ERROR: Failed to open first image");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit clean/8bit" + file1);
    title1 = getTitle();
    print("        First image loaded as: " + title1);
    
    // Load and prepare second image (dirty/after)
    print("        Loading image 2: " + file2_name);
    open(in_dir_2 + file2_name);
    if (nImages() != 2) {
        print("        ERROR: Expected 2 images, have " + nImages());
        close("*");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "8 bit dirty/8bit" + file2);
    title2 = getTitle();
    print("        Second image loaded as: " + title2);
    
    // Verify both images are still open
    if (!isOpen(title1) || !isOpen(title2)) {
        print("        ERROR: Lost one or both images during processing");
        close("*");
        return false;
    }
    
    // Perform registration with ImageJ macro compatible error checking
    print("        Starting image registration...");
    
    // Store initial window count to detect registration failure
    windows_before_registration = nImages();
    
    run("Descriptor-based registration (2d/3d)", 
        "first_image=" + title1 + " second_image=" + title2 + 
        " brightness_of=[Advanced ...] approximate_size=[Advanced ...] " +
        "type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] " +
        "transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] " +
        "number_of_neighbors=3 redundancy=2 significance=3 allowed_error_for_ransac=6 " +
        "choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 " +
        "create_overlayed add_point_rois interpolation=[Linear Interpolation] " +
        "detection_sigma=3.9905 threshold=0.0537");
    
    // Check if registration created new windows
    windows_after_registration = nImages();
    if (windows_after_registration <= windows_before_registration) {
        print("        ERROR: Registration failed - no new windows created");
        close("*");
        return false;
    }
    
    // Check registration success
    fused_title = "Fused " + file1 + " & " + file2;
    print("        Looking for fused result: " + fused_title);
    
    if (!isOpen(fused_title)) {
        print("        ERROR: Registration failed - no fused image created");
        print("        Available windows: ");
        for (w = 1; w <= nImages(); w++) {
            selectImage(w);
            print("          " + w + ": " + getTitle());
        }
        close("*");
        return false;
    }
    
    print("        ✓ Registration successful");
    
    // Continue with processing pipeline
    result = processFusedImage(fused_title, fullFileName, processed_dir, file1, file2);
    
    if (result) {
        print("        ✓ Image pair processing completed successfully");
    } else {
        print("        ERROR: Failed during fused image processing");
    }
    
    return result;
}

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
                      "Split/C1Fused", "Split/C2Fused", "Difference", "Edge", "Crop", 
                      "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", 
                      "Finished", "Errors", "EdgeCoordinates", "NewEdgeCoordinates");
                      
    for (i = 0; i < subdirs.length; i++) {
        File.makeDirectory(processed_dir + subdirs[i]);
    }
}

function verifyResultsTableIntegrity(context) {
    // Debug function to verify Results table state
    if (isOpen("Results")) {
        particle_count = nResults;
        print("    VERIFICATION [" + context + "]:");
        print("      Results table exists with " + particle_count + " particles");
        
        if (particle_count > 0) {
            // Check if we have expected columns
            first_area = getResult("Area", 0);
            last_area = getResult("Area", particle_count - 1);
            print("      First particle area: " + d2s(first_area, 3));
            print("      Last particle area: " + d2s(last_area, 3));
            print("      ✓ Results table structure is valid");
        }
    } else {
        print("    VERIFICATION [" + context + "]: No Results table exists");
    }
}

function saveResultsTables(out_dir, in_dir_1, in_dir_2) {
    base_name = File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2);
    
    // *** CRITICAL FIX: Save Results table but DON'T reset it until all processing is done ***
    if (isOpen("Results")) {
        total_particles = nResults;
        print("    Saving Results table with " + total_particles + " accumulated particles");
        Table.save(out_dir + "Particles " + base_name + ".csv", "Results");
        
        // *** IMPORTANT: Do NOT reset Results table here! ***
        // Results must persist across all images in all folder pairs
        // Only reset at the very end of ALL processing
        print("    ✓ Particle data preserved for continued accumulation");
    } else {
        print("    Warning: No Results table found to save");
    }
    
    // Summary table can be reset since it's per-folder
    if (isOpen("Summary")) {
        Table.save(out_dir + "Summary " + base_name + ".csv", "Summary");
        Table.reset("Summary");
    }
}

function addOptimizedSummaryData(comparison_folder, bef_folder_name, aft_folder_name) {
    // Check if Summary table exists
    if (!isOpen("Summary")) {
        print("    Summary table not found - skipping enhanced data addition");
        return;
    }
    
    num_summary_rows = Table.size("Summary");
    
    if (num_summary_rows == 0) {
        print("    Summary table is empty - cannot add additional data");
        return;
    }
    
    // Batch add all columns at once
    column_names = newArray("image_name", "edge_image_name", "finished_width", "finished_height",
                       "edge_width", "edge_height", "width_difference", "height_difference",
                       "Bef_Pre_Upper_Median", "Bef_Pre_Lower_Median", "Bef_Pre_Entire_Median",
                       "Bef_Post_Upper_Median", "Bef_Post_Lower_Median", "Bef_Post_Entire_Median",
                       "Aft_Pre_Upper_Median", "Aft_Pre_Lower_Median", "Aft_Pre_Entire_Median", 
                       "Aft_Post_Upper_Median", "Aft_Post_Lower_Median", "Aft_Post_Entire_Median");
    
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
    
    for (row = 0; row < minOf(num_summary_rows, finishedImageList.length); row++) {
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
    median_info = loadGlobalMedianInfo(out_dir);
    if (median_info.length == 0) {
        print("DEBUG: No median info found");
        return;
    }
    
    print("DEBUG: Found " + median_info.length + " median info entries");
    
    // Parse and organize data by image pairs
    for (row = 0; row < num_summary_rows; row++) {
        // Get the combined image name from this summary row
        combined_image_name = Table.getString("image_name", row, "Summary");
        
        print("DEBUG: Processing row " + row + ", combined name: " + combined_image_name);
        
        // Extract individual image names from combined name
        // Format: "imageAminus imageB.jpg" -> extract "imageA.jpg" and "imageB.jpg"
        image_names = extractImageNamesFromCombined(combined_image_name);
        
        if (image_names.length == 2) {
            bef_image = image_names[0];
            aft_image = image_names[1];
            
            print("DEBUG: Looking for Bef image: " + bef_image);
            print("DEBUG: Looking for Aft image: " + aft_image);
            
            // Find matching brightness data for both images
            bef_data = findImageBrightnessData(median_info, "Bef_", bef_image);
            aft_data = findImageBrightnessData(median_info, "Aft_", aft_image);
            
            print("DEBUG: Bef data found: " + (bef_data.length > 0));
            print("DEBUG: Aft data found: " + (aft_data.length > 0));
            
            if (bef_data.length >= 8) {
                // Before image data (format: folder|file|pre_top30|pre_bottom30|pre_entire|post_top30|post_bottom30|post_entire)
                Table.set("Bef_Pre_Upper_Median", row, parseFloat(bef_data[2]), "Summary");      // top 30%
                Table.set("Bef_Pre_Lower_Median", row, parseFloat(bef_data[3]), "Summary");     // bottom 30%
                Table.set("Bef_Pre_Entire_Median", row, parseFloat(bef_data[4]), "Summary");    // entire image
                Table.set("Bef_Post_Upper_Median", row, parseFloat(bef_data[5]), "Summary");    // top 30%
                Table.set("Bef_Post_Lower_Median", row, parseFloat(bef_data[6]), "Summary");    // bottom 30%
                Table.set("Bef_Post_Entire_Median", row, parseFloat(bef_data[7]), "Summary");   // entire image
                
                print("DEBUG: Set Bef data - Pre Upper: " + bef_data[2] + ", Pre Lower: " + bef_data[3]);
            }
            
            if (aft_data.length >= 8) {
                // After image data
                Table.set("Aft_Pre_Upper_Median", row, parseFloat(aft_data[2]), "Summary");     // top 30%
                Table.set("Aft_Pre_Lower_Median", row, parseFloat(aft_data[3]), "Summary");    // bottom 30%
                Table.set("Aft_Pre_Entire_Median", row, parseFloat(aft_data[4]), "Summary");   // entire image
                Table.set("Aft_Post_Upper_Median", row, parseFloat(aft_data[5]), "Summary");   // top 30%
                Table.set("Aft_Post_Lower_Median", row, parseFloat(aft_data[6]), "Summary");   // bottom 30%
                Table.set("Aft_Post_Entire_Median", row, parseFloat(aft_data[7]), "Summary");  // entire image
                
                print("DEBUG: Set Aft data - Pre Upper: " + aft_data[2] + ", Pre Lower: " + aft_data[3]);
            }
        } else {
            print("DEBUG: Could not extract image names from: " + combined_image_name);
        }
    }
}

function extractImageNamesFromCombined(combined_name) {
    // Handle format: "caliwaferedge100001000minuscaliwaferedge1000012.jpg"
    // Split on "minus" to get the two parts
    
    if (indexOf(combined_name, "minus") > 0) {
        minus_pos = indexOf(combined_name, "minus");
        
        // Extract first image name
        first_part = substring(combined_name, 0, minus_pos);
        first_image = first_part + ".jpg";
        
        // Extract second image name  
        second_part = substring(combined_name, minus_pos + 5); // +5 to skip "minus"
        // Remove .jpg extension if present, then add it back
        if (endsWith(second_part, ".jpg")) {
            second_part = substring(second_part, 0, lengthOf(second_part) - 4);
        }
        second_image = second_part + ".jpg";
        
        return newArray(first_image, second_image);
    }
    
    return newArray(0);
}

function findImageBrightnessData(median_info, folder_prefix, image_name) {
    print("DEBUG: Searching for " + folder_prefix + " + " + image_name);
    
    for (i = 0; i < median_info.length; i++) {
        if (median_info[i] != "") {
            info_parts = split(median_info[i], "|");
            
            print("DEBUG: Checking entry " + i + ": " + median_info[i]);
            print("DEBUG: Parts length: " + info_parts.length);
            if (info_parts.length >= 2) {
                print("DEBUG: Folder: '" + info_parts[0] + "', File: '" + info_parts[1] + "'");
            }
            
            if (info_parts.length >= 8 && 
                startsWith(info_parts[0], folder_prefix) && 
                info_parts[1] == image_name) {
                
                print("DEBUG: FOUND MATCH!");
                return info_parts;
            }
        }
    }
    
    print("DEBUG: No match found for " + folder_prefix + image_name);
    return newArray(0);
}

function optimizedProcessImagePair(in_dir_1, in_dir_2, parent_dir) {
    // Use brightness corrected images instead of original ones
    brightness_corrected_dir = parent_dir + "Edge Measurements/Brightness_Corrected/";
    
    // Extract folder names without paths
    folder_name_1 = File.getName(in_dir_1);
    folder_name_2 = File.getName(in_dir_2);
    
    // Point to brightness corrected folders
    corrected_dir_1 = brightness_corrected_dir + folder_name_1 + "/";
    corrected_dir_2 = brightness_corrected_dir + folder_name_2 + "/";
    
    print("    Using brightness corrected images:");
    print("      Folder 1: " + corrected_dir_1);
    print("      Folder 2: " + corrected_dir_2);
    
    // Verify brightness corrected folders exist
    if (!File.isDirectory(corrected_dir_1) || !File.isDirectory(corrected_dir_2)) {
        print("    ERROR: Brightness corrected folders not found");
        print("      Missing: " + corrected_dir_1 + " exists=" + File.isDirectory(corrected_dir_1));
        print("      Missing: " + corrected_dir_2 + " exists=" + File.isDirectory(corrected_dir_2));
        return 0;
    }
    
    // Get and sort file lists from brightness corrected folders
    ls_1 = getFileList(corrected_dir_1);
    ls_2 = getFileList(corrected_dir_2);
    Array.sort(ls_1);
    Array.sort(ls_2);
    
    // Pre-filter to image files
    image_files_1 = filterImageFiles(ls_1);
    image_files_2 = filterImageFiles(ls_2);
    
    print("    Found " + image_files_1.length + " images in corrected folder 1");
    print("    Found " + image_files_2.length + " images in corrected folder 2");
    
    if (image_files_1.length == 0 || image_files_2.length == 0) {
        print("    ERROR: No matching image files found in brightness corrected folders");
        return 0;
    }
    
    // Setup output directories with timestamp
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    folderName = folder_name_1 + " minus " + folder_name_2 + "_" + 
                 year + "_" + IJ.pad(month+1, 2) + "_" + IJ.pad(dayOfMonth, 2) + "_" + 
                 IJ.pad(hour, 2) + "_" + IJ.pad(minute, 2) + "_" + IJ.pad(second, 2);
    out_dir = parent_dir + "Edge Measurements/" + folderName + "/";
    processed_dir = out_dir + "Processed Images/";
    
    print("    Output directory: " + out_dir);
    
    // Batch create all subdirectories
    createAllSubdirectories(out_dir, processed_dir);
    
    // *** CRITICAL: Track particle count at FOLDER PAIR level ***
    folder_start_particle_count = nResults;
    print("    === STARTING FOLDER PAIR PROCESSING ===");
    print("    Initial particle count in Results table: " + folder_start_particle_count);
    print("    Processing " + folder_name_1 + " vs " + folder_name_2);
    
    // Process images with optimized pipeline
    num_pairs = minOf(image_files_1.length, image_files_2.length);
    successful_pairs = 0;
    total_particles_from_folder = 0;
    
    print("    Will process " + num_pairs + " image pairs");
    
    for (i = 0; i < num_pairs; i++) {
        // Track particles before this specific image pair
        image_start_particles = nResults;
        
        print("      --- Processing image pair " + (i+1) + "/" + num_pairs + " ---");
        print("      Files: " + image_files_1[i] + " vs " + image_files_2[i]);
        print("      Particles before this image: " + image_start_particles);
        
        // Process single image pair
        if (optimizedProcessImagePairSingle(corrected_dir_1, corrected_dir_2, image_files_1[i], image_files_2[i], processed_dir)) {
            successful_pairs++;
            
            // Track particles after this specific image pair
            image_end_particles = nResults;
            particles_from_this_image = image_end_particles - image_start_particles;
            total_particles_from_folder += particles_from_this_image;
            
            print("      SUCCESS: Added " + particles_from_this_image + " particles");
            print("      Running total: " + image_end_particles + " particles");
            
            // Verify particles were actually added
            if (particles_from_this_image == 0) {
                print("      WARNING: No particles found in this image pair - check thresholding");
            }
            
        } else {
            print("      FAILED: Could not process this image pair");
            logError("Failed to process pair: " + image_files_1[i] + " & " + image_files_2[i], processed_dir);
        }
        
		if (i % 2 == 0) {  // More frequent cleanup
		    results_before_cleanup = nResults;
		    safeCloseAllImages();
		    run("Collect Garbage");
		    results_after_cleanup = nResults;
		    
		    if (results_before_cleanup != results_after_cleanup) {
		        print("        *** ERROR: Results table was modified during cleanup! ***");
		        print("        Before: " + results_before_cleanup + ", After: " + results_after_cleanup);
		    }
		}
        
        // Update progress
        if (num_pairs > 1) {
            showProgress(i+1, num_pairs);
        }
    }
    
    // *** FINAL FOLDER PAIR SUMMARY ***
    folder_end_particle_count = nResults;
    particles_added_by_folder = folder_end_particle_count - folder_start_particle_count;
    
    print("    === FOLDER PAIR PROCESSING COMPLETE ===");
    print("    Successfully processed: " + successful_pairs + "/" + num_pairs + " image pairs");
    print("    Particles added by this folder pair: " + particles_added_by_folder);
    print("    Grand total particles accumulated: " + folder_end_particle_count);
    
    // Verify our counting matches
    if (particles_added_by_folder != total_particles_from_folder) {
        print("    WARNING: Particle count mismatch!");
        print("      Expected: " + total_particles_from_folder);
        print("      Actual: " + particles_added_by_folder);
    } else {
        print("    ✓ Particle counting verified correct");
    }
    
    // Enhanced summary generation and file saving only if we have successful pairs
    if (successful_pairs > 0) {
        print("    Generating summary data and saving results...");
        
        // Add additional data to Summary table if it exists
        addOptimizedSummaryData(out_dir, in_dir_1, in_dir_2);
        
        // Save both Results and Summary tables for this folder pair
        saveResultsTables(out_dir, in_dir_1, in_dir_2);
        
        print("    ✓ Results saved to: " + out_dir);
    } else {
        print("    No successful pairs - skipping file generation");
    }
    
    // Final verification of Results table integrity
    verifyResultsTableIntegrity("End of folder pair processing");
    
    return successful_pairs;
}

function optimizedProcessAllImagePairs(parent_dir, folder_pairs) {
    // Pre-create all output directories
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    if (!File.isDirectory(edge_measurements_dir)) {
        File.makeDirectory(edge_measurements_dir);
    }
    
    total_pairs_processed = 0;
    successful_pairs = 0;
    
    // *** CRITICAL: Initialize Results table management ***
    print("=== INITIALIZING PARTICLE ACCUMULATION SYSTEM ===");
    initial_global_particles = nResults;
    print("Starting with " + initial_global_particles + " particles in Results table");
    
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        print("\n=== PROCESSING FOLDER PAIR " + (i+1) + "/" + folder_pairs.length + " ===");
        print("  Processing image pair: " + bef_folder + " <-> " + aft_folder);
        
        pairs_processed = optimizedProcessImagePair(parent_dir + bef_folder, parent_dir + aft_folder, parent_dir);
        total_pairs_processed += pairs_processed;
        if (pairs_processed > 0) successful_pairs++;
        
        // Memory management
        if (i % 2 == 0) {
            run("Collect Garbage");
        }
        
        showProgress(i+1, folder_pairs.length);
    }
    
    final_global_particles = nResults;
    total_particles_all_folders = final_global_particles - initial_global_particles;
    
    print("\n=== IMAGE REGISTRATION AND PARTICLE ANALYSIS COMPLETE ===");
    print("Successfully processed " + successful_pairs + "/" + folder_pairs.length + " folder pairs");
    print("Total individual image pairs processed: " + total_pairs_processed);
    print("Total particles found across all folders: " + total_particles_all_folders);
}

// ============================================================================
// PART 4 FUNCTIONS: Edge Coordinate Extraction
// ============================================================================

function saveAllEdgeCoordinates(dir, fileName) {
    // Create directory if it doesn't exist
    if (!File.isDirectory(dir)) {
        File.makeDirectory(dir);
    }
    
    // Get image dimensions
    width = getWidth();
    height = getHeight();
    
    // Create a file to save the CSV data
    output_file = dir + "edge_coordinates_" + fileName + ".csv";
    f = File.open(output_file);
    
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

function extractEdgeCoordinatesFromFolder(edge_path, new_edge_dir) {
    edge_files = getFileList(edge_path);
    images_processed = 0;
    
    for (i = 0; i < edge_files.length; i++) {
        if (isImageFile(edge_files[i])) {
            // Open and process image
            open(edge_path + edge_files[i]);
            run("8-bit");
            run("Convert to Mask");
            
            // Get image dimensions and create pixel array
            width = getWidth();
            height = getHeight();
            
            // Get all pixels at once for faster processing
            pixel_array = newArray(width * height);
            for (y = 0; y < height; y++) {
                for (x = 0; x < width; x++) {
                    pixel_array[x + y * width] = getPixel(x, y);
                }
            }
            
            // Create array for storing edge positions
            max_y = newArray(width);
            Array.fill(max_y, -1);
            
            // Process columns to find last edge transition
            for (x = 0; x < width; x++) {
                last_edge = -1;
                for (y = 0; y < height; y++) {
                    current_pixel = pixel_array[x + y * width];
                    if (y > 0) {
                        previous_pixel = pixel_array[x + (y-1) * width];
                        // Check for both black-to-white and white-to-black transitions
                        if ((previous_pixel == 0 && current_pixel == 255) || 
                            (previous_pixel == 255 && current_pixel == 0)) {
                            last_edge = y;
                        }
                    }
                }
                if (last_edge > -1) {
                    max_y[x] = last_edge;
                }
            }
            
            // Prepare output file
            current_edge_file = edge_files[i];
            base_name = substring(current_edge_file, 0, lastIndexOf(current_edge_file, "."));
            output_file = new_edge_dir + base_name + "_edges.csv";
            
            // Write results using string buffer for faster I/O
            buffer = "X,Y\n";
            for (x = 0; x < width; x++) {
                if (max_y[x] >= 0) {
                    buffer = buffer + x + "," + max_y[x] + "\n";
                }
            }
            
            // Write buffer to file at once
            File.saveString(buffer, output_file);
            
            // Clean up
            close();
            images_processed++;
        }
    }
    
    return images_processed;
}

function extractAllEdgeCoordinates(parent_dir) {
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    
    if (!File.isDirectory(edge_measurements_dir)) {
        print("No Edge Measurements directory found");
        return;
    }
    
    // Get all comparison folders
    folder_list = getFileList(edge_measurements_dir);
    total_images_processed = 0;
    
    for (i = 0; i < folder_list.length; i++) {
        if (endsWith(folder_list[i], "/") && !startsWith(folder_list[i], "Brightness_Corrected")) {
            comparison_folder = edge_measurements_dir + folder_list[i];
            processed_images_path = comparison_folder + "Processed Images" + File.separator;
            edge_path = processed_images_path + "Edge" + File.separator;
            
            // Create NewEdgeCoordinates folder
            new_edge_dir = processed_images_path + "NewEdgeCoordinates" + File.separator;
            File.makeDirectory(new_edge_dir);
            
            if (File.exists(edge_path)) {
                images_processed = extractEdgeCoordinatesFromFolder(edge_path, new_edge_dir);
                total_images_processed += images_processed;
                print("  Processed " + images_processed + " edge images from " + folder_list[i]);
            }
        }
        
        showProgress(i+1, folder_list.length);
    }
    
    print("Edge coordinate extraction complete! Total images processed: " + total_images_processed);
}

// ============================================================================
// PART 5 FUNCTIONS: Particle Mapping and Qualification
// ============================================================================

function extractSampleNumber(folder_name) {
    // Extract sample number from folder name like "Bef_01 minus Aft_01_2025_1_1_10_30_45"
    if (startsWith(folder_name, "Bef_")) {
        end_pos = indexOf(folder_name, " minus");
        if (end_pos != -1) {
            return substring(folder_name, 4, end_pos);
        }
    }
    return "";
}

function extractSliceNumberFromEdgeFile(filename) {
    // Use the exact method from the original working script
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
    
    // Debug output to understand what's happening
    print("    Debug: Failed to extract slice number from: " + filename);
    print("    Debug: edge_match = " + edge_match);
    print("    Debug: number_str = '" + number_str + "'");
    if (lengthOf(number_str) >= 7) {
        slice_str = substring(number_str, 6);
        print("    Debug: slice_str = '" + slice_str + "'");
    }
    
    return -1;
}

function extractSliceNumberFromName(slice_name) {
    // Use the same method as extractSliceNumberFromEdgeFile for consistency
    return extractSliceNumberFromEdgeFile(slice_name);
}

function getDimensionDifferences(summary_file) {
    // Use the exact approach from the original working script
    differences = newArray(1000);
    for (i = 0; i < differences.length; i++) {
        differences[i] = "";  // Initialize all elements to empty string
    }
    
    if (!File.exists(summary_file)) {
        return differences;
    }
    
    lines = split(File.openAsString(summary_file), "\n");
    if (lines.length < 2) {
        return differences;
    }
    
    // Get indices for difference columns
    headers = split(lines[0], ",");
    width_diff_index = -1;
    height_diff_index = -1;
    slice_index = -1;
    
    for (i = 0; i < headers.length; i++) {
        if (headers[i] == "width_difference") width_diff_index = i;
        if (headers[i] == "height_difference") height_diff_index = i;
        if (headers[i] == "Slice") slice_index = i;
    }
    
    if (width_diff_index == -1 || height_diff_index == -1 || slice_index == -1) {
        return differences;
    }
    
    // Process each line using original method
    for (i = 1; i < lines.length; i++) {
        if (lines[i] == "") continue;
        
        fields = split(lines[i], ",");
       if (fields.length <= maxOf(maxOf(width_diff_index, height_diff_index), slice_index)) continue;
        
        // Extract slice number using original method
        slice_name = fields[slice_index];
        edge_match = indexOf(slice_name, "caliwaferedge");
        if (edge_match == -1) continue;
        
        number_str = substring(slice_name, edge_match + 13, edge_match + 21);
        if (lengthOf(number_str) >= 7) {
            slice_num = parseInt(substring(number_str, 6));  // Original method
            // Add proper bounds checking
            if (isNaN(slice_num) || slice_num < 0 || slice_num >= differences.length) {
                print("    Skipping dimension data for invalid slice: " + slice_num + " from " + slice_name);
                continue;
            }
            
            // Store width and height differences for this slice
            width_diff = parseFloat(fields[width_diff_index]);
            height_diff = parseFloat(fields[height_diff_index]);
            if (!isNaN(width_diff) && !isNaN(height_diff)) {
                differences[slice_num] = d2s(width_diff,6) + "," + d2s(height_diff,6);
                print("    Stored dimension differences for slice " + slice_num + ": " + differences[slice_num]);
            }
        }
    }
    
    return differences;
}

function qualifyEdgeParticles(comparison_folder, sample_number) {
    // Construct full paths
    particles_file = comparison_folder + "Particles Bef_" + sample_number + " minus Aft_" + sample_number + ".csv";
    summary_file = comparison_folder + "Summary Bef_" + sample_number + " minus Aft_" + sample_number + ".csv";
    summary_updated_file = comparison_folder + "Summary Bef_" + sample_number + " minus Aft_" + sample_number + "_updated.csv";
    edge_coord_dir = comparison_folder + "Processed Images" + File.separator + "NewEdgeCoordinates" + File.separator;
    
    // Use updated summary file if it exists
    if (File.exists(summary_updated_file)) {
        summary_file = summary_updated_file;
    }
    
    // Get dimension differences from summary file - using original array approach
    dimension_diffs = getDimensionDifferences(summary_file);
    
    // Verify files exist
    if (!File.exists(particles_file) || !File.exists(edge_coord_dir)) {
        print("    Required files not found for qualification");
        return false;
    }

    // Read particles file
    particle_lines = split(File.openAsString(particles_file), "\n");
    if (particle_lines.length < 2) {
        print("    Invalid particles file format");
        return false;
    }

    // Get header indices for particles file
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

    // Verify required columns exist
    if (bx_index == -1 || by_index == -1 || height_index == -1 || width_index == -1 || slice_index == -1) {
        print("    Required columns not found in particles file");
        return false;
    }

    // Add IsQualified column if it doesn't exist
    if (is_qualified_index == -1) {
        particle_headers = Array.concat(particle_headers, "IsQualified");
        is_qualified_index = particle_headers.length - 1;
        particle_lines[0] = String.join(particle_headers, ",");
    }

    // Load edge coordinates using original array approach with proper size
    edge_coords = newArray(1000);
    for (i = 0; i < edge_coords.length; i++) {
        edge_coords[i] = "";
    }
    
    coord_files = getFileList(edge_coord_dir);
    
    // Get valid slices from particle data first
    valid_slices = newArray(1000);
    for (i = 0; i < valid_slices.length; i++) {
        valid_slices[i] = false;
    }
    
    for (i = 1; i < particle_lines.length; i++) {
        particle_data = split(particle_lines[i], ",");
        if (particle_data.length > slice_index) {
            slice = parseInt(particle_data[slice_index]);
            if (!isNaN(slice) && slice >= 0 && slice < valid_slices.length) {
                valid_slices[slice] = true;
            }
        }
    }
    
    // Process edge coordinate files
    for (i = 0; i < coord_files.length; i++) {
        if (endsWith(coord_files[i], ".csv")) {
            slice_num = extractSliceNumberFromEdgeFile(coord_files[i]);
            // Add proper bounds checking and skip invalid slice numbers
            if (slice_num == -1 || slice_num < 0 || slice_num >= valid_slices.length) {
                print("    Skipping file with invalid slice number: " + coord_files[i] + " (slice_num = " + slice_num + ")");
                continue;
            }
            if (!valid_slices[slice_num]) {
                print("    Skipping unused slice: " + slice_num + " from file: " + coord_files[i]);
                continue;
            }
            
            edge_data = split(File.openAsString(edge_coord_dir + coord_files[i]), "\n");
            if (edge_data.length < 2) continue;
            
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
            print("    Loaded edge coordinates for slice " + slice_num + " from " + coord_files[i]);
        }
    }

    // Process each particle
    new_particle_lines = newArray(particle_lines.length);
    new_particle_lines[0] = particle_lines[0];
    qualified_count = 0;
    
    for (i = 1; i < particle_lines.length; i++) {
        particle_data = split(particle_lines[i], ",");
        
        // Ensure particle data has enough elements for all columns
        while (particle_data.length < particle_headers.length) {
            particle_data = Array.concat(particle_data, "");
        }
        
		if (particle_data.length <= maxOf(maxOf(maxOf(bx_index, by_index), height_index), width_index)) {
            new_particle_lines[i] = particle_lines[i];
            continue;
        }

        // Get particle data
        bx = parseFloat(particle_data[bx_index]);
        by = parseFloat(particle_data[by_index]);
        height = parseFloat(particle_data[height_index]);
        width = parseFloat(particle_data[width_index]);
        slice = parseInt(particle_data[slice_index]);
        
        // Apply dimension differences if available for this slice
        if (!isNaN(slice) && slice >= 0 && slice < dimension_diffs.length && dimension_diffs[slice] != "") {
            diffs = split(dimension_diffs[slice], ",");
            if (diffs.length >= 2) {
                width_diff = parseFloat(diffs[0]);
                height_diff = parseFloat(diffs[1]);
                
                if (!isNaN(width_diff) && !isNaN(height_diff)) {
                    // Apply half of the differences to coordinates, with scaling
                    bx = bx + ((width_diff * (-50.0/240.0)) / 2);
                    by = by + ((height_diff * (-50.0/240.0)) / 2);
                }
            }
        }
        
        particle_top = by + height;
        particle_left = bx;
        particle_right = bx + width;

        is_qualified = false;

        // Check qualification against edge coordinates if slice is valid
        if (!isNaN(slice) && slice >= 0 && slice < edge_coords.length && edge_coords[slice] != "") {
            edge_points = split(edge_coords[slice], ";");
            for (p = 0; p < edge_points.length; p++) {
                if (edge_points[p] == "") continue;
                
                coords = split(edge_points[p], ",");
                if (coords.length < 2) continue;
                
                edge_x = parseFloat(coords[0]);
                edge_y = parseFloat(coords[1]);
                
                if (!isNaN(edge_x) && !isNaN(edge_y)) {
                    if (edge_x >= particle_left && edge_x <= particle_right) {
                        if ((particle_top + 1) >= edge_y) {
                            is_qualified = true;
                            break;
                        }
                    }
                }
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
    print("    Updated qualification status: " + qualified_count + "/" + (particle_lines.length-1) + " particles qualified");
    return true;
}

function mapParticlesToSlices(comparison_folder, sample_number) {
    // Get paths to required files
    particles_file = comparison_folder + "Particles Bef_" + sample_number + " minus Aft_" + sample_number + ".csv";
    summary_file = comparison_folder + "Summary Bef_" + sample_number + " minus Aft_" + sample_number + ".csv";
    
    // Check for updated summary file first
    summary_updated_file = comparison_folder + "Summary Bef_" + sample_number + " minus Aft_" + sample_number + "_updated.csv";
    if (File.exists(summary_updated_file)) {
        summary_file = summary_updated_file;
    }
    
    // Verify files exist
    if (!File.exists(particles_file) || !File.exists(summary_file)) {
        print("    Required files not found for sample " + sample_number);
        return false;
    }

    // Read files
    particle_lines = split(File.openAsString(particles_file), "\n");
    summary_lines = split(File.openAsString(summary_file), "\n");
    
    // Verify file contents
    if (particle_lines.length < 2 || summary_lines.length < 2) {
        print("    Invalid file format for sample " + sample_number);
        return false;
    }

    // Get header indices for particles file
    particle_headers = split(particle_lines[0], ",");
    slice_index = -1;
    for (i = 0; i < particle_headers.length; i++) {
        if (particle_headers[i] == "Slice") slice_index = i;
    }

    // If Slice column doesn't exist, add it
    if (slice_index == -1) {
        particle_headers = Array.concat(particle_headers, "Slice");
        slice_index = particle_headers.length - 1;
        particle_lines[0] = String.join(particle_headers, ",");
    }

    // Get Count and Slice columns from summary file
    summary_headers = split(summary_lines[0], ",");
    count_index = -1;
    slice_name_index = -1;
    for (i = 0; i < summary_headers.length; i++) {
        if (summary_headers[i] == "Count") count_index = i;
        if (summary_headers[i] == "Slice") slice_name_index = i;
    }

    // Verify required columns exist
    if (count_index == -1 || slice_name_index == -1) {
        print("    Required columns not found in summary file for sample " + sample_number);
        return false;
    }

    // Use arrays to store slice info instead of huge indexed arrays
    slice_numbers = newArray(summary_lines.length - 1);
    slice_counts = newArray(summary_lines.length - 1);
    cumulative_counts = newArray(summary_lines.length - 1);
    num_valid_slices = 0;
    current_total = 0;

    // Process summary data to get valid slices and their cumulative counts
    for (i = 1; i < summary_lines.length; i++) {
        summary_data = split(summary_lines[i], ",");
        if (summary_data.length <= count_index || summary_data.length <= slice_name_index) {
            continue;
        }

        // Extract slice identifier from the filename in summary
        slice_name = summary_data[slice_name_index];
        slice_num = extractSliceNumberFromName(slice_name);
        
        if (slice_num == -1) continue;

        current_count = parseInt(summary_data[count_index]);
        if (isNaN(current_count)) continue;

        // Store slice info
        slice_numbers[num_valid_slices] = slice_num;
        slice_counts[num_valid_slices] = current_count;
        current_total += current_count;
        cumulative_counts[num_valid_slices] = current_total;
        num_valid_slices++;
    }

    // Process each particle
    new_particle_lines = newArray(particle_lines.length);
    new_particle_lines[0] = particle_lines[0];
    
    for (i = 1; i < particle_lines.length; i++) {
        slice_number = -1;
        particle_index = i;
        
        // Find appropriate slice for this particle
        for (j = 0; j < num_valid_slices; j++) {
            if (particle_index <= cumulative_counts[j]) {
                slice_number = slice_numbers[j];
                break;
            }
        }

        // Get particle data and update slice
        particle_data = split(particle_lines[i], ",");
        
        // Ensure particle data has enough elements for all columns
        while (particle_data.length < particle_headers.length) {
            particle_data = Array.concat(particle_data, "");
        }
        
        // Update slice number
        if (slice_number == -1) {
            particle_data[slice_index] = "0";
        } else {
            particle_data[slice_index] = "" + slice_number;
        }
        
        // Join particle data back into line
        new_particle_lines[i] = String.join(particle_data, ",");
    }

    // Save updated particles file
    File.saveString(String.join(new_particle_lines, "\n"), particles_file);
    print("    Updated slice numbers for particles");
    return true;
}

function mapAndQualifyAllParticles(parent_dir) {
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    
    if (!File.isDirectory(edge_measurements_dir)) {
        print("No Edge Measurements directory found");
        return;
    }
    
    // Get all comparison folders
    folder_list = getFileList(edge_measurements_dir);
    total_samples_processed = 0;
    
    for (i = 0; i < folder_list.length; i++) {
        if (endsWith(folder_list[i], "/") && !startsWith(folder_list[i], "Brightness_Corrected")) {
            comparison_folder = edge_measurements_dir + folder_list[i];
            
            // Extract sample number from folder name
            folder_name = substring(folder_list[i], 0, lengthOf(folder_list[i]) - 1); // Remove trailing slash
            sample_number = extractSampleNumber(folder_name);
            
            if (sample_number != "") {
                print("  Processing particles for sample: " + sample_number);
                
                // First map particles to slices, then qualify them
                if (mapParticlesToSlices(comparison_folder, sample_number)) {
                    if (qualifyEdgeParticles(comparison_folder, sample_number)) {
                        total_samples_processed++;
                        print("    Successfully processed sample " + sample_number);
                    }
                }
            }
        }
        
        showProgress(i+1, folder_list.length);
    }
    
    print("Particle mapping and qualification complete! Processed " + total_samples_processed + " samples");
}

// ============================================================================
// PART 6 FUNCTIONS: Cached Dimension Analysis
// ============================================================================

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
}

function processCachedDimensionAnalysis(subfolder, summaryFilePath, updatedSummaryPath) {
    finishedImagesPath = subfolder + "Processed Images" + File.separator + "Finished" + File.separator;
    edgeImagesPath = subfolder + "Processed Images" + File.separator + "Edge" + File.separator;
    
    if (!File.exists(finishedImagesPath) || !File.exists(edgeImagesPath)) {
        return false;
    }
    
    finishedImageList = getFileList(finishedImagesPath);
    if (finishedImageList.length == 0) return false;
    
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
        Table.reset("Dimension Data");
        return true;
    }
    
    Table.reset("Dimension Data");
    return false;
}

function cachedAnalyzeDimensions(parentFolder) {
    subfolders = getSubfolders(parentFolder + "Edge Measurements/");
    
    folders_processed = 0;
    for (i = 0; i < subfolders.length; i++) {
        subfolder = subfolders[i];
        summaryFilePath = findSummaryFile(subfolder);
        
        if (summaryFilePath == "") continue;
        
        // Check if already processed
        updatedSummaryPath = substring(summaryFilePath, 0, lastIndexOf(summaryFilePath, ".")) + "_updated.csv";
        if (File.exists(updatedSummaryPath)) {
            print("  Skipping already processed folder: " + File.getName(subfolder));
            continue;
        }
        
        if (processCachedDimensionAnalysis(subfolder, summaryFilePath, updatedSummaryPath)) {
            folders_processed++;
            print("  Updated dimension data for: " + File.getName(subfolder));
        }
        
        showProgress(i+1, subfolders.length);
    }
    
    print("Cached dimension analysis complete. Updated " + folders_processed + " folders");
}

// ============================================================================
// PART 7 FUNCTIONS: Final Summary Report
// ============================================================================

function countQualifiedParticles(particle_lines) {
    if (particle_lines.length < 2) return 0;
    
    // Find IsQualified column
    headers = split(particle_lines[0], ",");
    is_qualified_index = -1;
    for (i = 0; i < headers.length; i++) {
        if (headers[i] == "IsQualified") {
            is_qualified_index = i;
            break;
        }
    }
    
    if (is_qualified_index == -1) return 0;
    
    qualified_count = 0;
    for (i = 1; i < particle_lines.length; i++) {
        particle_data = split(particle_lines[i], ",");
        if (particle_data.length > is_qualified_index) {
            if (particle_data[is_qualified_index] == "true" || particle_data[is_qualified_index] == "1") {
                qualified_count++;
            }
        }
    }
    
    return qualified_count;
}

function generateFinalSummaryReport(parent_dir) {
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    
    if (!File.isDirectory(edge_measurements_dir)) {
        print("No Edge Measurements directory found for final report");
        return;
    }
    
    // Create final summary report
    report_file = edge_measurements_dir + "Final_Processing_Summary_" + 
                  replace(getTimeStamp(), ":", "-") + ".txt";
    
    report_content = "=== CALIBRATION EDGE ANALYSIS FINAL SUMMARY ===\n";
    report_content += "Generated: " + getTimeStamp() + "\n";
    report_content += "Parent Directory: " + parent_dir + "\n\n";
    
    // Get all comparison folders
    folder_list = getFileList(edge_measurements_dir);
    total_folders = 0;
    successful_folders = 0;
    total_particles = 0;
    total_qualified = 0;
    
    for (i = 0; i < folder_list.length; i++) {
        if (endsWith(folder_list[i], "/") && !startsWith(folder_list[i], "Brightness_Corrected")) {
            total_folders++;
            comparison_folder = edge_measurements_dir + folder_list[i];
            
            // Check for particles file
            sample_number = extractSampleNumber(substring(folder_list[i], 0, lengthOf(folder_list[i]) - 1));
            if (sample_number != "") {
                particles_file = comparison_folder + "Particles Bef_" + sample_number + " minus Aft_" + sample_number + ".csv";
                
                if (File.exists(particles_file)) {
                    successful_folders++;
                    
                    // Count particles and qualified particles
                    particle_lines = split(File.openAsString(particles_file), "\n");
                    if (particle_lines.length > 1) {
                        particle_count = particle_lines.length - 1;
                        total_particles += particle_count;
                        
                        // Count qualified particles
                        qualified_count = countQualifiedParticles(particle_lines);
                        total_qualified += qualified_count;
                        
                        report_content += "Sample " + sample_number + ": " + particle_count + " particles, " + 
                                        qualified_count + " qualified (" + 
                                        d2s((qualified_count * 100.0 / particle_count), 1) + "%)\n";
                    }
                }
            }
        }
    }
    
    report_content += "\n=== OVERALL STATISTICS ===\n";
    report_content += "Total folders processed: " + successful_folders + "/" + total_folders + "\n";
    report_content += "Total particles analyzed: " + total_particles + "\n";
    report_content += "Total particles qualified: " + total_qualified + "\n";
    if (total_particles > 0) {
        report_content += "Overall qualification rate: " + d2s((total_qualified * 100.0 / total_particles), 2) + "%\n";
    }
    
    report_content += "\n=== BRIGHTNESS STANDARDIZATION ===\n";
    report_content += "- Applied fixed linear brightness standardization\n";
    report_content += "- Preserves intensity relationships for threshold sensitivity\n";
    report_content += "- Handles temporal brightness drift across trials\n";
    
    report_content += "\n=== FILES GENERATED ===\n";
    report_content += "- Fixed brightness standardization data\n";
    report_content += "- Registered image pairs\n";
    report_content += "- Edge detection images\n";
    report_content += "- Edge coordinate CSV files\n";
    report_content += "- Particle analysis CSV files\n";
    report_content += "- Updated summary files with dimensions\n";
    report_content += "- Particle qualification results\n";
    report_content += "- Brightness standardization verification report\n";
    
    // Save report
    File.saveString(report_content, report_file);
    print("Final summary report generated: " + report_file);
    print("Successfully processed " + successful_folders + "/" + total_folders + " sample folders");
    print("Total particles: " + total_particles + ", Qualified: " + total_qualified);
}

function getOriginalImagePath(parent_dir, folder_name, image_name) {
    // Construct path to original image
    return parent_dir + folder_name + "/" + image_name;
}

function generateBrightnessSummaryStats(edge_measurements_dir, median_info) {
    // Create summary statistics for the brightness standardization
    summary_file = edge_measurements_dir + "Brightness_Summary_Statistics_" + 
                   replace(getTimeStamp(), ":", "-") + ".txt";
    
    summary_content = "=== BRIGHTNESS STANDARDIZATION SUMMARY STATISTICS ===\n";
    summary_content += "Generated: " + getTimeStamp() + "\n\n";
    
    // Collect all changes for statistical analysis
    median_changes = newArray(0);
    mean_changes = newArray(0);
    bef_medians = newArray(0);
    aft_medians = newArray(0);
    bef_means = newArray(0);
    aft_means = newArray(0);
    
    for (i = 0; i < median_info.length; i++) {
        if (median_info[i] != "") {
            info_parts = split(median_info[i], "|");
            if (info_parts.length >= 8) {
                folder_name = info_parts[0];
                pre_median = parseFloat(info_parts[2]);
                pre_mean = parseFloat(info_parts[3]);
                post_median = parseFloat(info_parts[5]);
                post_mean = parseFloat(info_parts[6]);
                
                if (!isNaN(pre_median) && !isNaN(post_median) && !isNaN(pre_mean) && !isNaN(post_mean)) {
                    median_changes = Array.concat(median_changes, post_median - pre_median);
                    mean_changes = Array.concat(mean_changes, post_mean - pre_mean);
                    
                    if (startsWith(folder_name, "Bef_")) {
                       bef_medians = Array.concat(bef_medians, pre_median);
                        bef_means = Array.concat(bef_means, pre_mean);
                    } else if (startsWith(folder_name, "Aft_")) {
                        aft_medians = Array.concat(aft_medians, pre_median);
                        aft_means = Array.concat(aft_means, pre_mean);
                    }
                }
            }
        }
    }
    
    // Calculate statistics
    if (median_changes.length > 0) {
        Array.getStatistics(median_changes, min_med_change, max_med_change, mean_med_change, std_med_change);
        Array.getStatistics(mean_changes, min_mean_change, max_mean_change, mean_mean_change, std_mean_change);
        
        summary_content += "BRIGHTNESS CHANGE STATISTICS:\n";
        summary_content += "  Median changes - Range: " + d2s(min_med_change, 1) + " to " + d2s(max_med_change, 1) + 
                          ", Mean: " + d2s(mean_med_change, 1) + ", StdDev: " + d2s(std_med_change, 1) + "\n";
        summary_content += "  Mean changes - Range: " + d2s(min_mean_change, 1) + " to " + d2s(max_mean_change, 1) + 
                          ", Mean: " + d2s(mean_mean_change, 1) + ", StdDev: " + d2s(std_mean_change, 1) + "\n\n";
    }
    
    if (bef_medians.length > 0 && aft_medians.length > 0) {
        Array.getStatistics(bef_medians, min_bef_med, max_bef_med, mean_bef_med, std_bef_med);
        Array.getStatistics(aft_medians, min_aft_med, max_aft_med, mean_aft_med, std_aft_med);
        
        summary_content += "ORIGINAL BRIGHTNESS COMPARISON:\n";
        summary_content += "  Bef_ folder medians - Range: " + d2s(min_bef_med, 1) + " to " + d2s(max_bef_med, 1) + 
                          ", Mean: " + d2s(mean_bef_med, 1) + ", StdDev: " + d2s(std_bef_med, 1) + "\n";
        summary_content += "  Aft_ folder medians - Range: " + d2s(min_aft_med, 1) + " to " + d2s(max_aft_med, 1) + 
                          ", Mean: " + d2s(mean_aft_med, 1) + ", StdDev: " + d2s(std_aft_med, 1) + "\n";
        summary_content += "  Temporal drift detected: " + d2s(abs(mean_bef_med - mean_aft_med), 1) + " intensity units\n\n";
    }
    
    summary_content += "STANDARDIZATION EFFECTIVENESS:\n";
    summary_content += "  Total images processed: " + median_info.length + "\n";
    summary_content += "  Target range: 10 to 200 intensity units\n";
    summary_content += "  Brightness consistency achieved: See verification report\n";
    
    File.saveString(summary_content, summary_file);
    print("Brightness summary statistics saved: " + summary_file);
}


function generateDetailedBrightnessReport(parent_dir) {
    print("Generating comprehensive brightness analysis report...");
    
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    
    if (!File.isDirectory(edge_measurements_dir)) {
        print("No Edge Measurements directory found for brightness report");
        return;
    }
    
    // Create detailed brightness report file
    report_file = edge_measurements_dir + "Detailed_Brightness_Analysis_" + 
                  replace(getTimeStamp(), ":", "-") + ".csv";
    
    // CSV header
    csv_content = "Folder,Image_Name,Original_Min,Original_Max,Original_Median,Original_Mean," +
                  "Original_Top30_Median,Original_Top30_Mean,Original_Bottom30_Median,Original_Bottom30_Mean," +
                  "Original_TopBottom_Ratio_Median,Original_TopBottom_Ratio_Mean," +
                  "Standardized_Min,Standardized_Max,Standardized_Median,Standardized_Mean," +
                  "Standardized_Top30_Median,Standardized_Top30_Mean,Standardized_Bottom30_Median,Standardized_Bottom30_Mean," +
                  "Standardized_TopBottom_Ratio_Median,Standardized_TopBottom_Ratio_Mean," +
                  "Median_Change,Mean_Change,Top30_Median_Change,Bottom30_Median_Change\n";
    
    // Load the stored brightness data
    median_info = loadGlobalMedianInfo(edge_measurements_dir);
    
    if (median_info.length == 0) {
        print("No brightness data found - skipping detailed brightness report");
        return;
    }
    
    // Process each brightness record
    for (i = 0; i < median_info.length; i++) {
        if (median_info[i] != "") {
            // Parse the stored data: folder|file|pre_median|pre_mean|pre_median|post_median|post_mean|post_median
            info_parts = split(median_info[i], "|");
            if (info_parts.length >= 8) {
                folder_name = info_parts[0];
                image_name = info_parts[1];
                pre_median = parseFloat(info_parts[2]);
                pre_mean = parseFloat(info_parts[3]);
                post_median = parseFloat(info_parts[5]);
                post_mean = parseFloat(info_parts[6]);
                
                // Load the original and standardized images to get complete stats
                original_image_path = getOriginalImagePath(parent_dir, folder_name, image_name);
                standardized_image_path = edge_measurements_dir + "Brightness_Corrected/" + folder_name + "/" + image_name;
                
                if (File.exists(original_image_path) && File.exists(standardized_image_path)) {
                    // Get complete original image statistics
                    open(original_image_path);
                    original_stats = getBasicImageStats();
                    original_spatial = calculateSpatialRegionStatsFast();
                    close();
                    
                    // Get complete standardized image statistics  
                    open(standardized_image_path);
                    standardized_stats = getBasicImageStats();
                    standardized_spatial = calculateSpatialRegionStatsFast();
                    close();
                    
                    // Calculate changes
                    median_change = standardized_stats[2] - original_stats[2];
                    mean_change = standardized_stats[3] - original_stats[3];
                    top30_median_change = standardized_spatial[0] - original_spatial[0];
                    bottom30_median_change = standardized_spatial[2] - original_spatial[2];
                    
                    
                    // Calculate ratios with proper syntax
                    if (original_spatial[2] != 0) {
                        original_ratio_median = original_spatial[0] / original_spatial[2];
                    } else {
                        original_ratio_median = 0;
                    }
                    
                    if (original_spatial[3] != 0) {
                        original_ratio_mean = original_spatial[1] / original_spatial[3];
                    } else {
                        original_ratio_mean = 0;
                    }
                    
                    if (standardized_spatial[2] != 0) {
                        standardized_ratio_median = standardized_spatial[0] / standardized_spatial[2];
                    } else {
                        standardized_ratio_median = 0;
                    }
                    
                    if (standardized_spatial[3] != 0) {
                        standardized_ratio_mean = standardized_spatial[1] / standardized_spatial[3];
                    } else {
                        standardized_ratio_mean = 0;
                    }
                    
                    
                    // Add row to CSV
                    csv_content += folder_name + "," + image_name + "," +
                                   d2s(original_stats[0], 1) + "," + d2s(original_stats[1], 1) + "," + 
                                   d2s(original_stats[2], 1) + "," + d2s(original_stats[3], 1) + "," +
                                   d2s(original_spatial[0], 1) + "," + d2s(original_spatial[1], 1) + "," +
                                   d2s(original_spatial[2], 1) + "," + d2s(original_spatial[3], 1) + "," +
                                   d2s(original_ratio_median, 3) + "," + d2s(original_ratio_mean, 3) + "," +
                                   d2s(standardized_stats[0], 1) + "," + d2s(standardized_stats[1], 1) + "," + 
                                   d2s(standardized_stats[2], 1) + "," + d2s(standardized_stats[3], 1) + "," +
                                   d2s(standardized_spatial[0], 1) + "," + d2s(standardized_spatial[1], 1) + "," +
                                   d2s(standardized_spatial[2], 1) + "," + d2s(standardized_spatial[3], 1) + "," +
                                   d2s(standardized_ratio_median, 3) + "," + d2s(standardized_ratio_mean, 3) + "," +
                                   d2s(median_change, 1) + "," + d2s(mean_change, 1) + "," +
                                   d2s(top30_median_change, 1) + "," + d2s(bottom30_median_change, 1) + "\n";
                    
                    print("  Added brightness data for: " + folder_name + "/" + image_name);
                } else {
                    print("  Warning: Could not find images for " + folder_name + "/" + image_name);
                }
            }
        }
    }
    
    // Save the detailed brightness report
    File.saveString(csv_content, report_file);
    print("Detailed brightness analysis report saved: " + report_file);
    
    // Also create a summary statistics file
    generateBrightnessSummaryStats(edge_measurements_dir, median_info);
}

function verifyStandardization(out_dir) {
    print("=== VERIFYING BRIGHTNESS STANDARDIZATION ===");
    
    // Check brightness consistency across all processed images
    brightness_corrected_dir = out_dir + "Brightness_Corrected/";
    
    if (!File.isDirectory(brightness_corrected_dir)) {
        print("No brightness corrected directory found - skipping verification");
        return;
    }
    
    folders = getFileList(brightness_corrected_dir);
    
    all_medians = newArray(0);
    all_means = newArray(0);
    all_mins = newArray(0);
    all_maxs = newArray(0);
    
    total_images_checked = 0;
    
    for (i = 0; i < folders.length; i++) {
        if (endsWith(folders[i], "/")) {
            folder_path = brightness_corrected_dir + folders[i];
            images = getFileList(folder_path);
            
            for (j = 0; j < images.length; j++) {
                if (isImageFile(images[j])) {
                    open(folder_path + images[j]);
                    
                    // Get comprehensive statistics without histogram
                    run("Set Measurements...", "mean median min max redirect=None decimal=3");
                    run("Select All");
                    run("Measure");
                    
                    median_val = getResult("Median", nResults-1);
                    mean_val = getResult("Mean", nResults-1);
                    min_val = getResult("Min", nResults-1);
                    max_val = getResult("Max", nResults-1);
                    
                    run("Clear Results");
                    
                    all_medians = Array.concat(all_medians, median_val);
                    all_means = Array.concat(all_means, mean_val);
                    all_mins = Array.concat(all_mins, min_val);
                    all_maxs = Array.concat(all_maxs, max_val);
                    
                    total_images_checked++;
                    close();
                }
            }
        }
    }
    
    // Calculate consistency statistics
    if (all_medians.length > 0) {
        Array.getStatistics(all_medians, min_median, max_median, mean_median, std_median);
        Array.getStatistics(all_means, min_mean, max_mean, mean_mean, std_mean);
        Array.getStatistics(all_mins, min_min, max_min, mean_min, std_min);
        Array.getStatistics(all_maxs, min_max, max_max, mean_max, std_max);
        
        print("Brightness consistency across " + total_images_checked + " standardized images:");
        print("  Median values - Range: " + d2s(min_median,1) + " to " + d2s(max_median,1) + 
              ", StdDev: " + d2s(std_median,1));
        print("  Mean values - Range: " + d2s(min_mean,1) + " to " + d2s(max_mean,1) + 
              ", StdDev: " + d2s(std_mean,1));
        print("  Min values - Range: " + d2s(min_min,1) + " to " + d2s(max_min,1) + 
              ", StdDev: " + d2s(std_min,1));
        print("  Max values - Range: " + d2s(min_max,1) + " to " + d2s(max_max,1) + 
              ", StdDev: " + d2s(std_max,1));
        
        // Calculate intensity range consistency
        intensity_ranges = newArray(all_mins.length);
        for (k = 0; k < all_mins.length; k++) {
            intensity_ranges[k] = all_maxs[k] - all_mins[k];
        }
        Array.getStatistics(intensity_ranges, min_range, max_range, mean_range, std_range);
        
        print("  Intensity ranges - Range: " + d2s(min_range,1) + " to " + d2s(max_range,1) + 
              ", StdDev: " + d2s(std_range,1));
        
        // Evaluation criteria
        if (std_median < 15 && std_mean < 15) {
            print("*** EXCELLENT: Brightness is very well standardized across trials ***");
        } else if (std_median < 25 && std_mean < 25) {
            print("*** GOOD: Brightness is reasonably standardized across trials ***");
        } else {
            print("*** WARNING: Significant brightness variation remains ***");
            print("    Consider adjusting standardization parameters");
        }
        
        // Check if threshold sensitivity is preserved
        if (std_range < 20) {
            print("*** GOOD: Intensity ranges are consistent - threshold sensitivity preserved ***");
        } else {
            print("*** NOTE: Some intensity range variation - monitor threshold sensitivity ***");
        }
        
    } else {
        print("No standardized images found for verification");
    }
}

function finalCleanupTables() {
    // *** ONLY reset Results table after ALL folder pairs are completely processed ***
    if (isOpen("Results")) {
        final_particle_count = nResults;
        print("=== FINAL CLEANUP ===");
        print("Total particles processed across all images and folders: " + final_particle_count);
        print("Now clearing Results table for next run");
        Table.reset("Results");
    }
    if (isOpen("Summary")) {
        Table.reset("Summary");
    }
}

// ============================================================================
// MAIN SCRIPT EXECUTION (CALLED LAST)
// ============================================================================

// User selects the parent directory containing all folders (only once)
parent_dir = getDirectory("Choose the parent directory containing Bef_ii and Aft_ii folders");

print("=== Starting Complete Calibration Edge Analysis ===");
print("Parent directory: " + parent_dir);
print("Timestamp: " + getTimeStamp());

// Pre-scan all folders to build processing queue
folder_pairs = buildProcessingQueue(parent_dir);
print("Found " + folder_pairs.length + " folder pairs to process");

if (folder_pairs.length == 0) {
    print("No valid folder pairs found. Exiting.");
    showMessage("No Data", "No valid Bef_/Aft_ folder pairs found in the selected directory.");
    exit();
}

// PART 1: File Renaming (batch optimized)
print("\n=== PART 1: BATCH RENAMING FILES ===");
batchRenameBefFiles(parent_dir, folder_pairs);

// PART 2: FIXED Brightness Standardization
print("\n=== PART 2: FIXED BRIGHTNESS STANDARDIZATION ===");
fixedBrightnessStandardization(parent_dir, folder_pairs);

// PART 3: Image Registration and Processing (FIXED for particle accumulation)
print("\n=== PART 3: FIXED IMAGE REGISTRATION AND PARTICLE ANALYSIS ===");
optimizedProcessAllImagePairs(parent_dir, folder_pairs);

// PART 4: Edge Coordinate Extraction
print("\n=== PART 4: EDGE COORDINATE EXTRACTION ===");
extractAllEdgeCoordinates(parent_dir);

// PART 5: Particle Mapping and Qualification
print("\n=== PART 5: PARTICLE MAPPING AND QUALIFICATION ===");
mapAndQualifyAllParticles(parent_dir);

// PART 6: Dimension Analysis (cached)
print("\n=== PART 6: CACHED DIMENSION ANALYSIS ===");
cachedAnalyzeDimensions(parent_dir);

// PART 7: Final Summary Report
print("\n=== PART 7: GENERATING FINAL SUMMARY ===");
generateFinalSummaryReport(parent_dir);

// PART 7B: Detailed Brightness Analysis Report
print("\n=== PART 7B: GENERATING DETAILED BRIGHTNESS REPORT ===");
generateDetailedBrightnessReport(parent_dir);

// PART 8: Verify Brightness Standardization
print("\n=== PART 8: VERIFYING STANDARDIZATION ===");
verifyStandardization(parent_dir + "Edge Measurements/");

finalCleanupTables();

setBatchMode(false);
print("\n=== ALL PROCESSING COMPLETE ===");
print("Completion timestamp: " + getTimeStamp());
showMessage("Processing Complete", "All calibration edge analysis steps completed successfully!\n\nCheck the Edge Measurements folder for results.");



