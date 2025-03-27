macro "Process Edge Particles" {
    // Get the parent directory
    parentDir = getDirectory("Choose the parent directory containing Bef_ii and Aft_ii folders");
    if (!File.exists(parentDir)) {
        exit("Invalid parent directory selected");
    }

    // Process all subdirectories
    list = getFileList(parentDir);
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "Bef_")) {
            // First map particles to slices, then qualify them
            mapParticlesToSlices(parentDir + list[i]);
            qualifyEdgeParticles(parentDir + list[i]);
        }
    }
}

function getSubfolders(dir) {
    subfolders = newArray(0);
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        if (endsWith(list[i], "/"))
            subfolders = Array.concat(subfolders, dir + list[i]);
    }
    return subfolders;
}

function getDimensionDifferences(summaryFile) {
    differences = newArray(1000);
    for (i = 0; i < differences.length; i++) {
        differences[i] = "";  // Initialize all elements to empty string
    }
    
    if (!File.exists(summaryFile)) {
        return differences;
    }
    
    lines = split(File.openAsString(summaryFile), "\n");
    if (lines.length < 2) {
        return differences;
    }
    
    // Get indices for difference columns
    headers = split(lines[0], ",");
    widthDiffIndex = -1;
    heightDiffIndex = -1;
    sliceIndex = -1;
    
    for (i = 0; i < headers.length; i++) {
        if (headers[i] == "width_difference") widthDiffIndex = i;
        if (headers[i] == "height_difference") heightDiffIndex = i;
        if (headers[i] == "Slice") sliceIndex = i;
    }
    
    if (widthDiffIndex == -1 || heightDiffIndex == -1 || sliceIndex == -1) {
        return differences;
    }
    
    // Process each line
    for (i = 1; i < lines.length; i++) {
        fields = split(lines[i], ",");
        if (fields.length <= maxOf(widthDiffIndex, heightDiffIndex)) continue;
        
        // Extract slice number
        sliceName = fields[sliceIndex];
        edgeMatch = indexOf(sliceName, "caliwaferedge");
        if (edgeMatch == -1) continue;
        
        numberStr = substring(sliceName, edgeMatch + 12, edgeMatch + 20);
        sliceNum = parseInt(substring(numberStr, 6));
        if (isNaN(sliceNum)) continue;
        
        // Store width and height differences for this slice
        widthDiff = parseFloat(fields[widthDiffIndex]);
        heightDiff = parseFloat(fields[heightDiffIndex]);
        if (!isNaN(widthDiff) && !isNaN(heightDiff)) {
            differences[sliceNum] = d2s(widthDiff,6) + "," + d2s(heightDiff,6);
        }
    }
    
    return differences;
}

