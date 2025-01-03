// Image Registration and Difference
// User selects two directories (Dirty and Clean)
// Corresponding images in each directory are registered together
run("Close All");
run("Collect Garbage");
run("Fresh Start");

dir0 = "/Users/brandontitensor/Desktop/College/Research/Dust_Contamination/Trials/Processing/Calibration/";
dir1 = "/Users/brandontitensor/Desktop/College/Research/Dust_Contamination/Trials/Processing/Calibration/";
// User selects input directories
in_dir_1 = getDirectory(dir0); // Choose first (clean) directory
in_dir_2 = getDirectory(dir0); // Choose second (dirty) directory
// Get list of all files within sample directories
ls_1 = getFileList(in_dir_1);
ls_2 = getFileList(in_dir_2);

// Filter files to only include edge images
Folder1 = File.getName(in_dir_1);
Folder2 = File.getName(in_dir_2);
// Check for directory of sample dataset, make dir if none exists
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
if (File.isDirectory(dir1+"/Edge Measurements")==0){
	File.makeDirectory(dir1+"/Edge Measurements");
}
folderName = File.getNameWithoutExtension(in_dir_1) + " minus " + File.getNameWithoutExtension(in_dir_2) + "_" + year + "_" + month+1 + "_" + dayOfMonth + "_" + hour  + "_" + minute + "_" + second;
if (File.isDirectory(in_dir_1 + "/../Edge Measurements" + folderName) == 0) {
	print("Making directory for sample " + File.getName(in_dir_1));
	File.makeDirectory(in_dir_1 + "/../Edge Measurements/" + folderName);
	out_dir = in_dir_1 + "/../Edge Measurements/" + folderName;
	processed_dir = out_dir + "/Processed Images";
	//Create new directories necessary.
	File.makeDirectory(processed_dir);
	File.makeDirectory(processed_dir + "/8 bit clean");
	File.makeDirectory(processed_dir + "/8 bit dirty");
	File.makeDirectory(processed_dir + "/Registration");
	File.makeDirectory(processed_dir + "/Split");
	File.makeDirectory(processed_dir + "/Split/C1Fused"); 
	File.makeDirectory(processed_dir + "/Split/C2Fused"); 
	File.makeDirectory(processed_dir + "/Difference");
	File.makeDirectory(processed_dir + "/Crop");
	File.makeDirectory(processed_dir + "/Crop8bit");
	File.makeDirectory(processed_dir + "/Crop8BitThreshold");
	File.makeDirectory(processed_dir + "/Crop8BitThresholdMask");
	File.makeDirectory(processed_dir + "/Finished");
	File.makeDirectory(processed_dir + "/Errors");  // Directory for error logs
} else { // Sample directory exists, now set that as the output directory
	out_dir = in_dir_1 + "/ImageJ Processed/" + folderName;
	print("Output directory set successfully");
}

