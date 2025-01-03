// Image Registration and Difference
// User selects two directories (Dirty and Clean)
// Corresponding images in each directory are registered together

function getInputDirectory(prompt) {
    return getDirectory(prompt);
}

function createOutputDirectories(baseDir, folderName) {
    var dirs = [
        "", "/Processed Images", "/8 bit clean", "/8 bit dirty", "/Registration",
        "/Split", "/Split/C1Fused", "/Split/C2Fused", "/Difference", "/Crop",
        "/Crop8bit", "/Crop8BitThreshold", "/Crop8BitThresholdMask", "/Finished"
    ];
    
    for (var i = 0; i < dirs.length; i++) {
        var dir = baseDir + "/" + folderName + dirs[i];
        File.makeDirectory(dir);
    }
    
    return baseDir + "/" + folderName;
}

function processImage(inDir1, inDir2, outDir, file1, file2) {
    var fullFileName = file1 + "minus" + file2;
    
    // Process clean image
    open(inDir1 + file1);
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", outDir + "/8 bit clean/8bit" + file1);
    var title1 = getTitle();

    // Process dirty image
    open(inDir2 + file2);
    run("8-bit");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", outDir + "/8 bit dirty/8bit" + file2);
    var title2 = getTitle();

    // Perform registration
    run("Descriptor-based registration (2d/3d)", "first_image="+ title1 + " second_image=" + title2 + " brightness_of=[Advanced ...] approximate_size=[Advanced ...] type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] number_of_neighbors=5 redundancy=4 significance=3 allowed_error_for_ransac=6 choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 create_overlayed add_point_rois interpolation=[Linear Interpolation] detection_sigma=3.9905 threshold=0.0537");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", outDir + "/Registration/Registered" + fullFileName);

    // Split channels and process
    run("Split Channels");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    selectWindow("C1-Fused " + file1 + " & " + file2);
    saveAs("jpg", outDir + "/Split/C1Fused/C1-Fused " + file1 + " & " + file2);
    selectWindow("C2-Fused " + file1 + " & " + file2);
    saveAs("jpg", outDir + "/Split/C2Fused/C2-Fused " + file1 + " & " + file2);

    // Calculate and process difference
    imageCalculator("Difference create", "C1-Fused " + file1 + " & " + file2,"C2-Fused " + file1 + " & " + file2);
    saveAs("jpg", outDir + "/Difference/Difference" + fullFileName);
    run("Specify...", "width=2860 height=2140 x=1440 y=1080 centered");
    run("Crop");
    run("Set Scale...", "distance=240 known=50 unit=micron");
    saveAs("jpg", outDir + "/Crop/Difference" + fullFileName);
    run("8-bit");
    saveAs("jpg", outDir + "/Crop8bit/Difference" + fullFileName);

    setThreshold(30, 255);
    run("Threshold...");
    saveAs("jpg", outDir + "/Crop8BitThreshold/Difference" + fullFileName);
    
    run("Convert to Mask");
    saveAs("jpg", outDir + "/Crop8BitThresholdMask/Difference" + fullFileName);
    run("Set Measurements...", "area bounding redirect=None decimal=3");
    run("Analyze Particles...", "  show=Masks display exclude include summarize");
    saveAs("jpg", outDir + "/Finished/" +  fullFileName);

    run("Close All");
}

// Main execution
run("Close All");
close("Results");
close("Summary");

var inDir1 = getInputDirectory("Choose first (clean) directory");
var inDir2 = getInputDirectory("Choose second (dirty) directory");

var fileList1 = getFileList(inDir1);
var fileList2 = getFileList(inDir2);

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
var folderName = File.getNameWithoutExtension(inDir1) + " minus " + File.getNameWithoutExtension(inDir2) + "_" + year + "_" + (month+1) + "_" + dayOfMonth + "_" + hour  + "_" + minute + "_" + second;

var outDir = createOutputDirectories(inDir1 + "/../Edge Measurements", folderName);

for (var i = 0; i < fileList1.length; i++) {
    showProgress(i+1, fileList1.length);
    if (indexOf(fileList1[i], "Edge") >= 0) {
        var file1 = fileList1[i];
        var file2 = fileList2[i];  // Assuming the files are in the same order in both directories
        processImage(inDir1, inDir2, outDir + "/Processed Images", file1, file2);
    }
}

Table.save(outDir + "/Particles " + File.getName(inDir1) + " minus " + File.getName(inDir2) + ".csv", "Results");
Table.save(outDir + "/Summary " + File.getName(inDir1) + " minus " + File.getName(inDir2) + ".csv", "Summary");
close("Results");
close("Summary");