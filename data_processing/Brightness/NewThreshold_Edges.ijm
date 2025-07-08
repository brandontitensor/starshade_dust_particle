// Complete Edge Processing Threshold Analysis with Anchor Point Brightness Standardization
// FIXED VERSION - Addresses file path length issues
// Uses shortened directory names and optimized file naming

setBatchMode(true);
run("Close All");

// User selects the parent directory containing Bef_xx and Aft_xx folders
parent_dir = getDirectory("Choose the parent directory containing Bef_xx and Aft_xx folders");
print("=== UPDATED EDGE PROCESSING THRESHOLD ANALYSIS ===");
print("Using Anchor Point Brightness Standardization");
print("Parent directory: " + parent_dir);

// Test range of thresholds around the new standardized threshold (40)
test_thresholds = newArray(30, 40, 45, 50, 55, 58, 60, 62, 70, 80);

// Find all Bef/Aft folder pairs
folder_pairs = buildProcessingQueue(parent_dir);
if (folder_pairs.length == 0) {
    print("No matching Bef_xx and Aft_xx folder pairs found!");
    exit();
}

print("Found " + folder_pairs.length + " folder pairs to process");
print("Testing " + test_thresholds.length + " threshold values: " + arrayToString(test_thresholds));

// Create main output directory with shorter name
analysis_dir = parent_dir + "ThreshAnalysis" + File.separator;
File.makeDirectory(analysis_dir);

// Create brightness standardization output directory with shorter name
brightness_dir = analysis_dir + "Brightness" + File.separator;
File.makeDirectory(brightness_dir);

// Arrays to store results across all thresholds
var all_results = newArray(0);
var summary_data = newArray(0);
var brightness_data = newArray(0);

// STEP 1: Apply anchor point brightness standardization to all images
print("\n=== STEP 1: ANCHOR POINT BRIGHTNESS STANDARDIZATION ===");
applyAnchorPointStandardization(parent_dir, folder_pairs, brightness_dir);

// STEP 2: Process each threshold using standardized images
for (t = 0; t < test_thresholds.length; t++) {
    current_threshold = test_thresholds[t];
    print("\n=== STEP 2: PROCESSING THRESHOLD: " + current_threshold + " (" + (t+1) + "/" + test_thresholds.length + ") ===");
    
    // Create output directory for this threshold with shorter name
    threshold_dir = analysis_dir + "T" + current_threshold + File.separator;
    File.makeDirectory(threshold_dir);
    
    // Clear global results for this threshold
    if (isOpen("Results")) {
        Table.reset("Results");
    }
    if (isOpen("Summary")) {
        Table.reset("Summary");
    }
    
    // Process each folder pair with current threshold using standardized images
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        print("Processing pair " + (i+1) + "/" + folder_pairs.length + ": " + bef_folder + " vs " + aft_folder);
        
        // Use brightness standardized images
        bef_standardized = brightness_dir + bef_folder + File.separator;
        aft_standardized = brightness_dir + aft_folder + File.separator;
        
        print("Using standardized images from:");
        print("  Bef: " + bef_standardized);
        print("  Aft: " + aft_standardized);
        
        // Run complete edge processing with current threshold
        processImagePairWithThreshold(bef_standardized, aft_standardized, 
                                    threshold_dir, current_threshold, bef_folder, aft_folder);
        
        // Memory management
        if (i % 3 == 0) {
            run("Collect Garbage");
        }
    }
    
    // Save results for this threshold
    saveThresholdResults(threshold_dir, current_threshold, folder_pairs.length);
    
    // Calculate summary statistics for this threshold
    calculateThresholdSummary(current_threshold);
}

// Create final analysis files
createFinalAnalysis(analysis_dir);

print("\n=== THRESHOLD ANALYSIS COMPLETE ===");
print("Results saved to: " + analysis_dir);
print("Brightness standardization data saved to: " + brightness_dir);
print("Review both quantitative data and visual results to select optimal threshold.");

setBatchMode(false);

// ============================================================================
// ANCHOR POINT BRIGHTNESS STANDARDIZATION FUNCTIONS
// ============================================================================

