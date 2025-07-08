run("Close All");
imagesOn = 1; // Set to 1 to save intermediate images
numSampleImages = 7; // Number of images to save intermediate steps for per folder

in = getDirectory("Choose a directory containing folders with images");

// Check for the required directories
if (!File.isDirectory(in + "/ImageJ Processed/")) {
    // If no directory exists for processed data, create one
    print("Processing directory does not exist, creating one...");
    File.makeDirectory(in + "/ImageJ Processed/");
}

// Set the output directory for processed data
out = in + "/ImageJ Processed";

// Get the list of folders in the input directory
list = getFileList(in);
setBatchMode(true); // Enable batch mode for faster processing

// Set measurements to include median for brightness measurement
run("Set Measurements...", "area center perimeter bounding fit shape feret's skewness area_fraction median redirect=None decimal=3");

// Create main intermediate steps directory
if (imagesOn) {
    File.makeDirectory(out + "/Intermediate_Steps");
}

// Arrays to store median brightness information for summary
var median_info = newArray(0);

for (i = 0; i < list.length; i++) {
    if (File.isDirectory(in + list[i])) {
        subFolderName = list[i];
        subFolderPath = in + subFolderName;
        subList = getFileList(subFolderPath);
        
        // Filter to only image files
        imageFiles = newArray(0);
        for (j = 0; j < subList.length; j++) {
            if (endsWith(subList[j], ".tif") || endsWith(subList[j], ".tiff") ||
                endsWith(subList[j], ".jpg") || endsWith(subList[j], ".jpeg") ||
                endsWith(subList[j], ".png") || endsWith(subList[j], ".bmp")) {
                imageFiles = Array.concat(imageFiles, subList[j]);
            }
        }
        
        // Calculate which images to save intermediate steps for
        sampleIndices = calculateSampleIndices(imageFiles.length, numSampleImages);
        
        // Create a subfolder in the output directory for the current image folder
        subFolderOut = out + "/" + subFolderName;
        File.makeDirectory(subFolderOut);
        
        // Create intermediate steps subfolder for this image folder
        if (imagesOn) {
            intermediateStepsDir = out + "/Intermediate_Steps/" + subFolderName;
            File.makeDirectory(intermediateStepsDir);
            
            // Create subdirectories for each processing step
            File.makeDirectory(intermediateStepsDir + "/01_Original");
            File.makeDirectory(intermediateStepsDir + "/02_After_Median_Measurement");
            File.makeDirectory(intermediateStepsDir + "/03_After_32bit_Conversion");
            File.makeDirectory(intermediateStepsDir + "/04_After_Brightness_Offset");
            File.makeDirectory(intermediateStepsDir + "/05_After_Post_Transform_Measurement");
            File.makeDirectory(intermediateStepsDir + "/06_After_8bit_Conversion");
            File.makeDirectory(intermediateStepsDir + "/07_After_Threshold_Set");
            File.makeDirectory(intermediateStepsDir + "/08_After_Scale_Set");
            File.makeDirectory(intermediateStepsDir + "/09_Final_Mask");
            
            // Create a text file listing which images were sampled
            sampledImagesLog = "Sampled Images for Intermediate Steps:\n";
            for (k = 0; k < sampleIndices.length; k++) {
                if (sampleIndices[k] < imageFiles.length) {
                    sampledImagesLog += "Index " + (sampleIndices[k] + 1) + ": " + imageFiles[sampleIndices[k]] + "\n";
                }
            }
            File.saveString(sampledImagesLog, intermediateStepsDir + "/sampled_images_log.txt");
        }
        
        for (counter = 0; counter < subList.length; counter++) {
            showProgress(counter + 1, subList.length);
            print(subList[counter]);
            
            // Check if the file is an image before processing
            if (endsWith(subList[counter], ".tif") || endsWith(subList[counter], ".tiff") ||
                endsWith(subList[counter], ".jpg") || endsWith(subList[counter], ".jpeg") ||
                endsWith(subList[counter], ".png") || endsWith(subList[counter], ".bmp")) {
                
                // Find the index of this image in the imageFiles array
                imageIndex = getImageIndex(imageFiles, subList[counter]);
                saveIntermediateSteps = imagesOn && isInArray(sampleIndices, imageIndex);
                
                open(subFolderPath + "/" + subList[counter]);
                image_title = getTitle();
                baseFileName = File.getNameWithoutExtension(subList[counter]);
                
                // STEP 1: Save original image (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/01_Original/" + baseFileName + "_original.tif");
                }
                
                // STEP 2: Measure original median brightness of entire image
                run("Select All");
                // Use getValue instead of Results table to avoid interfering with particle results
                original_median = getValue("Median");
                print("Original median brightness for " + subList[counter] + ": " + original_median);
                
                // Save image after median measurement (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/02_After_Median_Measurement/" + baseFileName + "_measured.tif");
                }
                
                // STEP 3: Transform image to set median brightness to 0
                // Calculate the offset needed to make median = 0
                offset_value = -original_median;
                
                if (original_median != 0) {
                    // Apply brightness offset using Add operation
                    run("32-bit"); // Convert to 32-bit to handle negative values
                    
                    // Save after 32-bit conversion (only for selected images)
                    if (saveIntermediateSteps) {
                        saveAs("Tiff", intermediateStepsDir + "/03_After_32bit_Conversion/" + baseFileName + "_32bit.tif");
                    }
                    
                    run("Add...", "value=" + offset_value);
                    print("Applied offset of " + offset_value + " to " + subList[counter]);
                    
                    // Save after brightness offset (only for selected images)
                    if (saveIntermediateSteps) {
                        saveAs("Tiff", intermediateStepsDir + "/04_After_Brightness_Offset/" + baseFileName + "_offset.tif");
                    }
                } else {
                    print("No transformation needed for " + subList[counter] + " (median already 0)");
                    // Still convert to 32-bit for consistency
                    run("32-bit");
                    
                    // Save after 32-bit conversion (only for selected images)
                    if (saveIntermediateSteps) {
                        saveAs("Tiff", intermediateStepsDir + "/03_After_32bit_Conversion/" + baseFileName + "_32bit.tif");
                        saveAs("Tiff", intermediateStepsDir + "/04_After_Brightness_Offset/" + baseFileName + "_no_offset.tif");
                    }
                }
                
                // STEP 4: Measure median brightness after transformation to confirm it's 0
                run("Select All");
                // Use getValue instead of Results table to avoid interfering with particle results
                post_transform_median = getValue("Median");
                print("Post-transformation median brightness for " + subList[counter] + ": " + post_transform_median);
                
                // Save after post-transformation measurement (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/05_After_Post_Transform_Measurement/" + baseFileName + "_post_measure.tif");
                }
                
                // Store median information for this image
                median_info = Array.concat(median_info, subFolderName + "|" + subList[counter] + "|" + original_median + "|" + post_transform_median);
                
                // STEP 5: Continue with original processing
                run("8-bit");
                
                // Save after 8-bit conversion (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/06_After_8bit_Conversion/" + baseFileName + "_8bit.tif");
                }
                
                showProgress(counter + 1, subList.length);
                setOption("BlackBackground", true);
                setThreshold(72, 255);
                
                // Save after threshold setting (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/07_After_Threshold_Set/" + baseFileName + "_threshold.tif");
                }
                
                run("Set Scale...", "distance=240 known=50 unit=microns");
                
                // Save after scale setting (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/08_After_Scale_Set/" + baseFileName + "_scaled.tif");
                }
                
                run("Convert to Mask");
                
                // Save final mask (only for selected images)
                if (saveIntermediateSteps) {
                    saveAs("Tiff", intermediateStepsDir + "/09_Final_Mask/" + baseFileName + "_mask.tif");
                }
                
                run("Analyze Particles...", " display summarize");
                
                close("*");
            } else {
                showProgress(counter + 1, subList.length);
                print("Skipping non-image file: " + subList[counter]);
            }
        }
        
        // Get the current date and time
        getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
        dateTime = year + "_" + month + "_" + dayOfMonth + "_" + hour + "_" + minute + "_" + second;
        
        // Save the "Summary" table if it exists and add median brightness information
        if (isOpen("Summary")) {
            // Add median brightness columns to existing Summary table
            addMedianDataToSummary(median_info, subFolderName);
            // Clean folder name for filename (remove trailing slash if present)
            cleanFolderName = replace(subFolderName, "/", "");
            Table.save(subFolderOut + "/" + "Summary_" + cleanFolderName + ".csv", "Summary");
            Table.reset("Summary");
        } else {
            print("Summary table not found for subfolder: " + subFolderName);
        }
        
        // Save the "Results" table if it exists
        if (isOpen("Results")) {
            // Clean folder name for filename (remove trailing slash if present)
            cleanFolderName = replace(subFolderName, "/", "");
            Table.save(subFolderOut + "/" + "Particles_" + cleanFolderName + ".csv", "Results");
            Table.reset("Results");
        } else {
            print("Results table not found for subfolder: " + subFolderName);
        }
        
        // Clear median info for next folder
        median_info = newArray(0);
    }
}

