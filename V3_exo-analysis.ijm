// Adaptation of ms105 FIJI script 1
// JEP 07/2024

// V3 - analyse for exocytic events
// Code currently copied over from V2-8_cleaned

// need to insert define global variables and other stuff here.
// maybe do line 9 instead of line 10?
// #@ String (label = "File suffix", value = "_cell.roi") suffix
// #@ String (label = "File suffix", value = ".tif") suffix
// No, this does not work! Need file to be opened & be the original file.

// For V4, add this:
//#@ Boolean (label = "2-channel analysis", value = true) twoclr


function processFile(input, output, file) {
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	
	//// Skip if file exists because it will be run in def-cell-ROI and this will depend on its results?
	if (File.exists(output + "/" + origfn + "_cell.roi") == false) {
		return;
	}
	if (File.exists(output + "/" + origfn + "_IntensityData.csv") == false) {
		return;
	}
	
	open(input+File.separator+file);
	origft = getTitle(file);							//// is this redundant with origfn?
	run("Clear Results");
	roiManager("reset");


	for (i = 0; i < 2; i++) {
		recycle = i
		if (recycle == 0) { // Detect ROIs on channel 1, analyse these in channel 1&2
			// Make named duplicates
			run("Duplicate...", "title=template duplicate channels=1");
			run("Duplicate...", "title=subject duplicate channels=2");
			
			// Detect puncta on template
			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			
		} else if (recycle == 1) { // Detect ROIs on channel 2, analyse these in channel 1&2
			selectImage(origft); // is redundant with below (code at end of for loop), but performed as backup.
			run("Duplicate...", "title=template duplicate channels=2");
			run("Duplicate...", "title=subject duplicate channels=1");

			template_spot_detection(output, origfn, recycle);
			
			exo_analysis_general(output, "template", origfn, recycle);
			exo_analysis_general(output, "subject", origfn, recycle);
			// I know this code is doubled and not 'pretty'/conventional, but this is the way I can integrate recycle number into the sequence
			
		} else {
			print("Too many recycles! Recycles >= 1");
			return;
		}
		
		// Close all images except original: set up for next recycle.
		selectImage(origft);	////If I delete origft above, replace with selectImage(file);. origfn WILL NOT work.
		close("\\Others");
	}
	run("Close All");
}



//------------------------------------------------------------------------------------------------------------------------------------
// THIS FUNCTION WORKS. DO NOT MODIFY FOR THE MOMENT.
function template_spot_detection (output, fn, recycle) {
	selectImage("template");
	roiManager("reset");
	
	run("Z Project...", "projection=[Max Intensity]");
	run("Enhance Contrast", "saturated=0.35");

	// Load cell outline ROI
	roiManager("open", output + "/" + fn + "_cell.roi");
	roiManager("select", 0);
	
	// Clear all but selection
	run("Clear Results");
	run("Clear Outside");
	run("Select None");
	roiManager("reset");	// Remove cell outline ROI
	
	// Find puncta and save results
	run("Find Maxima..."); 		//// Need to define prominence!
	roiManager("Add");
	roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	
	run("Close"); 	//// First run closes ROI manager?
	run("Close");	//// Second run closes MAX_* image?
//	Replace two lines above with single line below? Don't especially need to close ROI manager.
//	close("MAX_template");
}

//------------------------------------------------------------------------------------------------------------------------------------
// This function runs without error. No need to change
function exo_analysis_general (output, base, fn, recycle) { //// base = base file name (input template or subject when calling this function).
	selectImage(base);										
	getDimensions(width, height, channels, slices, frames);
	if (base == "template") {
		imageName = fn + "_recy-" + recycle + "_t"
	} else if (base == "subject") {							//// this bit might be wrong. i.e. Assigning these values to imageName
		imageName = fn + "_recy-" + recycle + "_s"
	}
	
	
	selectImage(base);
	roiManager("Select", 0);

	// get array of x and y coords
	getSelectionCoordinates(xCoords, yCoords);

	run("Select None");
	f = File.open(output + "/" + imageName+ "_IntensityData.csv");			////		////Need to update imageName?
	str = "";
	for (i = 0; i < xCoords.length; i++) {
		str = str + "spot_" + i + ",";
	}
	str = str + "frame\n";
	print(f, str);


	for (i = 0; i < frames; i++) {
		Stack.setFrame(i+1);
		str = "";
		for (j = 0; j < xCoords.length; j++) {
			makeOval(xCoords[j] - 2, yCoords[j] - 2, 4, 4);
			getStatistics(area, mean, min, max, std, histogram);
			str = str + mean + ",";
		}
		str = str + i + "\n";
		print(f, str);
	}
	File.close(f);

	//Get coordinates of all points 
	f = File.open(output + "/" + imageName+ "_CoordData.csv");				////		////Need to update imageName?
	str = "";
	x = ""; 
	y= "";
	for (i = 0; i < xCoords.length; i++) {
		str = str + "spot_" + i + ",";
		x = x + xCoords[i]+ ","; 
		y = y + yCoords[i] + ",";
	}
	str = str + "\n";
	x = x + "\n";
	y = y + "\n";
	print(f, str);
	print(f, x);
	print(f, y);
	File.close(f);

	//Get informations 
	getPixelSize(unit, pixelWidth, pixelHeight);
	print("SCALE" + unit + "," +pixelWidth+ "," +pixelHeight);
	frameInterval=Stack.getFrameInterval();
	frameInterval = "interval (in s)"+","+ frameInterval + "\n" ; 
	Totspot = xCoords.length; 
	Totspot = "Totspot" +","+ Totspot+ "\n" ; 
	Area = "area (in unit)" +","+ Area+ "\n";
	scaleunit =  "ScaleUnit" +","+ unit + "\n";
	pixelScale =  "pixelScale" +","+ pixelWidth + "\n";
	head = "Info, Value\n";
	
	f = File.open(output + "/" + imageName+ "_CellInfo.csv");				////		////Need to update imageName?
	print (f, head);
	print(f, Area); 
	print(f, frameInterval); 
	print(f, Totspot); 
	print (f, scaleunit);
	print (f, pixelScale);
	File.close(f);
	// when running this section alone, a log window is open at the end. Maybe add the two following lines?
//	selectWindow("Log");
//	run("Close");
}
//------------------------------------------------------------------------------------------------------------------------------------