function applyAnchorPointStandardization(parent_dir, folder_pairs, brightness_dir) {
    // Set measurements once globally
    run("Set Measurements...", "area center perimeter bounding fit shape feret's skewness area_fraction median redirect=None decimal=3");
    
    // Ensure directories end with separator
    if (!endsWith(parent_dir, File.separator)) {
        parent_dir = parent_dir + File.separator;
    }
    if (!endsWith(brightness_dir, File.separator)) {
        brightness_dir = brightness_dir + File.separator;
    }
    
    // Process all folder pairs
    for (i = 0; i < folder_pairs.length; i++) {
        pair_info = split(folder_pairs[i], "|");
        bef_folder = pair_info[0];
        aft_folder = pair_info[1];
        
        print("Standardizing brightness for: " + bef_folder + " and " + aft_folder);
        
        // Remove trailing slash from folder names if present
        bef_folder_clean = replace(bef_folder, File.separator, "");
        aft_folder_clean = replace(aft_folder, File.separator, "");
        
        // Process both folders
        bef_input_path = parent_dir + bef_folder_clean + File.separator;
        bef_output_path = brightness_dir + bef_folder_clean + File.separator;
        aft_input_path = parent_dir + aft_folder_clean + File.separator;
        aft_output_path = brightness_dir + aft_folder_clean + File.separator;
        
        print("Processing paths:");
        print("  Bef input: " + bef_input_path);
        print("  Bef output: " + bef_output_path);
        print("  Aft input: " + aft_input_path);
        print("  Aft output: " + aft_output_path);
        
        bef_brightness_data = standardizeFolderBrightness(bef_input_path, bef_output_path, bef_folder_clean);
        aft_brightness_data = standardizeFolderBrightness(aft_input_path, aft_output_path, aft_folder_clean);
        
        // Store brightness data for analysis
        brightness_data = Array.concat(brightness_data, bef_brightness_data);
        brightness_data = Array.concat(brightness_data, aft_brightness_data);
        
        // Periodic memory cleanup
        if (i % 3 == 0) {
            run("Collect Garbage");
        }
    }
    
    // Save brightness standardization data
    saveBrightnessData(brightness_dir);
    
    print("Anchor point brightness standardization complete!");
}

function standardizeFolderBrightness(input_folder, output_folder, folder_name) {
    // Ensure paths end with separator
    if (!endsWith(input_folder, File.separator)) {
        input_folder = input_folder + File.separator;
    }
    if (!endsWith(output_folder, File.separator)) {
        output_folder = output_folder + File.separator;
    }
    
    // Create output directory
    File.makeDirectory(output_folder);
    
    // Check if input folder exists
    if (!File.exists(input_folder)) {
        print("Error: Input folder does not exist: " + input_folder);
        return newArray(0);
    }
    
    file_list = getFileList(input_folder);
    Array.sort(file_list);
    
    // Filter to image files only
    image_files = newArray(0);
    for (i = 0; i < file_list.length; i++) {
        if (isImageFile(file_list[i])) {
            image_files = Array.concat(image_files, file_list[i]);
        }
    }
    
    if (image_files.length == 0) {
        print("No image files found in " + folder_name + " (path: " + input_folder + ")");
        return newArray(0);
    }
    
    print("Processing " + image_files.length + " images in " + folder_name);
    brightness_info = newArray(0);
    
    for (j = 0; j < image_files.length; j++) {
        current_file = image_files[j];
        showProgress(j+1, image_files.length);
        
        full_input_path = input_folder + current_file;
        print("  Opening: " + full_input_path);
        
        // Check if file exists before opening
        if (!File.exists(full_input_path)) {
            print("    Error: File does not exist: " + full_input_path);
            continue;
        }
        
        // Open and prepare image
        open(full_input_path);
        if (nImages() == 0) {
            print("    Error: Failed to open image: " + full_input_path);
            continue;
        }
        
        image_title = getTitle();
        
        // Convert to 32-bit for processing
        run("32-bit");
        
        // Get dimensions
        getDimensions(width, height, channels, slices, frames);
        
        // Calculate region parameters
        upper_30_height = floor(height * 0.3);
        lower_30_height = floor(height * 0.3);
        lower_y = height - lower_30_height;
        
        // Measure original regions
        original_stats = measureAnchorRegions(width, height, upper_30_height, lower_y, lower_30_height);
        
        // Apply anchor point standardization
        applyFixedStandardization(original_stats);
        
        // Measure post-standardization
        post_stats = measureAnchorRegions(width, height, upper_30_height, lower_y, lower_30_height);
        
        // Store brightness information
        brightness_info = Array.concat(brightness_info, 
            folder_name + "|" + current_file + "|" + 
            original_stats[0] + "|" + original_stats[1] + "|" + original_stats[2] + "|" +
            post_stats[0] + "|" + post_stats[1] + "|" + post_stats[2]);
        
        // Convert back to 8-bit and save
        run("8-bit");
        full_output_path = output_folder + current_file;
        saveAs("jpg", full_output_path);
        close("*");
        
        print("    Saved: " + full_output_path);
        
        // Clear results periodically
        if (j % 10 == 0) {
            run("Clear Results");
        }
    }
    
    // Final cleanup
    run("Clear Results");
    return brightness_info;
}

