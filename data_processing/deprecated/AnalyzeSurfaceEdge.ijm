//This macro is to use the ROI manager on a line through the middle along with a rectangle above. We'll get the data through ImageJ and then, with MatLab, analyze the area in order to get a direct comparison

//Get the directory from which our images for surface measurements will come from.
in = getDirectory("/Users/vawdrey/inSync Share/Optical Edge Contamination/ImageJ Processed/Surface Measurements");
//Here is where our masks are.
list = getFileList(in);
//Open image
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
surfaceEdgeName = "/../Surface Edge Images_" + month + "_"+ dayOfMonth + "_" + hour + "_" + minute;
File.makeDirectory(in+surfaceEdgeName);
File.makeDirectory(in+surfaceEdgeName +"/Near edge");
File.makeDirectory(in+surfaceEdgeName +"/Edge And Near Edge");

File.makeDirectory(in+surfaceEdgeName +"/Near edge 2");
File.makeDirectory(in+surfaceEdgeName +"/Edge And Near Edge 2");

for(i=1; i<list.length; i++)
{
	showProgress(i+1,list.length);
	open(in+list[i]);
	title = getTitle();
	if(indexOf(title,"Surface") >= 0) 
	{
	
	id0 = getImageID();
	run("8-bit");
	setThreshold(30,255);
	run("Specify...", "width=640 height=200 x=0 y=25");
	run("Analyze Particles...", "  show=Masks exclude include summarize");
	saveAs("jpg", in+surfaceEdgeName + "/Near edge/" + getTitle());
	id1 = getImageID();
	selectImage(id0);
	saveAs("jpg", in+surfaceEdgeName + "/Edge And Near Edge/" + getTitle());
	run("Specify...", "width=640 height=200 x=0 y=25");
	run("Analyze Particles...", "  show=Masks include summarize");
	id2 = getImageID();
	imageCalculator("Difference", id1, id2);
	idFin1=getImageID();
	selectImage(id0);
	run("Specify...", "width=640 height=400 x=0 y=25");
	run("Analyze Particles...", "  show=Masks exclude include summarize");
	saveAs("jpg", in+surfaceEdgeName + "/Near edge 2/" + getTitle());
	id3 = getImageID();
	selectImage(id0);
	saveAs("jpg", in+surfaceEdgeName + "/Edge And Near Edge 2/" + getTitle());
	run("Specify...", "width=640 height=400 x=0 y=25");
	run("Analyze Particles...", "  show=Masks include summarize");
	id4 = getImageID();
	imageCalculator("Difference", id3, id4);
	idFin2 = getImageID();
	imageCalculator("Subtract create", idFin1, idFin2);
	run("Analyze Particles...", " show=Masks display include summarize");
	saveAs("jpg", in + surfaceEdgeName + "/" + getTitle());
	run("Close All");
	}
}
Table.save(in+surfaceEdgeName+"/ParticlesOnEdge.csv","Results");
Table.save(in+surfaceEdgeName+"/Summary.csv","Summary");