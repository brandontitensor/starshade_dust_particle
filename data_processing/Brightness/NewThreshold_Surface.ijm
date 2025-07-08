// Threshold Analysis Script - FIXED VERSION
// Analyzes histogram and tests multiple thresholds to find optimal value
run("Close All");
in = getDirectory("Choose a directory with sample images for threshold testing");
out = in + "/Threshold_Analysis/";
File.makeDirectory(out);
list = getFileList(in);
setBatchMode(true);

// Arrays to store threshold performance data
var threshold_data = newArray(0);
var image_names = newArray(0);

// Test range of thresholds
test_thresholds = newArray(60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85);

print("Starting threshold analysis...");

for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif") || endsWith(list[i], ".jpg") || endsWith(list[i], ".png")) {
        open(in + list[i]);
        image_name = File.getNameWithoutExtension(list[i]);
        original_title = getTitle();
        
        // Apply your median normalization (same as main script)
        run("Select All");
        run("Set Measurements...", "median");
        run("Measure");
        original_median = getResult("Median", nResults-1);
        run("Clear Results"); // Clear after getting median
        
        if (original_median != 0) {
            run("32-bit");
            offset_value = -original_median;
            run("Add...", "value=" + offset_value);
        }
        
        run("8-bit");
        run("Set Scale...", "distance=240 known=50 unit=microns");
        
        // Test each threshold
        for (t = 0; t < test_thresholds.length; t++) {
            // Duplicate image for testing
            selectWindow(original_title);
            run("Duplicate...", "title=test_image");
            
            // Apply threshold - use different approach
            setAutoThreshold("Default dark");
            setThreshold(test_thresholds[t], 255);
            setOption("BlackBackground", true);
            run("Convert to Mask");
            
            // Clear any previous results before analysis
            if (isOpen("Results")) {
                selectWindow("Results");
                run("Close");
            }
            
            // Analyze particles with fresh results table
            run("Set Measurements...", "area center perimeter bounding fit shape feret's");
            run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 display clear");
            
            // Get particle count from fresh results
            particle_count = nResults;
            
            if (particle_count > 0) {
                avg_area = 0;
                for (p = 0; p < particle_count; p++) {
                    avg_area += getResult("Area", p);
                }
                avg_area = avg_area / particle_count;
            } else {
                avg_area = 0;
            }
            
            // Save test image
            saveAs("PNG", out + image_name + "_threshold_" + test_thresholds[t] + ".png");
            
            // Record data
            data_line = image_name + "," + test_thresholds[t] + "," + particle_count + "," + avg_area;
            threshold_data = Array.concat(threshold_data, data_line);
            
            // Debug print
            print("Image: " + image_name + ", Threshold: " + test_thresholds[t] + ", Count: " + particle_count);
            
            // Clean up for next threshold test
            run("Clear Results");
            close("test_image");
        }
        
        image_names = Array.concat(image_names, image_name);
        close(original_title);
    }
}

// Create summary CSV
csv_path = out + "Threshold_Analysis_Results.csv";
File.saveString("Image_Name,Threshold_Value,Particle_Count,Average_Area\n", csv_path);
for (i = 0; i < threshold_data.length; i++) {
    File.append(threshold_data[i] + "\n", csv_path);
}

setBatchMode(false);
print("Threshold analysis complete! Check: " + csv_path);
print("Review the saved threshold test images to visually assess quality.");