function measureAnchorRegions(width, height, upper_30_height, lower_y, lower_30_height) {
    stats = newArray(3);
    
    // Measure upper 30% region (light anchor)
    makeRectangle(0, 0, width, upper_30_height);
    run("Measure");
    stats[0] = getResult("Median", nResults-1);
    
    // Measure lower 30% region (dark anchor)
    makeRectangle(0, lower_y, width, lower_30_height);
    run("Measure");
    stats[1] = getResult("Median", nResults-1);
    
    // Measure entire image
    run("Select All");
    run("Measure");
    stats[2] = getResult("Median", nResults-1);
    
    return stats;
}

function applyFixedStandardization(original_stats) {
    // Anchor point targets (from calibration script)
    target_top_median = 200;     // Target for top 30% region median
    target_bottom_median = 10;    // Target for bottom 30% region median
    
    original_top_median = original_stats[0];
    original_bottom_median = original_stats[1];
    
    print("  Applying anchor point standardization:");
    print("    Original top median: " + original_top_median + " -> target: " + target_top_median);
    print("    Original bottom median: " + original_bottom_median + " -> target: " + target_bottom_median);
    
    // Avoid division by zero
    original_range = original_top_median - original_bottom_median;
    if (original_range <= 0) {
        print("    Warning: Invalid brightness range, skipping transformation");
        return;
    }
    
    target_range = target_top_median - target_bottom_median;
    
    // Calculate linear transformation parameters: y = mx + b
    scale_factor = target_range / original_range;
    offset = target_bottom_median - (original_bottom_median * scale_factor);
    
    print("    Scale factor: " + scale_factor);
    print("    Offset: " + offset);
    
    // Apply transformation
    run("Multiply...", "value=" + scale_factor);
    run("Add...", "value=" + offset);
    
    print("    Anchor point standardization complete");
}

function saveBrightnessData(brightness_dir) {
    brightness_file_path = brightness_dir + "brightness_data.csv";
    
    // Create CSV header
    header = "Folder,Filename,Original_Top_Median,Original_Bottom_Median,Original_Entire_Median,Post_Top_Median,Post_Bottom_Median,Post_Entire_Median\n";
    File.saveString(header, brightness_file_path);
    
    // Save all brightness data
    for (i = 0; i < brightness_data.length; i++) {
        if (brightness_data[i] != "") {
            // Convert pipe-separated to comma-separated
            csv_line = replace(brightness_data[i], "|", ",") + "\n";
            File.append(csv_line, brightness_file_path);
        }
    }
    
    print("Brightness standardization data saved to: " + brightness_file_path);
}

// ============================================================================
// MAIN PROCESSING FUNCTIONS (Updated for shorter paths)
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

