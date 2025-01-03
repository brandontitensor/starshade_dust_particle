// Close all open windows and clear results
run("Close All");
close("Results");
close("Summary");

// Ask user to select parent directory
parentDir = getDirectory("Choose a parent directory containing subfolders with images to process");

// Get list of subfolders
subfolderList = getFileList(parentDir);

// Function to process images in a subfolder
function processSubfolder(inDir1, inDir2) {
    // Get list of all files within sample directories
    ls_1 = getFileList(inDir1);
    ls_2 = getFileList(inDir2);

    // Filter files to only include edge images
    Folder1 = File.getName(inDir1);
    Folder2 = File.getName(inDir2);

    // Create output directory
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    folderName = File.getNameWithoutExtension(inDir1) + " minus " + File.getNameWithoutExtension(inDir2) + "_" + year + "_" + (month+1) + "_" + dayOfMonth + "_" + hour  + "_" + minute + "_" + second;
    out_dir = parentDir + "Edge Measurements/" + folderName;
    File.makeDirectory(out_dir);
    processed_dir = out_dir + "/Processed Images";

    // Create necessary subdirectories
    subdirs = newArray("/8 bit clean", "/8 bit dirty", "/Registration", "/Split", "/Split/C1Fused", 
                       "/Split/C2Fused", "/Difference", "/Crop", "/Crop8bit", "/Crop8BitThreshold", 
                       "/Crop8BitThresholdMask", "/Finished");
    for (i = 0; i < subdirs.length; i++) {
        File.makeDirectory(processed_dir + subdirs[i]);
    }

    // Process each image
    for(i=0; i<ls_1.length; i++) {
        showProgress(i+1, ls_1.length);
        
        file1 = File.getNameWithoutExtension(inDir1+ls_1[i]);
        file2 = File.getNameWithoutExtension(inDir2+ls_2[i]);
        fullFileName = file1 + "minus" + file2;

        // Process clean image
        open(inDir1+ls_1[i]);
        run("8-bit");
        run("Set Scale...", "distance=240 known=50 unit=micron");
        saveAs("Jpeg", processed_dir + "/8 bit clean/8bit" + file1);
        title1 = getTitle();

        // Process dirty image
        open(inDir2+ls_2[i]);
        run("8-bit");
        run("Set Scale...", "distance=240 known=50 unit=micron");
        saveAs("Jpeg", processed_dir + "/8 bit dirty/8bit" + file2);
        title2 = getTitle();

        // Perform registration
        run("Descriptor-based registration (2d/3d)", "first_image="+ title1 + " second_image=" + title2 + " brightness_of=[Advanced ...] approximate_size=[Advanced ...] type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] number_of_neighbors=5 redundancy=4 significance=3 allowed_error_for_ransac=6 choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 create_overlayed add_point_rois interpolation=[Linear Interpolation] detection_sigma=3.9905 threshold=0.0537");
        run("Set Scale...", "distance=240 known=50 unit=micron");
        saveAs("Jpeg", processed_dir + "/Registration/Registered" + fullFileName);

        // Split channels and process
        run("Split Channels");
        run("Set Scale...", "distance=240 known=50 unit=micron");
        selectWindow("C1-Fused " + file1 + " & " + file2);
        saveAs("Jpeg", processed_dir + "/Split/C1Fused/C1-Fused " + file1 + " & " + file2);
        selectWindow("C2-Fused " + file1 + " & " + file2);
        saveAs("Jpeg", processed_dir + "/Split/C2Fused/C2-Fused " + file1 + " & " + file2);

        // Calculate difference and process
        imageCalculator("Difference create", "C1-Fused " + file1 + " & " + file2,"C2-Fused " + file1 + " & " + file2);
        saveAs("Jpeg", processed_dir + "/Difference/Difference" + fullFileName);
        run("Specify...", "width=2860 height=2140 x=1440 y=1080 centered");
        run("Crop");
        run("Set Scale...", "distance=240 known=50 unit=micron");
        saveAs("Jpeg", processed_dir + "/Crop/Difference" + fullFileName);
        run("8-bit");
        saveAs("Jpeg", processed_dir + "/Crop8bit/Difference" + fullFileName);
        setThreshold(30, 255);
        run("Threshold...");
        saveAs("Jpeg", processed_dir + "/Crop8bitThreshold/Difference" + fullFileName);
        
        run("Convert to Mask");
        saveAs("Jpeg", processed_dir + "/Crop8bitThresholdMask/Difference" + fullFileName);
        run("Set Measurements...", "area bounding redirect=None decimal=3");
        run("Analyze Particles...", "  show=Masks display exclude include summarize");
        saveAs("Jpeg", processed_dir + "/Finished/" +  fullFileName);

        run("Close All");
    }

    // Save results
    Table.save(out_dir+ "/Particles " + Folder1 + " minus " + Folder2 + ".csv", "Results");
    Table.save(out_dir+ "/Summary " + Folder1 + " minus " + Folder2 + ".csv", "Summary");
    close("Results");
    close("Summary");
}

// Process each subfolder
for (i = 0; i < subfolderList.length; i++) {
    if (endsWith(subfolderList[i], "/")) {  // Check if it's a directory
        currentFolder = parentDir + subfolderList[i];
        inDir1 = currentFolder + "clean/";
        inDir2 = currentFolder + "dirty/";
        
        if (File.exists(inDir1) && File.exists(inDir2)) {
            print("Processing subfolder: " + subfolderList[i]);
            processSubfolder(inDir1, inDir2);
        } else {
            print("Skipping subfolder: " + subfolderList[i] + " (missing clean or dirty folder)");
        }
    }
}

showMessage("Processing complete for all subfolders.");