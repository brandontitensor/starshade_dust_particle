// Simplified Edge Analysis Macro - Removes edge detection and particle qualification
// Keeps the calibration-style loop structure but focuses on difference image processing only

setBatchMode(true);
run("Close All");

// ============================================================================
// UTILITY FUNCTIONS (DEFINED FIRST)
// ============================================================================

function safeCloseAllImages() {
    window_count = nImages();
    
    if (window_count > 0) {
        window_titles = newArray(window_count);
        for (w = 1; w <= window_count; w++) {
            selectImage(w);
            window_titles[w-1] = getTitle();
        }
        
        for (w = 0; w < window_titles.length; w++) {
            if (isOpen(window_titles[w])) {
                selectWindow(window_titles[w]);
                close();
            }
        }
    }
    
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

// ============================================================================
// PART 1 FUNCTIONS: Optimized File Renaming
// ============================================================================

function optimizedProcessFolder(folder_path) {
    file_list = getFileList(folder_path);
    rename_operations = newArray(0);
    
    for (i = 0; i < file_list.length; i++) {
        old_name = file_list[i];
        if (!endsWith(old_name, "/")) {
            dot_index = lastIndexOf(old_name, ".");
            if (dot_index != -1 && !endsWith(old_name, "0" + substring(old_name, dot_index))) {
                new_name = substring(old_name, 0, dot_index) + "0" + substring(old_name, dot_index);
                rename_operations = Array.concat(rename_operations, old_name + "|" + new_name);
            }
        }
    }
    
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
    getDimensions(width, height, channels, slices, frames);
    
    top_region_height = floor(height * 0.30);
    bottom_region_start_y = floor(height * 0.70);
    bottom_region_height = height - bottom_region_start_y;
    
    run("Select None");
    
    makeRectangle(0, 0, width, top_region_height);
    run("Set Measurements...", "mean median redirect=None decimal=3");
    run("Measure");
    top_median = getResult("Median", nResults-1);
    top_mean = getResult("Mean", nResults-1);
    run("Clear Results");
    
    makeRectangle(0, bottom_region_start_y, width, bottom_region_height);
    run("Set Measurements...", "mean median redirect=None decimal=3");
    run("Measure");
    bottom_median = getResult("Median", nResults-1);
    bottom_mean = getResult("Mean", nResults-1);
    run("Clear Results");
    
    run("Select None");
    
    return newArray(top_median, top_mean, bottom_median, bottom_mean);
}

function applyFallbackStandardization(original_stats) {
    original_median = original_stats[2];
    target_median = 100;
    
    offset = target_median - original_median;
    
    if (offset != 0) {
        run("32-bit");
        run("Add...", "value=" + offset);
        run("8-bit");
        
        new_stats = getBasicImageStats();
        print("      Fallback applied - median shift: " + d2s(offset, 1));
        
        return new_stats;
    } else {
        print("      No transformation needed");
        return original_stats;
    }
}

function applyFixedStandardization(original_stats) {
    original_min = original_stats[0];
    original_max = original_stats[1];
    original_median = original_stats[2];
    original_mean = original_stats[3];
    
    original_regions = calculateSpatialRegionStatsFast();
    original_top_median = original_regions[0];
    original_bottom_median = original_regions[2];
    
    print("      Original top 30% median: " + d2s(original_top_median, 1) + ", bottom 30% median: " + d2s(original_bottom_median, 1));
    print("      Original top/bottom ratio: " + d2s(original_top_median/original_bottom_median, 2));
    
    target_top_median = 200;
    target_bottom_median = 10;
    
    print("      Target top 30% median: " + target_top_median + ", bottom 30% median: " + target_bottom_median);
    
    original_range = original_top_median - original_bottom_median;
    target_range = target_top_median - target_bottom_median;
    
    if (original_range > 0) {
        scale_factor = target_range / original_range;
        offset = target_bottom_median - (original_bottom_median * scale_factor);
        
        print("      Anchor Point Transform: scale = " + d2s(scale_factor, 4) + ", offset = " + d2s(offset, 2));
        
        run("32-bit");
        run("Multiply...", "value=" + scale_factor);
        run("Add...", "value=" + offset);
        run("8-bit");
        
        new_stats = getBasicImageStats();
        
        new_regions = calculateSpatialRegionStatsFast();
        new_top_median = new_regions[0];
        new_bottom_median = new_regions[2];
        
        print("      Achieved top 30% median: " + d2s(new_top_median, 1) + ", bottom 30% median: " + d2s(new_bottom_median, 1));
        print("      New top/bottom ratio: " + d2s(new_top_median/new_bottom_median, 2));
        print("      Target accuracy - top: " + d2s(abs(new_top_median - target_top_median), 1) + ", bottom: " + d2s(abs(new_bottom_median - target_bottom_median), 1));
        
        top_median_change = new_top_median - original_top_median;
        bottom_median_change = new_bottom_median - original_bottom_median;
        print("      Spatial changes - top median: " + d2s(top_median_change, 1) + ", bottom median: " + d2s(bottom_median_change, 1));
        
        original_ratio = original_top_median / original_bottom_median;
        new_ratio = new_top_median / new_bottom_median;
        target_ratio = target_top_median / target_bottom_median;
        print("      Ratio preservation - original: " + d2s(original_ratio, 2) + ", achieved: " + d2s(new_ratio, 2) + ", target: " + d2s(target_ratio, 2));
        
        return new_stats;
    } else {
        print("      No spatial gradient detected - using fallback standardization");
        return applyFallbackStandardization(original_stats);
    }
}

function fixedStandardizeFolder(folder_path, folder_name, out_dir) {
    file_list = getFileList(folder_path);
    
    image_files = newArray(0);
    for (i = 0; i < file_list.length; i++) {
        if (isImageFile(file_list[i])) {
            image_files = Array.concat(image_files, file_list[i]);
        }
    }
    
    if (image_files.length == 0) return newArray(0);
    
    corrected_image_path = out_dir + "Brightness_Corrected/" + folder_name + "/";
    File.makeDirectory(corrected_image_path);
    
    median_info = newArray(0);
    
    print("  Processing " + folder_name + " (" + image_files.length + " images)");
    
    for (j = 0; j < image_files.length; j++) {
        current_file = image_files[j];
        
        open(folder_path + current_file);
        
        original_stats = getBasicImageStats();
        original_spatial = calculateSpatialRegionStatsFast();
        
        new_stats = applyFixedStandardization(original_stats);
        new_spatial = calculateSpatialRegionStatsFast();
        
        brightness_data = folder_name + "|" + current_file + "|" + 
                         original_spatial[0] + "|" + original_spatial[2] + "|" + original_stats[2] + "|" +
                         new_spatial[0] + "|" + new_spatial[2] + "|" + new_stats[2];
        
        print("DEBUG: Storing brightness data: " + brightness_data);
        median_info = Array.concat(median_info, brightness_data);
        
        saveAs("jpg", corrected_image_path + current_file);
        close("*");
    }
    
    return median_info;
}

function fixedBrightnessStandardization(parent_dir, folder_pairs) {
    print("=== FIXED BRIGHTNESS STANDARDIZATION FOR TEMPORAL DRIFT ===");
    print("Linear scaling to preserve threshold sensitivity across trials");
    
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
// PART 3 FUNCTIONS: SIMPLIFIED IMAGE REGISTRATION AND PROCESSING
// ============================================================================

function processSimplifiedDifferenceWithDebugging(diff_title, fullFileName, processed_dir) {
    print("          Processing difference image: " + diff_title);
    
    selectWindow(diff_title);
    saveAs("jpg", processed_dir + "Difference/Difference" + fullFileName);
    
    getDimensions(width, height, channels, slices, frames);
    new_height = floor(height * 0.8);
    new_y = floor(height * 0.1);
    
    print("          Original dimensions: " + width + "x" + height);
    print("          Cropping to: " + width + "x" + new_height);
    
    makeRectangle(0, new_y, width, new_height);
    run("Crop");
    
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    saveAs("jpg", processed_dir + "Crop/Difference" + fullFileName);
    run("8-bit");
    saveAs("jpg", processed_dir + "Crop8bit/Difference" + fullFileName);
    
    getDimensions(final_width, final_height, channels, slices, frames);
    print("          Final 8-bit dimensions: " + final_width + "x" + final_height);
    
    THRESHOLD_VALUE = 60;
    print("          Applying threshold: " + THRESHOLD_VALUE);
    
    if (bitDepth() != 8) {
        print("          WARNING: Image is not 8-bit! Converting...");
        run("8-bit");
    }
    
    setThreshold(THRESHOLD_VALUE, 255);
    
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
    
    run("Convert to Mask");
    saveAs("jpg", processed_dir + "Crop8BitThreshold/Difference" + fullFileName);
    saveAs("jpg", processed_dir + "Crop8BitThresholdMask/Difference" + fullFileName);
    
    print("          Starting particle analysis...");
    
    particles_before_analysis = nResults;
    
    run("Set Measurements...", "area bounding shape redirect=None decimal=3");
    
    run("Analyze Particles...", " show=Masks display exclude include summarize");
    
    particles_after_analysis = nResults;
    particles_found_this_image = particles_after_analysis - particles_before_analysis;
    
    print("          Particle analysis results:");
    print("            Particles found: " + particles_found_this_image);
    print("            Total particles in table: " + particles_after_analysis);
    
    if (particles_found_this_image > 0) {
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
        } else {
            print("          ✓ All particles have valid measurements");
        }
    } else {
        print("          WARNING: No particles detected - check threshold or image quality");
    }
    
    saveAs("jpg", processed_dir + "Finished/" + fullFileName);
    
    print("          ✓ Difference processing completed");
    return true;
}

function processSimplifiedFusedImage(fused_title, fullFileName, processed_dir, file1, file2) {
    selectWindow(fused_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Registration/Registered" + fullFileName);
    
    run("Split Channels");
    
    c1_title = "C1-" + fused_title;
    c2_title = "C2-" + fused_title;
    
    if (!isOpen(c1_title) || !isOpen(c2_title)) {
        print("          ERROR: Failed to split channels");
        return false;
    }
    
    selectWindow(c1_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", processed_dir + "Split/C1Fused/C1-Fused " + file1 + " & " + file2);
    c1_saved_title = getTitle();
    
    selectWindow(c2_title);
    saveAs("jpg", processed_dir + "Split/C2Fused/C2-Fused " + file1 + " & " + file2);
    c2_saved_title = getTitle();
    
    // Calculate difference using original channels (no edge detection)
    imageCalculator("Difference create", c1_saved_title, c2_saved_title);
    
    diff_title = "Result of " + c1_saved_title;
    
    if (!isOpen(diff_title)) {
        print("          ERROR: Failed to create difference image");
        return false;
    }
    
    return processSimplifiedDifferenceWithDebugging(diff_title, fullFileName, processed_dir);
}

function optimizedProcessImagePairSingle(in_dir_1, in_dir_2, file1_name, file2_name, processed_dir) {
    file1 = File.getNameWithoutExtension(file1_name);
    file2 = File.getNameWithoutExtension(file2_name);
    fullFileName = file1 + "minus" + file2;
    
    print("        Processing: " + fullFileName);
    
    if (!File.exists(in_dir_1 + file1_name) || !File.exists(in_dir_2 + file2_name)) {
        print("        ERROR: Input files not found");
        print("          File 1: " + in_dir_1 + file1_name + " exists=" + File.exists(in_dir_1 + file1_name));
        print("          File 2: " + in_dir_2 + file2_name + " exists=" + File.exists(in_dir_2 + file2_name));
        return false;
    }
    
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
    
    if (!isOpen(title1) || !isOpen(title2)) {
        print("        ERROR: Lost one or both images during processing");
        close("*");
        return false;
    }
    
    print("        Starting image registration...");
    
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
    
    windows_after_registration = nImages();
    if (windows_after_registration <= windows_before_registration) {
        print("        ERROR: Registration failed - no new windows created");
        close("*");
        return false;
    }
    
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
    
    result = processSimplifiedFusedImage(fused_title, fullFileName, processed_dir, file1, file2);
    
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
    
    // Removed edge-related directories
    subdirs = newArray("8 bit clean", "8 bit dirty", "Registration", "Split", 
                      "Split/C1Fused", "Split/C2Fused", "Difference", "Crop", 
                      "Crop8bit", "Crop8BitThreshold", "Crop8BitThresholdMask", 
                      "Finished", "Errors");
                      
    for (i = 0; i < subdirs.length; i++) {
        File.makeDirectory(processed_dir + subdirs[i]);
    }
}

function verifyResultsTableIntegrity(context) {
    if (isOpen("Results")) {
        particle_count = nResults;
        print("    VERIFICATION [" + context + "]:");
        print("      Results table exists with " + particle_count + " particles");
        
        if (particle_count > 0) {
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
    
    if (isOpen("Results")) {
        total_particles = nResults;
        print("    Saving Results table with " + total_particles + " accumulated particles");
        Table.save(out_dir + "Particles " + base_name + ".csv", "Results");
        
        print("    ✓ Particle data preserved for continued accumulation");
    } else {
        print("    Warning: No Results table found to save");
    }
    
    if (isOpen("Summary")) {
        Table.save(out_dir + "Summary " + base_name + ".csv", "Summary");
        Table.reset("Summary");
    }
}

function addOptimizedSummaryData(comparison_folder, bef_folder_name, aft_folder_name) {
    if (!isOpen("Summary")) {
        print("    Summary table not found - skipping enhanced data addition");
        return;
    }
    
    num_summary_rows = Table.size("Summary");
    
    if (num_summary_rows == 0) {
        print("    Summary table is empty - cannot add additional data");
        return;
    }
    
    // Simplified column additions (removed edge-related columns)
    column_names = newArray("image_name", "finished_width", "finished_height",
                       "Bef_Pre_Upper_Median", "Bef_Pre_Lower_Median", "Bef_Pre_Entire_Median",
                       "Bef_Post_Upper_Median", "Bef_Post_Lower_Median", "Bef_Post_Entire_Median",
                       "Aft_Pre_Upper_Median", "Aft_Pre_Lower_Median", "Aft_Pre_Entire_Median", 
                       "Aft_Post_Upper_Median", "Aft_Post_Lower_Median", "Aft_Post_Entire_Median");
    
    for (col = 0; col < column_names.length; col++) {
        for (row = 0; row < num_summary_rows; row++) {
            Table.set(column_names[col], row, 0, "Summary");
        }
    }
    
    addSimplifiedDimensionData(comparison_folder, num_summary_rows);
    addOptimizedMedianData(File.getParent(comparison_folder) + "/", num_summary_rows);
}

function addSimplifiedDimensionData(comparison_folder, num_summary_rows) {
    processed_images_path = comparison_folder + "Processed Images/";
    finishedImagesPath = processed_images_path + "Finished/";
    
    if (!File.isDirectory(finishedImagesPath)) {
        return;
    }
    
    finishedImageList = getFileList(finishedImagesPath);
    
    for (row = 0; row < minOf(num_summary_rows, finishedImageList.length); row++) {
        if (isImageFile(finishedImageList[row])) {
            finishedImagePath = finishedImagesPath + finishedImageList[row];
            
            finishedDims = getImageDimensions(finishedImagePath);
            
            Table.set("image_name", row, finishedImageList[row], "Summary");
            Table.set("finished_width", row, finishedDims[0], "Summary");
            Table.set("finished_height", row, finishedDims[1], "Summary");
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
    
    for (row = 0; row < num_summary_rows; row++) {
        combined_image_name = Table.getString("image_name", row, "Summary");
        
        print("DEBUG: Processing row " + row + ", combined name: " + combined_image_name);
        
        image_names = extractImageNamesFromCombined(combined_image_name);
        
        if (image_names.length == 2) {
            bef_image = image_names[0];
            aft_image = image_names[1];
            
            print("DEBUG: Looking for Bef image: " + bef_image);
            print("DEBUG: Looking for Aft image: " + aft_image);
            
            bef_data = findImageBrightnessData(median_info, "Bef_", bef_image);
            aft_data = findImageBrightnessData(median_info, "Aft_", aft_image);
            
            print("DEBUG: Bef data found: " + (bef_data.length > 0));
            print("DEBUG: Aft data found: " + (aft_data.length > 0));
            
            if (bef_data.length >= 8) {
                Table.set("Bef_Pre_Upper_Median", row, parseFloat(bef_data[2]), "Summary");
                Table.set("Bef_Pre_Lower_Median", row, parseFloat(bef_data[3]), "Summary");
                Table.set("Bef_Pre_Entire_Median", row, parseFloat(bef_data[4]), "Summary");
                Table.set("Bef_Post_Upper_Median", row, parseFloat(bef_data[5]), "Summary");
                Table.set("Bef_Post_Lower_Median", row, parseFloat(bef_data[6]), "Summary");
                Table.set("Bef_Post_Entire_Median", row, parseFloat(bef_data[7]), "Summary");
                
                print("DEBUG: Set Bef data - Pre Upper: " + bef_data[2] + ", Pre Lower: " + bef_data[3]);
            }
            
            if (aft_data.length >= 8) {
                Table.set("Aft_Pre_Upper_Median", row, parseFloat(aft_data[2]), "Summary");
                Table.set("Aft_Pre_Lower_Median", row, parseFloat(aft_data[3]), "Summary");
                Table.set("Aft_Pre_Entire_Median", row, parseFloat(aft_data[4]), "Summary");
                Table.set("Aft_Post_Upper_Median", row, parseFloat(aft_data[5]), "Summary");
                Table.set("Aft_Post_Lower_Median", row, parseFloat(aft_data[6]), "Summary");
                Table.set("Aft_Post_Entire_Median", row, parseFloat(aft_data[7]), "Summary");
                
                print("DEBUG: Set Aft data - Pre Upper: " + aft_data[2] + ", Pre Lower: " + aft_data[3]);
            }
        } else {
            print("DEBUG: Could not extract image names from: " + combined_image_name);
        }
    }
}

function extractImageNamesFromCombined(combined_name) {
    if (indexOf(combined_name, "minus") > 0) {
        minus_pos = indexOf(combined_name, "minus");
        
        first_part = substring(combined_name, 0, minus_pos);
        first_image = first_part + ".jpg";
        
        second_part = substring(combined_name, minus_pos + 5);
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
    
    folder_name_1 = File.getName(in_dir_1);
    folder_name_2 = File.getName(in_dir_2);
    
    corrected_dir_1 = brightness_corrected_dir + folder_name_1 + "/";
    corrected_dir_2 = brightness_corrected_dir + folder_name_2 + "/";
    
    print("    Using brightness corrected images:");
    print("      Folder 1: " + corrected_dir_1);
    print("      Folder 2: " + corrected_dir_2);
    
    if (!File.isDirectory(corrected_dir_1) || !File.isDirectory(corrected_dir_2)) {
        print("    ERROR: Brightness corrected folders not found");
        print("      Missing: " + corrected_dir_1 + " exists=" + File.isDirectory(corrected_dir_1));
        print("      Missing: " + corrected_dir_2 + " exists=" + File.isDirectory(corrected_dir_2));
        return 0;
    }
    
    ls_1 = getFileList(corrected_dir_1);
    ls_2 = getFileList(corrected_dir_2);
    Array.sort(ls_1);
    Array.sort(ls_2);
    
    image_files_1 = filterImageFiles(ls_1);
    image_files_2 = filterImageFiles(ls_2);
    
    print("    Found " + image_files_1.length + " images in corrected folder 1");
    print("    Found " + image_files_2.length + " images in corrected folder 2");
    
    if (image_files_1.length == 0 || image_files_2.length == 0) {
        print("    ERROR: No matching image files found in brightness corrected folders");
        return 0;
    }
    
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    folderName = folder_name_1 + " minus " + folder_name_2 + "_" + 
                 year + "_" + IJ.pad(month+1, 2) + "_" + IJ.pad(dayOfMonth, 2) + "_" + 
                 IJ.pad(hour, 2) + "_" + IJ.pad(minute, 2) + "_" + IJ.pad(second, 2);
    out_dir = parent_dir + "Edge Measurements/" + folderName + "/";
    processed_dir = out_dir + "Processed Images/";
    
    print("    Output directory: " + out_dir);
    
    createAllSubdirectories(out_dir, processed_dir);
    
    folder_start_particle_count = nResults;
    print("    === STARTING FOLDER PAIR PROCESSING ===");
    print("    Initial particle count in Results table: " + folder_start_particle_count);
    print("    Processing " + folder_name_1 + " vs " + folder_name_2);
    
    num_pairs = minOf(image_files_1.length, image_files_2.length);
    successful_pairs = 0;
    total_particles_from_folder = 0;
    
    print("    Will process " + num_pairs + " image pairs");
    
    for (i = 0; i < num_pairs; i++) {
        image_start_particles = nResults;
        
        print("      --- Processing image pair " + (i+1) + "/" + num_pairs + " ---");
        print("      Files: " + image_files_1[i] + " vs " + image_files_2[i]);
        print("      Particles before this image: " + image_start_particles);
        
        if (optimizedProcessImagePairSingle(corrected_dir_1, corrected_dir_2, image_files_1[i], image_files_2[i], processed_dir)) {
            successful_pairs++;
            
            image_end_particles = nResults;
            particles_from_this_image = image_end_particles - image_start_particles;
            total_particles_from_folder += particles_from_this_image;
            
            print("      SUCCESS: Added " + particles_from_this_image + " particles");
            print("      Running total: " + image_end_particles + " particles");
            
            if (particles_from_this_image == 0) {
                print("      WARNING: No particles found in this image pair - check thresholding");
            }
            
        } else {
            print("      FAILED: Could not process this image pair");
            logError("Failed to process pair: " + image_files_1[i] + " & " + image_files_2[i], processed_dir);
        }
        
        if (i % 2 == 0) {
            results_before_cleanup = nResults;
            safeCloseAllImages();
            run("Collect Garbage");
            results_after_cleanup = nResults;
            
            if (results_before_cleanup != results_after_cleanup) {
                print("        *** ERROR: Results table was modified during cleanup! ***");
                print("        Before: " + results_before_cleanup + ", After: " + results_after_cleanup);
            }
        }
        
        if (num_pairs > 1) {
            showProgress(i+1, num_pairs);
        }
    }
    
    folder_end_particle_count = nResults;
    particles_added_by_folder = folder_end_particle_count - folder_start_particle_count;
    
    print("    === FOLDER PAIR PROCESSING COMPLETE ===");
    print("    Successfully processed: " + successful_pairs + "/" + num_pairs + " image pairs");
    print("    Particles added by this folder pair: " + particles_added_by_folder);
    print("    Grand total particles accumulated: " + folder_end_particle_count);
    
    if (particles_added_by_folder != total_particles_from_folder) {
        print("    WARNING: Particle count mismatch!");
        print("      Expected: " + total_particles_from_folder);
        print("      Actual: " + particles_added_by_folder);
    } else {
        print("    ✓ Particle counting verified correct");
    }
    
    if (successful_pairs > 0) {
        print("    Generating summary data and saving results...");
        
        addOptimizedSummaryData(out_dir, in_dir_1, in_dir_2);
        
        saveResultsTables(out_dir, in_dir_1, in_dir_2);
        
        print("    ✓ Results saved to: " + out_dir);
    } else {
        print("    No successful pairs - skipping file generation");
    }
    
    verifyResultsTableIntegrity("End of folder pair processing");
    
    return successful_pairs;
}

function optimizedProcessAllImagePairs(parent_dir, folder_pairs) {
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    if (!File.isDirectory(edge_measurements_dir)) {
        File.makeDirectory(edge_measurements_dir);
    }
    
    total_pairs_processed = 0;
    successful_pairs = 0;
    
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
// PART 4 FUNCTIONS: Cached Dimension Analysis (Simplified)
// ============================================================================

function updateSummaryFileOptimized(summaryFilePath, updatedSummaryPath) {
    summaryFile = File.openAsString(summaryFilePath);
    summaryLines = split(summaryFile, "\n");
    
    if (summaryLines.length <= 1) return;
    
    imageNameColumn = Table.getColumn("image_name");
    finishedWidthColumn = Table.getColumn("finished_width");
    finishedHeightColumn = Table.getColumn("finished_height");
    
    headerFields = split(summaryLines[0], ",");
    newHeaders = newArray("image_name", "finished_width", "finished_height");
    headerFields = Array.concat(headerFields, newHeaders);
    summaryLines[0] = String.join(headerFields, ",");
    
    for (k = 1; k < summaryLines.length; k++) {
        summaryFields = split(summaryLines[k], ",");
        
        if (k-1 < imageNameColumn.length) {
            newData = newArray(imageNameColumn[k-1], finishedWidthColumn[k-1], finishedHeightColumn[k-1]);
        } else {
            newData = newArray("", "", "");
        }
        
        summaryFields = Array.concat(summaryFields, newData);
        summaryLines[k] = String.join(summaryFields, ",");
    }
    
    updatedSummary = String.join(summaryLines, "\n");
    File.saveString(updatedSummary, updatedSummaryPath);
}

function processCachedDimensionAnalysis(subfolder, summaryFilePath, updatedSummaryPath) {
    finishedImagesPath = subfolder + "Processed Images" + File.separator + "Finished" + File.separator;
    
    if (!File.exists(finishedImagesPath)) {
        return false;
    }
    
    finishedImageList = getFileList(finishedImagesPath);
    if (finishedImageList.length == 0) return false;
    
    Table.create("Dimension Data");
    rowIndex = 0;
    
    for (j = 0; j < finishedImageList.length; j++) {
        if (isImageFile(finishedImageList[j])) {
            finishedImagePath = finishedImagesPath + finishedImageList[j];
            
            finishedDimensions = getImageDimensions(finishedImagePath);
            
            Table.set("image_name", rowIndex, finishedImageList[j]);
            Table.set("finished_width", rowIndex, finishedDimensions[0]);
            Table.set("finished_height", rowIndex, finishedDimensions[1]);
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
// PART 5 FUNCTIONS: Final Summary Report (Simplified)
// ============================================================================

function generateFinalSummaryReport(parent_dir) {
    edge_measurements_dir = parent_dir + "Edge Measurements/";
    
    if (!File.isDirectory(edge_measurements_dir)) {
        print("No Edge Measurements directory found for final report");
        return;
    }
    
    report_file = edge_measurements_dir + "Final_Processing_Summary_" + 
                  replace(getTimeStamp(), ":", "-") + ".txt";
    
    report_content = "=== SIMPLIFIED EDGE ANALYSIS FINAL SUMMARY ===\n";
    report_content += "Generated: " + getTimeStamp() + "\n";
    report_content += "Parent Directory: " + parent_dir + "\n\n";
    
    folder_list = getFileList(edge_measurements_dir);
    total_folders = 0;
    successful_folders = 0;
    total_particles = 0;
    
    for (i = 0; i < folder_list.length; i++) {
        if (endsWith(folder_list[i], "/") && !startsWith(folder_list[i], "Brightness_Corrected")) {
            total_folders++;
            comparison_folder = edge_measurements_dir + folder_list[i];
            
            // Look for any particles file
            particles_files = getFileList(comparison_folder);
            for (j = 0; j < particles_files.length; j++) {
                if (startsWith(particles_files[j], "Particles") && endsWith(particles_files[j], ".csv")) {
                    successful_folders++;
                    
                    particles_file = comparison_folder + particles_files[j];
                    particle_lines = split(File.openAsString(particles_file), "\n");
                    if (particle_lines.length > 1) {
                        particle_count = particle_lines.length - 1;
                        total_particles += particle_count;
                        
                        report_content += "Folder " + folder_list[i] + ": " + particle_count + " particles\n";
                    }
                    break;
                }
            }
        }
    }
    
    report_content += "\n=== OVERALL STATISTICS ===\n";
    report_content += "Total folders processed: " + successful_folders + "/" + total_folders + "\n";
    report_content += "Total particles analyzed: " + total_particles + "\n";
    
    report_content += "\n=== BRIGHTNESS STANDARDIZATION ===\n";
    report_content += "- Applied fixed linear brightness standardization\n";
    report_content += "- Preserves intensity relationships for threshold sensitivity\n";
    report_content += "- Handles temporal brightness drift across trials\n";
    
    report_content += "\n=== FILES GENERATED ===\n";
    report_content += "- Fixed brightness standardization data\n";
    report_content += "- Registered image pairs\n";
    report_content += "- Difference detection images\n";
    report_content += "- Particle analysis CSV files\n";
    report_content += "- Updated summary files with dimensions\n";
    report_content += "- Brightness standardization verification report\n";
    
    File.saveString(report_content, report_file);
    print("Final summary report generated: " + report_file);
    print("Successfully processed " + successful_folders + "/" + total_folders + " sample folders");
    print("Total particles: " + total_particles);
}

function verifyStandardization(out_dir) {
    print("=== VERIFYING BRIGHTNESS STANDARDIZATION ===");
    
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
        
        intensity_ranges = newArray(all_mins.length);
        for (k = 0; k < all_mins.length; k++) {
            intensity_ranges[k] = all_maxs[k] - all_mins[k];
        }
        Array.getStatistics(intensity_ranges, min_range, max_range, mean_range, std_range);
        
        print("  Intensity ranges - Range: " + d2s(min_range,1) + " to " + d2s(max_range,1) + 
              ", StdDev: " + d2s(std_range,1));
        
        if (std_median < 15 && std_mean < 15) {
            print("*** EXCELLENT: Brightness is very well standardized across trials ***");
        } else if (std_median < 25 && std_mean < 25) {
            print("*** GOOD: Brightness is reasonably standardized across trials ***");
        } else {
            print("*** WARNING: Significant brightness variation remains ***");
            print("    Consider adjusting standardization parameters");
        }
        
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
// MAIN SCRIPT EXECUTION
// ============================================================================

// User selects the parent directory containing all folders (only once)
parent_dir = getDirectory("Choose the parent directory containing Bef_ii and Aft_ii folders");

print("=== Starting Simplified Edge Analysis ===");
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

// PART 3: Simplified Image Registration and Processing (No edge detection or qualification)
print("\n=== PART 3: SIMPLIFIED IMAGE REGISTRATION AND PARTICLE ANALYSIS ===");
optimizedProcessAllImagePairs(parent_dir, folder_pairs);

// PART 4: Simplified Dimension Analysis (cached)
print("\n=== PART 4: CACHED DIMENSION ANALYSIS ===");
cachedAnalyzeDimensions(parent_dir);

// PART 5: Final Summary Report
print("\n=== PART 5: GENERATING FINAL SUMMARY ===");
generateFinalSummaryReport(parent_dir);

// PART 6: Verify Brightness Standardization
print("\n=== PART 6: VERIFYING STANDARDIZATION ===");
verifyStandardization(parent_dir + "Edge Measurements/");

finalCleanupTables();

setBatchMode(false);
print("\n=== ALL PROCESSING COMPLETE ===");
print("Completion timestamp: " + getTimeStamp());
showMessage("Processing Complete", "All simplified edge analysis steps completed successfully!\n\nCheck the Edge Measurements folder for results.\n\nNote: Edge detection and particle qualification have been removed from this version.");