function processImagePairWithThreshold(in_dir_1, in_dir_2, threshold_dir, threshold_value, original_bef_name, original_aft_name) {
    // Ensure directories end with separator
    if (!endsWith(in_dir_1, File.separator)) {
        in_dir_1 = in_dir_1 + File.separator;
    }
    if (!endsWith(in_dir_2, File.separator)) {
        in_dir_2 = in_dir_2 + File.separator;
    }
    if (!endsWith(threshold_dir, File.separator)) {
        threshold_dir = threshold_dir + File.separator;
    }
    
    // Check if input directories exist
    if (!File.exists(in_dir_1)) {
        print("Error: Input directory 1 does not exist: " + in_dir_1);
        return;
    }
    if (!File.exists(in_dir_2)) {
        print("Error: Input directory 2 does not exist: " + in_dir_2);
        return;
    }
    
    // Get and sort file lists from standardized images
    ls_1 = getFileList(in_dir_1);
    ls_2 = getFileList(in_dir_2);
    Array.sort(ls_1);
    Array.sort(ls_2);
    
    // Filter to image files
    image_files_1 = filterImageFiles(ls_1);
    image_files_2 = filterImageFiles(ls_2);
    
    print("Found " + image_files_1.length + " images in " + original_bef_name);
    print("Found " + image_files_2.length + " images in " + original_aft_name);
    
    // Setup output directories for this threshold - SHORTENED NAMES
    folderName = "B" + substring(original_bef_name, 4, 6) + "_A" + substring(original_aft_name, 4, 6);
    out_dir = threshold_dir + folderName + File.separator;
    processed_dir = out_dir + "Proc" + File.separator;
    
    // Create all subdirectories
    createAllSubdirectories(out_dir, processed_dir);
    
    // Process image pairs
    num_pairs = minOf(image_files_1.length, image_files_2.length);
    
    for (i = 0; i < num_pairs; i++) {
        showProgress(i+1, num_pairs);
        
        processImagePairSingleWithThreshold(in_dir_1, in_dir_2, image_files_1[i], image_files_2[i], 
                                           processed_dir, threshold_value);
        
        // Cleanup memory
        if (i % 5 == 0) {
            run("Close All");
            run("Collect Garbage");
        }
    }
    
    // Save results for this pair
    saveResultsTables(out_dir, original_bef_name, original_aft_name, threshold_value);
}

function processImagePairSingleWithThreshold(in_dir_1, in_dir_2, file1_name, file2_name, processed_dir, threshold_value) {
    file1 = File.getNameWithoutExtension(file1_name);
    file2 = File.getNameWithoutExtension(file2_name);
    
    // Create very short filenames to avoid path length issues
    file1_short = substring(file1, 0, Math.min(file1.length(), 8));
    file2_short = substring(file2, 0, Math.min(file2.length(), 8));
    fullFileName = file1_short + file2_short;
    
    print("  Processing: " + file1_name + " & " + file2_name + " with threshold " + threshold_value);
    
    // Construct full file paths
    full_path_1 = in_dir_1 + file1_name;
    full_path_2 = in_dir_2 + file2_name;
    
    // Check if input files exist
    if (!File.exists(full_path_1)) {
        print("    Error: First file not found: " + full_path_1);
        return false;
    }
    if (!File.exists(full_path_2)) {
        print("    Error: Second file not found: " + full_path_2);
        return false;
    }
    
    // Load and prepare first image (already brightness standardized)
    print("    Opening first image: " + full_path_1);
    open(full_path_1);
    if (nImages() == 0) {
        print("    Failed to open first image");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Use very short filename for saving
    clean_filename = "c" + file1_short + ".jpg";
    clean_save_path = processed_dir + "Clean" + File.separator + clean_filename;
    saveAs("jpg", clean_save_path);
    title1 = getTitle();
    
    // Load and prepare second image (already brightness standardized)
    print("    Opening second image: " + full_path_2);
    open(full_path_2);
    if (nImages() != 2) {
        print("    Failed to open second image (total images: " + nImages() + ")");
        close("*");
        return false;
    }
    
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Use very short filename for saving
    dirty_filename = "d" + file2_short + ".jpg";
    dirty_save_path = processed_dir + "Dirty" + File.separator + dirty_filename;
    saveAs("jpg", dirty_save_path);
    title2 = getTitle();
    
    // Perform registration
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
    fused_title = "Fused " + file1_short + " & " + file2_short;
    if (!isOpen(fused_title)) {
        print("    Registration failed");
        close("*");
        return false;
    }
    
    // Process fused image with specific threshold
    processFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1_short, file2_short, threshold_value);
    
    return true;
}

