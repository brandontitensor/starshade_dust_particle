// Macro to add "0" before file extension in Bef_ii folders
run("Close All");

// User selects the parent directory containing Bef_ii folders
parent_dir = getDirectory("Choose the parent directory containing Bef_ii folders");

// Get list of all folders within the parent directory
folder_list = getFileList(parent_dir);

// Loop through folders to find Bef_ii folders
for (i = 0; i < folder_list.length; i++) {
    if (startsWith(folder_list[i], "Bef_")) {
        processFolder(parent_dir + folder_list[i]);
    }
}

function processFolder(folder_path) {
    // Get list of files in the folder
    file_list = getFileList(folder_path);
    
    // Loop through each file
    for (i = 0; i < file_list.length; i++) {
        old_name = file_list[i];
        
        // Check if the file has an extension
        dot_index = lastIndexOf(old_name, ".");
        if (dot_index != -1) {
            // Construct new name with "0" before the extension
            new_name = substring(old_name, 0, dot_index) + "0" + substring(old_name, dot_index);
            
            // Rename the file
            File.rename(folder_path + old_name, folder_path + new_name);
            print("Renamed: " + old_name + " to " + new_name);
        }
    }
    print("Processed folder: " + folder_path);
}

print("Renaming complete!");