function qualifyEdgeParticles(folder) {
    // Extract sample number from the folder name
    folderName = File.getName(folder);
    if (indexOf(folderName, " minus") == -1) {
        print("Invalid folder name format: " + folderName);
        return;
    }
    sampleNumber = substring(folderName, 4, indexOf(folderName, " minus"));
    
    // Construct full paths
    particlesFile = folder + "Particles Bef_" + sampleNumber + " minus Aft_" + sampleNumber + ".csv";
    summaryFile = folder + "Summary Bef_" + sampleNumber + " minus Aft_" + sampleNumber + "_updated.csv";
    edgeCoordDir = folder + "Processed Images" + File.separator + "NewEdgeCoordinates" + File.separator;
    
    // Print paths for debugging
    print("Processing folder: " + folder);
    print("Particles file: " + particlesFile);
    print("Summary file: " + summaryFile);
    print("Edge coordinates directory: " + edgeCoordDir);
    
    // Get dimension differences from summary file
    dimensionDiffs = getDimensionDifferences(summaryFile);
    
    // Verify files exist
    if (!File.exists(particlesFile) || !File.exists(edgeCoordDir)) {
        print("Required files not found for sample " + sampleNumber);
        return;
    }

    // Read particles file
    particleLines = split(File.openAsString(particlesFile), "\n");
    if (particleLines.length < 2) {
        print("Invalid particles file format for sample " + sampleNumber);
        return;
    }

    // Get header indices for particles file
    particleHeaders = split(particleLines[0], ",");
    bxIndex = -1;
    byIndex = -1;
    heightIndex = -1;
    widthIndex = -1;
    sliceIndex = -1;
    isQualifiedIndex = -1;
    
    for (i = 0; i < particleHeaders.length; i++) {
        if (particleHeaders[i] == "BX") bxIndex = i;
        if (particleHeaders[i] == "BY") byIndex = i;
        if (particleHeaders[i] == "Height") heightIndex = i;
        if (particleHeaders[i] == "Width") widthIndex = i;
        if (particleHeaders[i] == "Slice") sliceIndex = i;
        if (particleHeaders[i] == "IsQualified") isQualifiedIndex = i;
    }

    // Verify required columns exist
    if (bxIndex == -1 || byIndex == -1 || heightIndex == -1 || widthIndex == -1) {
        print("Required columns not found in particles file");
        return;
    }

    // Add IsQualified column if it doesn't exist
    if (isQualifiedIndex == -1) {
        particleHeaders = Array.concat(particleHeaders, "IsQualified");
        isQualifiedIndex = particleHeaders.length - 1;
        particleLines[0] = String.join(particleHeaders, ",");
    }

    // Load edge coordinates for each slice
    edgeCoords = newArray(1000);
    edgeFiles = getFileList(edgeCoordDir);
    
    // Get valid slices from particle data
    validSlices = newArray(1000);
    if (sliceIndex != -1) {
        for (i = 1; i < particleLines.length; i++) {
            particleData = split(particleLines[i], ",");
            if (particleData.length > sliceIndex) {
                slice = parseInt(particleData[sliceIndex]);
                validSlices[slice] = true;
            }
        }
    }
    
    // Process edge coordinate files
    for (i = 0; i < edgeFiles.length; i++) {
        if (endsWith(edgeFiles[i], ".csv")) {
            sliceNum = extractSliceNumber(edgeFiles[i]);
            if (sliceNum == -1 || (sliceIndex != -1 && !validSlices[sliceNum])) continue;
            
            edgeData = split(File.openAsString(edgeCoordDir + edgeFiles[i]), "\n");
            if (edgeData.length < 2) continue;
            
            coordArray = newArray(edgeData.length - 1);
            for (j = 1; j < edgeData.length; j++) {
                coords = split(edgeData[j], ",");
                if (coords.length >= 2) {
                    scaledX = parseFloat(coords[0]) * (50.0/240.0);
                    scaledY = parseFloat(coords[1]) * (50.0/240.0);
                    coordArray[j-1] = d2s(scaledX,6) + "," + d2s(scaledY,6);
                }
            }
            edgeCoords[sliceNum] = String.join(coordArray, ";");
        }
    }

    // Process each particle
    newParticleLines = newArray(particleLines.length);
    newParticleLines[0] = particleLines[0];
    
    for (i = 1; i < particleLines.length; i++) {
        particleData = split(particleLines[i], ",");
        
        // Ensure particle data has enough elements for all columns
        while (particleData.length < particleHeaders.length) {
            particleData = Array.concat(particleData, "");
        }
        
        if (particleData.length <= maxOf(bxIndex, byIndex) || 
            particleData.length <= maxOf(heightIndex, widthIndex)) {
            newParticleLines[i] = particleLines[i];
            continue;
        }

        // Get particle data
        bx = parseFloat(particleData[bxIndex]);
        by = parseFloat(particleData[byIndex]);
        height = parseFloat(particleData[heightIndex]);
        width = parseFloat(particleData[widthIndex]);
        
        // Get slice number from data if available
        slice = -1;
        if (sliceIndex != -1 && particleData.length > sliceIndex) {
            slice = parseInt(particleData[sliceIndex]);
        }
        
        // Apply dimension differences if available for this slice
        if (slice != -1 && dimensionDiffs[slice] != "") {
            diffs = split(dimensionDiffs[slice], ",");
            if (diffs.length >= 2) {
                widthDiff = parseFloat(diffs[0]);
                heightDiff = parseFloat(diffs[1]);
                
                // Apply half of the differences to coordinates, with scaling
                bx = bx + ((widthDiff * (-50.0/240.0)) / 2);
                by = by + ((heightDiff * (-50.0/240.0)) / 2);
            }
        }
        
        particleTop = by + height;
        particleLeft = bx;
        particleRight = bx + width;

        isQualified = false;

        // Check qualification against edge coordinates if slice is valid
        if (slice != -1 && edgeCoords[slice] != "") {
            edgePoints = split(edgeCoords[slice], ";");
            for (p = 0; p < edgePoints.length; p++) {
                if (edgePoints[p] == "") continue;
                
                coords = split(edgePoints[p], ",");
                if (coords.length < 2) continue;
                
                edgeX = parseFloat(coords[0]);
                edgeY = parseFloat(coords[1]);
                
                if (edgeX >= particleLeft && edgeX <= particleRight) {
                    if ((particleTop + 2) >= edgeY) {
                        isQualified = true;
                        break;
                    }
                }
            }
        }

        // Update particle data with qualification status
        particleData[isQualifiedIndex] = "" + isQualified;
        
        // Join particle data back into line
        newParticleLines[i] = String.join(particleData, ",");
    }

    // Save updated particles file
    File.saveString(String.join(newParticleLines, "\n"), particlesFile);
    print("Processed sample " + sampleNumber + ": Updated qualification status with dimension adjustments");
}