function processFusedImageWithThreshold(fused_title, fullFileName, processed_dir, file1, file2, threshold_value) {
    selectWindow(fused_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Use very short filename for registration
    reg_filename = "r" + fullFileName + ".jpg";
    reg_save_path = processed_dir + "Reg" + File.separator + reg_filename;
    saveAs("jpg", reg_save_path);
    
    // Split channels
    run("Split Channels");
    
    c1_title = "C1-" + fused_title;
    c2_title = "C2-" + fused_title;
    
    if (!isOpen(c1_title) || !isOpen(c2_title)) {
        return false;
    }
    
    // Save split channels with shorter names
    selectWindow(c1_title);
    run("Set Scale...", "distance=240 known=50 unit=micron");
    c1_filename = "c1" + fullFileName + ".jpg";
    c1_save_path = processed_dir + "Split" + File.separator + c1_filename;
    saveAs("jpg", c1_save_path);
    
    selectWindow(c2_title);
    c2_filename = "c2" + fullFileName + ".jpg";
    c2_save_path = processed_dir + "Split" + File.separator + c2_filename;
    saveAs("jpg", c2_save_path);
    
    // Calculate difference
    imageCalculator("Difference create", c1_title, c2_title);
    diff_title = "Result of " + c1_title;
    
    if (!isOpen(diff_title)) {
        return false;
    }
    
    // Process difference image with specific threshold
    processOptimizedDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value);
    
    return true;
}

function processOptimizedDifferenceWithThreshold(diff_title, fullFileName, processed_dir, threshold_value) {
    selectWindow(diff_title);
    
    // Use very short filename for difference
    diff_filename = "df" + fullFileName + ".jpg";
    diff_save_path = processed_dir + "Diff" + File.separator + diff_filename;
    saveAs("jpg", diff_save_path);
    
    // Get dimensions and calculate crop
    getDimensions(width, height, channels, slices, frames);
    new_width = floor(width * 0.8);
    new_x = floor(width * 0.1);
    new_height = floor(height * 0.8);
    new_y = floor(height * 0.1);
    
    // Apply crop
    run("Specify...", "width=" + new_width + " height=" + new_height + " x=" + new_x + " y=" + new_y);
    run("Crop");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    
    // Save cropped version with very short filename
    crop_filename = "cr" + fullFileName + ".jpg";
    crop_save_path = processed_dir + "Crop" + File.separator + crop_filename;
    saveAs("jpg", crop_save_path);
    
    run("8-bit");
    crop8_filename = "c8" + fullFileName + ".jpg";
    crop8_save_path = processed_dir + "Crop8" + File.separator + crop8_filename;
    saveAs("jpg", crop8_save_path);
    
    // Apply the specific threshold being tested
    setThreshold(threshold_value, 255);
    thresh_filename = "th" + fullFileName + "t" + threshold_value + ".jpg";
    thresh_save_path = processed_dir + "Thresh" + File.separator + thresh_filename;
    saveAs("jpg", thresh_save_path);
    
    // Convert to mask
    run("Convert to Mask");
    mask_filename = "m" + fullFileName + "t" + threshold_value + ".jpg";
    mask_save_path = processed_dir + "Mask" + File.separator + mask_filename;
    saveAs("jpg", mask_save_path);
    
    // Set measurements and analyze particles
    run("Set Measurements...", "area bounding redirect=None decimal=3");
    run("Analyze Particles...", "show=Masks display exclude include summarize");
    
    // Save final results with threshold info
    final_filename = "f" + fullFileName + "t" + threshold_value + ".jpg";
    final_save_path = processed_dir + "Final" + File.separator + final_filename;
    saveAs("jpg", final_save_path);
    
    return true;
}

// ============================================================================
// ANALYSIS AND SUMMARY FUNCTIONS
// ============================================================================