setBatchMode(false); // Disable batch mode at the end
run("Close All");

// Function to calculate which image indices to sample for intermediate steps
function calculateSampleIndices(totalImages, numSamples) {
    if (totalImages <= numSamples) {
        // If we have fewer images than desired samples, use all of them
        indices = newArray(totalImages);
        for (i = 0; i < totalImages; i++) {
            indices[i] = i;
        }
        return indices;
    }
    
    // Calculate evenly spaced indices
    indices = newArray(numSamples);
    if (numSamples == 1) {
        indices[0] = floor(totalImages / 2); // Middle image
    } else {
        stepSize = (totalImages - 1) / (numSamples - 1);
        for (i = 0; i < numSamples; i++) {
            indices[i] = floor(i * stepSize);
        }
    }
    return indices;
}

// Function to find the index of an image in the imageFiles array
function getImageIndex(imageFiles, imageName) {
    for (i = 0; i < imageFiles.length; i++) {
        if (imageFiles[i] == imageName) {
            return i;
        }
    }
    return -1; // Not found
}

// Function to check if a value is in an array
function isInArray(array, value) {
    for (i = 0; i < array.length; i++) {
        if (array[i] == value) {
            return true;
        }
    }
    return false;
}

function addMedianDataToSummary(median_data, folder_name) {
    // Get the number of rows in the Summary table
    num_summary_rows = Table.size("Summary");
    
    // Add new columns to Summary table for median brightness data
    if (num_summary_rows > 0) {
        // Initialize the new columns
        for (i = 0; i < num_summary_rows; i++) {
            Table.set("Original_Median_Brightness", i, 0, "Summary");
            Table.set("Post_Transform_Median_Brightness", i, 0, "Summary");
            Table.set("Transformation_Applied", i, "No", "Summary");
        }
        
        // Fill in the median data for each row
        median_index = 0;
        for (i = 0; i < num_summary_rows && median_index < median_data.length; i++) {
            if (median_index < median_data.length) {
                info_parts = split(median_data[median_index], "|");
                if (info_parts.length >= 4) {
                    curr_folder = info_parts[0];
                    curr_image = info_parts[1];
                    orig_median = parseFloat(info_parts[2]);
                    post_median = parseFloat(info_parts[3]);
                    if (orig_median != 0) {
                        transformation_applied = "Yes";
                    } else {
                        transformation_applied = "No";
                    }
                    
                    // Set the values in the Summary table
                    Table.set("Original_Median_Brightness", i, orig_median, "Summary");
                    Table.set("Post_Transform_Median_Brightness", i, post_median, "Summary");
                    Table.set("Transformation_Applied", i, transformation_applied, "Summary");
                    
                    median_index++;
                }
            }
        }
        
        print("Added median brightness data to Summary table for folder: " + folder_name);
    } else {
        print("Warning: Summary table is empty for folder: " + folder_name);
    }
}