function extractSliceNumber(filename) {
    // Extract slice number from various filename formats
    edgeMatch = indexOf(filename, "caliwaferedge");
    if (edgeMatch != -1) {
        numberStr = substring(filename, edgeMatch + 12, edgeMatch + 20);
        return parseInt(substring(numberStr, 6));
    }
    return -1;
}

function mapParticlesToSlices(folder) {
    // Extract the folder name and sample number
    folderName = File.getName(folder);
    if (indexOf(folderName, " minus") == -1) {
        print("Invalid folder name format: " + folderName);
        return;
    }
    sampleNumber = substring(folderName, 4, indexOf(folderName, " minus"));
    
    // Get paths to required files
    particlesFile = folder + "Particles Bef_" + sampleNumber + " minus Aft_" + sampleNumber + ".csv";
    summaryFile = folder + "Summary Bef_" + sampleNumber + " minus Aft_" + sampleNumber + "_updated.csv";
    
    // Verify files exist
    if (!File.exists(particlesFile) || !File.exists(summaryFile)) {
        print("Required files not found for sample " + sampleNumber);
        return;
    }

    // Read files
    particleLines = split(File.openAsString(particlesFile), "\n");
    summaryLines = split(File.openAsString(summaryFile), "\n");
    
    // Verify file contents
    if (particleLines.length < 2 || summaryLines.length < 2) {
        print("Invalid file format for sample " + sampleNumber);
        return;
    }

    // Get header indices for particles file
    particleHeaders = split(particleLines[0], ",");
    sliceIndex = -1;
    for (i = 0; i < particleHeaders.length; i++) {
        if (particleHeaders[i] == "Slice") sliceIndex = i;
    }

    // If Slice column doesn't exist, add it
    if (sliceIndex == -1) {
        particleHeaders = Array.concat(particleHeaders, "Slice");
        sliceIndex = particleHeaders.length - 1;
        particleLines[0] = String.join(particleHeaders, ",");
    }

    // Get Count and Slice columns from summary file
    summaryHeaders = split(summaryLines[0], ",");
    countIndex = -1;
    sliceNameIndex = -1;
    for (i = 0; i < summaryHeaders.length; i++) {
        if (summaryHeaders[i] == "Count") countIndex = i;
        if (summaryHeaders[i] == "Slice") sliceNameIndex = i;
    }

    // Verify required columns exist
    if (countIndex == -1 || sliceNameIndex == -1) {
        print("Required columns not found in summary file for sample " + sampleNumber);
        return;
    }

    // Create arrays to store valid slices and their cumulative counts
    validSlices = newArray(1000);
    cumulativeCounts = newArray(1000);
    currentTotal = 0;
    maxValidSlice = -1;

    // Process summary data to get valid slices and their cumulative counts
    for (i = 1; i < summaryLines.length; i++) {
        summaryData = split(summaryLines[i], ",");
        if (summaryData.length <= countIndex || summaryData.length <= sliceNameIndex) {
            continue;
        }

        // Extract slice identifier from the filename in summary
        sliceName = summaryData[sliceNameIndex];
        edgeMatch = indexOf(sliceName, "caliwaferedge");
        if (edgeMatch == -1) continue;
        
        numberStr = substring(sliceName, edgeMatch + 12, edgeMatch + 20);
        sliceNum = parseInt(substring(numberStr, 6));
        
        if (isNaN(sliceNum)) continue;

        currentCount = parseInt(summaryData[countIndex]);
        if (isNaN(currentCount)) continue;

        // Record valid slice and its cumulative count
        validSlices[sliceNum] = true;
        currentTotal += currentCount;
        cumulativeCounts[sliceNum] = currentTotal;
        if (sliceNum > maxValidSlice) maxValidSlice = sliceNum;
    }

    // Process each particle
    newParticleLines = newArray(particleLines.length);
    newParticleLines[0] = particleLines[0];
    
    for (i = 1; i < particleLines.length; i++) {
        sliceNumber = -1;
        particleIndex = i;
        
        // Find appropriate slice for this particle
        for (j = 0; j <= maxValidSlice; j++) {
            if (validSlices[j] && particleIndex <= cumulativeCounts[j]) {
                sliceNumber = j;
                break;
            }
        }

        // Get particle data and update slice
        particleData = split(particleLines[i], ",");
        
        // Ensure particle data has enough elements for all columns
        while (particleData.length < particleHeaders.length) {
            particleData = Array.concat(particleData, "");
        }
        
        // Update slice number
        if (sliceNumber == -1) {
            print("Warning: Could not assign slice number to particle " + i);
            particleData[sliceIndex] = "0";
        } else {
            particleData[sliceIndex] = "" + sliceNumber;
        }
        
        // Join particle data back into line
        newParticleLines[i] = String.join(particleData, ",");
    }

    // Save updated particles file
    File.saveString(String.join(newParticleLines, "\n"), particlesFile);
    print("Processed sample " + sampleNumber + ": Updated slice numbers for particles");
}