for(i=0; i<ls_1.length; i++) {
	showProgress(i+1,ls_1.length);

	//Get file names, save an ideal full file name
	file1 = File.getNameWithoutExtension(in_dir_1+ls_1[i]);
	file2 = File.getNameWithoutExtension(in_dir_2+ls_2[i]);
	fullFileName = file1 + "minus" + file2;
	
	// Open and process clean file
	if (File.exists(in_dir_1+ls_1[i])) {
		open(in_dir_1+ls_1[i]);
		run("8-bit");
		run("Set Scale...", "distance=240 known=50 unit=micron");
		saveAs(".jpg", processed_dir + "/8 bit clean/8bit" + file1);
		title1 = getTitle();
		
		// Open and process dirty file
		if (File.exists(in_dir_2+ls_2[i])) {
			open(in_dir_2+ls_2[i]);
			run("8-bit");
			run("Set Scale...", "distance=240 known=50 unit=micron");
			saveAs(".jpg", processed_dir + "/8 bit dirty/8bit" + file2);
			title2 = getTitle();
			
			// Perform registration
			run("Descriptor-based registration (2d/3d)", "first_image="+ title1 + " second_image=" + title2 + " brightness_of=[Advanced ...] approximate_size=[Advanced ...] type_of_detections=[Minima & Maxima] subpixel_localization=[3-dimensional quadratic fit] transformation_model=[Rigid (2d)] images_pre-alignemnt=[Approxmiately aligned] number_of_neighbors=3 redundancy=2 significance=3 allowed_error_for_ransac=6 choose_registration_channel_for_image_1=1 choose_registration_channel_for_image_2=1 create_overlayed add_point_rois interpolation=[Linear Interpolation] detection_sigma=3.9905 threshold=0.0537");
			
			// Check if registration was successful
			if (isOpen("Fused " + file1 + " & " + file2)) {
				run("Set Scale...", "distance=240 known=50 unit=micron");
				saveAs(".jpg", processed_dir + "/Registration/Registered" + fullFileName);
				
				// Continue with the rest of the processing
				run("Split Channels");
				if (isOpen("C1-Fused " + file1 + " & " + file2) && isOpen("C2-Fused " + file1 + " & " + file2)) {
					run("Set Scale...", "distance=240 known=50 unit=micron");
					selectWindow("C1-Fused " + file1 + " & " + file2);
					saveAs(".jpg", processed_dir + "/Split/C1Fused/C1-Fused " + file1 + " & " + file2);
					selectWindow("C2-Fused " + file1 + " & " + file2);
					saveAs(".jpg", processed_dir + "/Split/C2Fused/C2-Fused " + file1 + " & " + file2);
					imageCalculator("Difference create", "C1-Fused " + file1 + " & " + file2,"C2-Fused " + file1 + " & " + file2);
					
					if (isOpen("Result of C1-Fused " + file1 + " & " + file2)) {
						saveAs(".jpg", processed_dir + "/Difference/Difference" + fullFileName);
						
						// Get image dimensions
                        getDimensions(width, height, channels, slices, frames);
                        
                        // Calculate crop parameters for middle 50%
                        new_width = floor(width * 0.75);
                        new_x = floor(width * 0.125);
                        new_height = floor(height * 0.1);
                        new_y = floor(height * 0.5);
                        
                        // Crop the image
                        run("Specify...", "width=new_width height=new_height x=new_x y=new_y");
                        run("Crop");
						run("Set Scale...", "distance=240 known=50 unit=micron");
						saveAs(".jpg", processed_dir + "/Crop/Difference" + fullFileName);
						run("8-bit");
						saveAs(".jpg", processed_dir + "/Crop8bit/Difference" + fullFileName);
						setThreshold(95, 255);
						run("Threshold...");
						saveAs(".jpg", processed_dir + "/Crop8bitThreshold/Difference" + fullFileName);
						run("Convert to Mask");
						saveAs(".jpg", processed_dir + "/Crop8bitThresholdMask/Difference" + fullFileName);
						run("Set Measurements...", "area bounding redirect=None decimal=3");
						run("Analyze Particles...", "  show=Masks display exclude include summarize");
						saveAs(".jpg", processed_dir + "/Finished/" +  fullFileName);
					} else {
						print("Error: Failed to create difference image for " + fullFileName);
						File.append("Error: Failed to create difference image for " + fullFileName + "\n", processed_dir + "/Errors/error_log.txt");
					}
				} else {
					print("Error: Failed to split channels for " + fullFileName);
					File.append("Error: Failed to split channels for " + fullFileName + "\n", processed_dir + "/Errors/error_log.txt");
				}
			} else {
				print("Error: Registration failed for " + fullFileName);
				File.append("Error: Registration failed for " + fullFileName + "\n", processed_dir + "/Errors/error_log.txt");
			}
		} else {
			print("Error: Dirty file not found - " + in_dir_2+ls_2[i]);
			File.append("Error: Dirty file not found - " + in_dir_2+ls_2[i] + "\n", processed_dir + "/Errors/error_log.txt");
		}
	} else {
		print("Error: Clean file not found - " + in_dir_1+ls_1[i]);
		File.append("Error: Clean file not found - " + in_dir_1+ls_1[i] + "\n", processed_dir + "/Errors/error_log.txt");
	}
	
	run("Close All");
}

Table.save(out_dir+ "/Particles " + Folder1 + " minus " + Folder2 + ".csv", "Results");
Table.save(out_dir+ "/Summary " + Folder1 + " minus " + Folder2 + ".csv", "Summary");
close("Results");
close("Summary");