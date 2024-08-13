

//roiManager("measure");	//// Need to perform these two lines a decent bit before? Before the clear outside and the run("select none")
//cellArea = getResult("Area", 0); //// Also need to make sure results table is empty for line above

promi = 12;

do {
	// Clear ROI manager and results table
	run("Clear Results");
	run("Select None");
	roiManager("reset");
	
	// Perform spot detection and count maxima
	run("Find Maxima...", "prominence=" + promi);
	roiManager("Add");
	roiManager("select", 0);
	roiManager("measure");
	promi = promi + 1;
} while ((nResults/cellArea) > VALUE_WE_DECIDE);

roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	
close("MAX_template");
