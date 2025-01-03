run("Close All");
imagesOn = 0; // Set to 0 for batch mode
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
setBatchMode(true); // Enable batch mode
run("Set Measurements...", "area center perimeter bounding fit shape feret's skewness area_fraction redirect=None decimal=3");
if (imagesOn) {
    File.makeDirectory(out + "/images");
}
for (i = 0; i < list.length; i++) {
    if (File.isDirectory(in + list[i])) {
        subFolderName = list[i];
        subFolderPath = in + subFolderName;
        subList = getFileList(subFolderPath);
        // Create a subfolder in the output directory for the current image folder
        subFolderOut = out + "/" + subFolderName;
        File.makeDirectory(subFolderOut);
        for (counter = 0; counter < subList.length; counter++) {
            showProgress(counter + 1, subList.length);
            print(subList[counter]);
            // Check if the file is an image before processing
            if (endsWith(subList[counter], ".tif") || endsWith(subList[counter], ".tiff") ||
                endsWith(subList[counter], ".jpg") || endsWith(subList[counter], ".jpeg") ||
                endsWith(subList[counter], ".png") || endsWith(subList[counter], ".bmp")) {
                open(subFolderPath + "/" + subList[counter]);
                
                run("8-bit");
                showProgress(counter + 1, subList.length);
                setOption("BlackBackground", true);
                setThreshold(140, 255);
                run("Set Scale...", "distance=240 known=50 unit=microns");
                run("Convert to Mask");
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
        // Save the "Summary" table if it exists
        if (isOpen("Summary")) {
            Table.save(out+"/Summary_"+dayOfMonth+"_"+hour+"_"+minute+"_"+".csv", "Summary");
            Table.reset("Summary");
        } else {
            print("Summary table not found for subfolder: " + subFolderName);
        }
        // Save the "Results" table if it exists
        if (isOpen("Results")) {
            Table.save(subFolderOut + "/" + "Particles_" + dayOfMonth+"_"+hour+"_"+minute+"_" + ".csv", "Results");
            Table.reset("Results");
        } else {
            print("Results table not found for subfolder: " + subFolderName);
        }
    }
}
setBatchMode(false); // Disable batch mode at the end
run("Close All");