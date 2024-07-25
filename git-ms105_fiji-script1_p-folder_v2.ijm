// MS105 Fiji Script 1
// Modified for batch by JEP 07/2024
// Replaced code with ms105_fiji-script1_p-folder_v2-6-section.ijm

function processFile(input, output, file) {
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	
	if (File.Exists(output + File.separator + origfn + "-" + 1 + "_IntensityData.csv")) {		// Skips original/parent file if it has already been analysed
		print(origfn + "-" + 1 + "_IntensityData.csv already exists. Image skipped.");
		return ("1");		
	}

	open(input+File.separator+file);
	origft = getTitle(file);							//// is this redundant with origfn?
	run("Clear Results");
	roiManager("reset");

	// Draw ROI around cell and save it	
	cellROI(output, origfn);		// output file name = origfn + "_cell.roi
	
	
	for (i = 0; i < 2; i++) {
		recycle = i
		if (recycle == 0) {							//// is this the right place to do this? I might need to change this. This maybe isn't even the right way to do it.
			run("Duplicate...", "title=template duplicate channels=1");				//// can I do this? template = run(... ?
			run("Duplicate...", "title=subject duplicate channels=2");
		} else if (recycle == 1) {
			run("Duplicate...", "title=template duplicate channels=2");
			run("Duplicate...", "title=subject duplicate channels=1");
		} else {
			print("Too many recycles! Recycles >= 1");
			return("1");
		}
		
		// Code & functions here.
		template_spot_detection(output, template, origfn, recycle);
		
		exo_analysis_general(output, template, origfn, recycle);			//// Steve comment: no need for 'template' or 'subject' as they aren't variables to use
		exo_analysis_general(output, subject, origfn, recycle);			//// JP: need to figure out a way to run twice with template and then subject
//		//// Maybe run like this?
//		exo_analysis_general(output, "template", origfn, recycle);
//		exo_analysis_general(output, "subject", origfn, recycle);

		selectImage(orig);
		close("\\Others");

	}
	run("Close All");															//// Is this in the right place?
}





//------------------------------------------------------------------------------------------------------------------------------------
// Save ROI of shape drawn around cell. This most probably can get shortened a decent bit.
function cellROI(output, fn) {
	selectImage("template");
	run("Z Project...", "projection=[Max Intensity]");		//// Need to make sure that the correct image is selected at this point.
	run("Enhance Contrast", "saturated=0.35");

	// Draw around the cell and save that ROI
	waitForUser("Draw around the cell", "Draw around the cell");
	roiManager("add");
	roiManager("Save", output + "/" + fn + "_cell.roi");
	
	// A bunch of junk that can be removed? Probably need to keep 'select none' and a final 'close' to close the Z profile result window.
	run("Set Measurements...", "area redirect=None decimal=3");
	run("Measure");
	Area = getResult("Area", 0);
	run("Close" );
	print("area="+Area);
	run("Clear Results");
	run("Clear Outside");
	run("Select None");
	run("Close");
	run("Close");
}

//------------------------------------------------------------------------------------------------------------------------------------
function template_spot_detection (output, template, fn, recycle) {
	selectImage("template");				//// don't need variable template just above. image = string 'template'
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
	roiManager("reset");	// Remove cell outline ROI				//// from speaking with Steve: added this line ////
	
	// Find puncta and save results
	run("Find Maxima..."); 
	roiManager("Add");
	roiManager("Save", output + "/" + fn + "_recy-" + recycle + ".roi");					////
	
	run("Close");				//// Hopefully this closes the new window (Z projection window)
}

//------------------------------------------------------------------------------------------------------------------------------------
function exo_analysis_general (output, base, fn, recycle) { //// base = base file name (input template or subject when calling this function).
	selectImage(base);										//// base = deprecated
	getDimensions(width, height, channels, slices, frames);
	if (base == "template") {
		imageName = fn + "_t" + "_recy-" + recycle
	}
	else if (base == "subject") {							//// this bit might be wrong. i.e. Assigning these values to imageName
		imageName = fn + "_s" + "_recy-" + recycle
	}
	
	
	
	selectImage(______);
	roiManager("Select", 0);

	// get array of x and y coords
	getSelectionCoordinates(xCoords, yCoords);

	run("Select None");
	f = File.open(output + "/" + imageName+ "_IntensityData.csv");			////		////Need to update imageName
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
	f = File.open(output + "/" + imageName+ "_CoordData.csv");				////		////Need to update imageName
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
	
	f = File.open(output + "/" + imageName+ "_CellInfo.csv");				////		////Need to update imageName
	print (f, head);
	print(f, Area); 
	print(f, frameInterval); 
	print(f, Totspot); 
	print (f, scaleunit);
	print (f, pixelScale);
	File.close(f);
	
}

//------------------------------------------------------------------------------------------------------------------------------------





// Add Stack.getDimensions(width, height, channels, slices, frames); into exoanalysis function
// imageName needs to be revised/adapted
	
	
	
	
// if recycle == 0
// template = name-1
// subject = name-2
// if recycle == 1
// template = name-2
// subject = name-1






// In function processFile:
//		recycle = 0
//		if (recycle == 0) {							//// is this the right place to do this? I might need to change this. This maybe isn't even the right way to do it.
//			template = run("Duplicate...", "duplicate channels=1");				//// can I do this? template = run(... ?
//			subject = run("Duplicate...", "duplicate channels=2");
//		}
//		else if (recycle == 1) {
//			template = run("Duplicate...", "duplicate channels=2");
//			subject = run("Duplicate...", "duplicate channels=1");
//		}
//		else {
//			print("Too many recycles! Recycles >= 1");
//		}


//function cellROIold(output, fn) {
//	//Do zstack, select the cell and find maxima - add to ROI --------------------------------
//	run("Z Project...", "projection=[Max Intensity]");
//	run("Enhance Contrast", "saturated=0.35");
//
//	waitForUser("Draw around the cell", "Draw around the cell");
//	run("Set Measurements...", "area redirect=None decimal=3");
//	run("Measure");
//	Area = getResult("Area", 0);
//	run("Close" );
//	print("area="+Area);
//	run("Clear Results");
//	run("Clear Outside");
//	run("Select None");
//
//	run("Find Maxima..."); 
//	roiManager("Add");
//		
//	roiManager("Save", output + "/" + fn + "_cell.roi");					//// NOTE: imageName is not defined here
//	//----------------------------------------------------------------------------------------
//}