function saveThresholdResults(threshold_dir, threshold_value, num_pairs) {
    if (isOpen("Results")) {
        Table.save(threshold_dir + "Particles_T" + threshold_value + ".csv", "Results");
        
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
        Table.save(threshold_dir + "Summary_T" + threshold_value + ".csv", "Summary");
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

function createFinalAnalysis(analysis_dir) {
    print("\nCreating final analysis files...");
    
    // Save detailed results
    detailed_csv = analysis_dir + "All_Results.csv";
    detailed_header = "Threshold,Particle_Number,Area,BX,BY,Width,Height\n";
    File.saveString(detailed_header, detailed_csv);
    for (i = 0; i < all_results.length; i++) {
        File.append(all_results[i] + "\n", detailed_csv);
    }
    
    // Save threshold comparison
    comparison_csv = analysis_dir + "Summary.csv";
    comparison_header = "Threshold,Total_Particles,Total_Area,Average_Area,Min_Area,Max_Area\n";
    File.saveString(comparison_header, comparison_csv);
    for (i = 0; i < summary_data.length; i++) {
        File.append(summary_data[i] + "\n", comparison_csv);
    }
    
    // Create comprehensive report
    report_path = analysis_dir + "Analysis_Report.txt";
    report_content = "EDGE PROCESSING THRESHOLD ANALYSIS REPORT\n";
    report_content += "==========================================\n\n";
    report_content += "Uses Anchor Point Brightness Standardization\n";
    report_content += "Analysis Date: " + getCurrentDateTime() + "\n";
    report_content += "Folder Pairs Processed: " + folder_pairs.length + "\n";
    report_content += "Thresholds Tested: " + arrayToString(test_thresholds) + "\n\n";
    
    report_content += "PROCESSING PIPELINE:\n";
    report_content += "1. Anchor Point Brightness Standardization\n";
    report_content += "   - Top 30% region standardized to median 200\n";
    report_content += "   - Bottom 30% region standardized to median 10\n";
    report_content += "2. Image registration (Descriptor-based 2D)\n";
    report_content += "3. Channel splitting and difference calculation\n";
    report_content += "4. Cropping (80% of original size)\n";
    report_content += "5. Threshold application (VARIABLE PARAMETER)\n";
    report_content += "6. Mask conversion and particle analysis\n\n";
    
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
    
    report_content += "\nOUTPUT STRUCTURE (Shortened for path length):\n";
    report_content += "- ThreshAnalysis/: Main analysis directory\n";
    report_content += "- Brightness/: Anchor point standardized images\n";
    report_content += "- T[X]/: Results for each threshold value\n";
    report_content += "- Proc/: Processed images with shortened names\n";
    report_content += "- All_Results.csv: Complete particle measurements\n";
    report_content += "- Summary.csv: Summary statistics by threshold\n\n";
    
    report_content += "PATH LENGTH OPTIMIZATIONS:\n";
    report_content += "- Shortened all directory names\n";
    report_content += "- Reduced filename lengths\n";
    report_content += "- Optimized folder structure\n";
    report_content += "- Should work with Windows path limitations\n";
    
    File.saveString(report_content, report_path);
    
    print("Analysis files created:");
    print("- " + detailed_csv);
    print("- " + comparison_csv); 
    print("- " + report_path);
}

// ============================================================================
// UTILITY FUNCTIONS (Updated for shorter paths)
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
    // Ensure directories end with separator
    if (!endsWith(out_dir, File.separator)) {
        out_dir = out_dir + File.separator;
    }
    if (!endsWith(processed_dir, File.separator)) {
        processed_dir = processed_dir + File.separator;
    }
    
    File.makeDirectory(out_dir);
    File.makeDirectory(processed_dir);
    
    // Shortened subdirectory names
    subdirs = newArray("Clean", "Dirty", "Reg", "Split", "Diff", "Crop", "Crop8", "Thresh", "Mask", "Final");
                      
    for (i = 0; i < subdirs.length; i++) {
        subdir_path = processed_dir + subdirs[i];
        File.makeDirectory(subdir_path);
        print("Created directory: " + subdir_path);
    }
}

function saveResultsTables(out_dir, bef_name, aft_name, threshold_value) {
    // Shortened base name
    bef_short = substring(bef_name, 4, 6);
    aft_short = substring(aft_name, 4, 6);
    base_name = "B" + bef_short + "_A" + aft_short;
    
    if (isOpen("Results")) {
        Table.save(out_dir + "P_" + base_name + "_t" + threshold_value + ".csv", "Results");
        Table.reset("Results");
    }
    
    if (isOpen("Summary")) {
        Table.save(out_dir + "S_" + base_name + "_t" + threshold_value + ".csv", "Summary");
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