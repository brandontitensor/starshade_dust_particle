setBatchMode(true);

// Function to get all subfolders in a directory
function getSubfolders(dir) {
    subfolders = newArray(0);
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        if (endsWith(list[i], "/"))
            subfolders = Array.concat(subfolders, dir + list[i]);
    }
    return subfolders;
}

// Function to find the summary file that starts with "Summary "
function findSummaryFile(dir) {
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        if (startsWith(list[i], "Summary")) {
            return dir + list[i];
        }
    }
    return "";
}

// Function to get image dimensions
function getImageDimensions(imagePath) {
    dimensions = newArray(2);
    if (File.exists(imagePath)) {
        open(imagePath);
        imageId = getImageID();
        selectImage(imageId);
        dimensions[0] = getWidth();
        dimensions[1] = getHeight();
        close();
    } else {
        dimensions[0] = 0;
        dimensions[1] = 0;
    }
    return dimensions;
}

// Function to get corresponding Edge filename
function getEdgeFilename(finishedName) {
    // Replace "Difference" with "Edge" at the start of the filename
    if (startsWith(finishedName, "Difference")) {
        return "Edge" + substring(finishedName, 10); // "Difference" is 10 characters
    }
    return finishedName; // Return unchanged if doesn't start with "Difference"
}

// Main script
parentFolder = getDirectory("Choose the parent folder");
subfolders = getSubfolders(parentFolder);

for (i=0; i<subfolders.length; i++) {
    subfolder = subfolders[i];
    finishedImagesPath = subfolder + "Processed Images" + File.separator + "Finished" + File.separator;
    edgeImagesPath = subfolder + "Processed Images" + File.separator + "Edge" + File.separator;
    summaryFilePath = findSummaryFile(subfolder);
    
    if (summaryFilePath == "") {
        print("No summary file found in " + subfolder);
        continue;
    }
    
    summaryFile = File.openAsString(summaryFilePath);
    
    // Process images
    finishedImageList = getFileList(finishedImagesPath);
    Table.create("Dimension Data");
    rowIndex = 0;
    
    for (j=0; j<finishedImageList.length; j++) {
        if (endsWith(finishedImageList[j], ".tif") || endsWith(finishedImageList[j], ".jpg") || endsWith(finishedImageList[j], ".png")) {
            // Get Finished image dimensions
            finishedImagePath = finishedImagesPath + finishedImageList[j];
            finishedDimensions = getImageDimensions(finishedImagePath);
            
            // Get corresponding Edge image dimensions
            edgeFilename = getEdgeFilename(finishedImageList[j]);
            edgeImagePath = edgeImagesPath + edgeFilename;
            edgeDimensions = getImageDimensions(edgeImagePath);
            
            // Calculate differences
            widthDiff = finishedDimensions[0] - edgeDimensions[0];
            heightDiff = finishedDimensions[1] - edgeDimensions[1];
            
            // Store data in table
            Table.set("image_name", rowIndex, finishedImageList[j]);
            Table.set("edge_image_name", rowIndex, edgeFilename);
            Table.set("finished_width", rowIndex, finishedDimensions[0]);
            Table.set("finished_height", rowIndex, finishedDimensions[1]);
            Table.set("edge_width", rowIndex, edgeDimensions[0]);
            Table.set("edge_height", rowIndex, edgeDimensions[1]);
            Table.set("width_difference", rowIndex, widthDiff);
            Table.set("height_difference", rowIndex, heightDiff);
            rowIndex++;
        }             
    }
    
    // Update summary file with dimension data
    summaryLines = split(summaryFile, "\n");
    
    // Get all column data
    imageNameColumn = Table.getColumn("image_name");
    edgeImageNameColumn = Table.getColumn("edge_image_name");
    finishedWidthColumn = Table.getColumn("finished_width");
    finishedHeightColumn = Table.getColumn("finished_height");
    edgeWidthColumn = Table.getColumn("edge_width");
    edgeHeightColumn = Table.getColumn("edge_height");
    widthDiffColumn = Table.getColumn("width_difference");
    heightDiffColumn = Table.getColumn("height_difference");
    
    // Add new column headers
    headerFields = split(summaryLines[0], ",");
    newHeaders = newArray("image_name", "edge_image_name", "finished_width", "finished_height", 
                         "edge_width", "edge_height", "width_difference", "height_difference");
    headerFields = Array.concat(headerFields, newHeaders);
    summaryLines[0] = String.join(headerFields, ",");
    
    // Update each row with new data
    for (k=1; k<summaryLines.length; k++) {
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
    updatedSummaryPath = substring(summaryFilePath, 0, lastIndexOf(summaryFilePath, ".")) + "_updated.csv";
    File.saveString(updatedSummary, updatedSummaryPath);
    
    // Clear the table for the next iteration
    Table.reset("Dimension Data");
}

print("Processing complete. Updated summary files have been saved.");