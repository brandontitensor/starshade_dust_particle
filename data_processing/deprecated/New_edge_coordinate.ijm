// Enable batch mode for better performance
setBatchMode(true);

// Ask user to select the main directory
mainDir = getDirectory("Choose the main directory containing the 'Bef_# minus Aft_#' folders");
if (mainDir == "") exit("No directory selected");

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
                        print("\\Update:Processing: " + folderName + " - Image " + totalImages);
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

// Show summary message
showMessage("Processing Complete", 
    "Processed " + totalImages + " images across " + totalFolders + " folders.\n" +
    "Edge coordinates have been saved in NewEdgeCoordinates folders.");