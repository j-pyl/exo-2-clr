// Show detected peaks
// Used scripts in ms105 to for the very seed of this code.
// More or less just got the Table.getColumn from there.
// JEP 09/2024


// FIJI process folder template
#@ File (label = "Input directory (Images)", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ File (label = "CSV directory", style = "directory") csvdir
#@ String (label = "Image file suffix", value = ".nd2") suffix 
#@ String (label = "File prefix", value = "") prefix


// Choose how to run program
Dialog.create("Select Program Mode");
sp_setting = newArray("Show all peaks","Open Peaks individually");
Dialog.addRadioButtonGroup("    Select program mode: ", sp_setting, 1, 2, "Show all peaks");
opi_setting = newArray(" Visual"," Silent");
Dialog.addRadioButtonGroup("    Run mode (opi):", opi_setting, 1, 2, " Visual");
Dialog.addMessage(" Visual: see image before deciding to save films\n Silent: creates films for all peaks");
Dialog.show();
script_mode = Dialog.getRadioButton();
opi_mode = Dialog.getRadioButton();


if (script_mode=="Show all peaks") {
	print("Running show all peaks");
	processFolder(input, script_mode, opi_mode);
} else {
	print("Running open peaks individually");
	if (opi_mode==" Silent") {
		setBatchMode(true);
		processFolder(input, script_mode, opi_mode);
		setBatchMode(false);
	} else {
		processFolder(input, script_mode, opi_mode);
	}
}
waitForUser("Macro/processFolder done");


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input, script_mode, opi_mode) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i], script_mode, opi_mode, prefix);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i], csvdir, script_mode, opi_mode, prefix);
	}
}

function processFile(input, output, file, csvdir, script_mode, opi_mode, prefix) {
	print("Processing: " + input + File.separator + file);
	origfn = File.getNameWithoutExtension(file);
	csv_suffix = "_t_peak-xyt.csv";
	csvf_0t = prefix+origfn+"_recy-"+0+csv_suffix;
	csvf_1t = prefix+origfn+"_recy-"+1+csv_suffix;
	
	
	// Check if either csv exists and open relevant ones
	csvf_0t_exists = File.exists(csvdir+File.separator+csvf_0t);
	csvf_1t_exists = File.exists(csvdir+File.separator+csvf_1t);
		
	// Import csv data into array
	if (csvf_0t_exists==true) {
		open(csvdir+File.separator+csvf_0t);
		
		// 0t data
		selectWindow(csvf_0t);
		xcoords_0t = Table.getColumn("x_coord");
		ycoords_0t = Table.getColumn("y_coord");
		frm_no_0t = Table.getColumn("frame");
		spot_n_0t = Table.getColumn("spot_no");
		for (i=0; i<spot_n_0t.length; i++) {
			spot_n_0t[i] =  spot_n_0t[i] + "_0t";
		}
		run("Close");
	}
	if (csvf_1t_exists==true) {
		open(csvdir+File.separator+csvf_1t);
		
		// 1t data
		selectWindow(csvf_1t);
		xcoords_1t = Table.getColumn("x_coord");
		ycoords_1t = Table.getColumn("y_coord");
		frm_no_1t = Table.getColumn("frame");
		spot_n_1t = Table.getColumn("spot_no");
		for (i=0; i<spot_n_1t.length; i++) {
			spot_n_1t[i] =  spot_n_1t[i] + "_1t";
		}
		run("Close");
	}
	
	// Bring arrays together
	if ((csvf_0t_exists==true) && (csvf_1t_exists==true)) {
		xcoords = Array.concat(xcoords_0t, xcoords_1t);
		ycoords = Array.concat(ycoords_0t, ycoords_1t);
		frm_no = Array.concat(frm_no_0t, frm_no_1t);
		spot_n = Array.concat(spot_n_0t, spot_n_1t);
	} else if ((csvf_0t_exists==true) && (csvf_1t_exists==false)) {
		xcoords = xcoords_0t;
		ycoords = ycoords_0t;
		frm_no = frm_no_0t;
		spot_n = spot_n_0t;
	} else if ((csvf_0t_exists==false) && (csvf_1t_exists==true)) {
		xcoords = xcoords_1t;
		ycoords = ycoords_1t;
		frm_no = frm_no_1t;
		spot_n = spot_n_1t;
	} else { // In case neither file exists.
		print("In "+csvdir+"\nNeither file below exists.\n"+csvf_0t+"\n"+csvf_1t);
		return;
	}
	
	// Run selected script mode
	if (script_mode=="Open Peaks individually") open_peaks_indiv(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn, opi_mode);
	else show_all_peaks(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn);
	
	close("*");
}



//------------------------------------------------------------------------------------------------------------------------------------
// Show all detected peaks as ROIs
// Use: click on the ROI name in ROI manager and an ROI will be drawn around the peak and the frame will be set to the peak.
function show_all_peaks (input, output, file, xcoords, ycoords, frm_no, spot_n, origfn) {
	
	// Open image
	s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT";
	run("Bio-Formats Importer", s);
	
	// Make ROIs
	roiManager("reset");
	for (i=0; i<xcoords.length; i++) {
		makeOval(xcoords[i]-15, ycoords[i]-15,31,31);
		Roi.setPosition(1,1,frm_no[i]);
		roiManager("add");
		roiManager("select", i);
		roiManager("rename", spot_n[i]);
	}
	
	
	// Select ROIs to make films with
	Dialog.createNonBlocking("Save ROIs");
	Dialog.addMessage("Select which ROIs to save");
	dlab = newArray(xcoords.length); // Dialog label
	ddef = newArray(xcoords.length); // Dialog default
	for (i=0; i<xcoords.length; i++) {
		dlab[i] = spot_n[i];
		ddef[i] = false;
	}
	drow = Math.ceil(xcoords.length/5);
	Dialog.addCheckboxGroup(drow, 5, dlab, ddef);
	Dialog.show();
	
	// Make films with selected ROIs
	for (i = 0; i < xcoords.length; i++) {
		temp = Dialog.getCheckbox();
		if (temp == true) {
			
			// Create a new subdirectory with files to save
			save_img_dir = output+File.separator+origfn+"_show-peaks-out"; ////
			if (File.isDirectory(save_img_dir)==false) File.makeDirectory(save_img_dir);
			
			// Set up figure coordinates & dimensions
			fig_coords = fig_coord_setup(i, xcoords[i], ycoords[i], frm_no[i]);
			f_start = fig_coords[0];
			f_end = fig_coords[1];
			x_strt = fig_coords[2];
			y_strt = fig_coords[3];
			wl = fig_coords[4];
			hl = fig_coords[5];
			
			// Create & save image
			roiManager("deselect");
			makeRectangle(x_strt, y_strt, wl, hl); //// could simplify wih just fig_coords[x]
			run("Duplicate...", "title="+ spot_n[i] +" duplicate frames="+ f_start +"-"+ f_end);
			saveAs ("Tiff",  save_img_dir+File.separator+spot_n[i]+ ".tif"); ////
			
			close(spot_n[i]+".tif");
		}
	}
}


//------------------------------------------------------------------------------------------------------------------------------------
// Open each peak individually
function open_peaks_indiv(input, output, file, xcoords, ycoords, frm_no, spot_n, origfn, opi_mode) {

	// Open image
	s = "open=["+input+File.separator+file+"] autoscale color_mode=Composite crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT";
	run("Bio-Formats Importer", s);
	roiManager("reset");
	
	for (i=0; i<xcoords.length; i++) {
		// Set up figure coordinates & dimensions
		fig_coords = fig_coord_setup(i, xcoords[i], ycoords[i], frm_no[i]);
		f_start = fig_coords[0];
		f_end = fig_coords[1];
		x_strt = fig_coords[2];
		y_strt = fig_coords[3];
		wl = fig_coords[4];
		hl = fig_coords[5];
		
		// Create & save image
		roiManager("deselect");
		makeRectangle(x_strt, y_strt, wl, hl); //// could simplify wih just fig_coords[x]
		run("Duplicate...", "title="+ spot_n[i] +" duplicate frames="+ f_start +"-"+ f_end);
		run("Set... ", "zoom=2400");
		
		if (opi_mode==" Silent") {
			img_save = "Yes";
		} else {
			Dialog.createNonBlocking("Save film"); //// getBoolean is better because it is single click
			opi_setting2 = newArray("Yes","No");   //// but it is a 'modal' box (would prevent you from viewing frames)
			Dialog.addRadioButtonGroup("Save film", opi_setting2, 1, 2, "No");
			Dialog.setInsets(0,150,0);
			Dialog.addMessage(" ");
			Dialog.show();
			img_save = Dialog.getRadioButton();
		}
					
		//Save image
		if (img_save=="Yes") {
			save_img_dir = output+File.separator+origfn+"_show-peaks-out"; ////
			if (File.isDirectory(save_img_dir)==false) File.makeDirectory(save_img_dir);
			
			saveAs ("Tiff",  save_img_dir+File.separator+spot_n[i]+ ".tif"); ////
			close(spot_n[i]+".tif");
		} else {
			close(spot_n[i]);
		}
	}
}


//------------------------------------------------------------------------------------------------------------------------------------
// Set up for cropped figure size and coordinates
function fig_coord_setup (indx, x, y, frm) {
	Stack.getDimensions(img_width, img_height, img_channels, img_slices, img_frames);
	
	// Image dimensions
	len_w = 37;
	len_h = 37;
	if (!(len_w%2 && len_h%2)) exit("Image dimensions are not odd numbers.\n \nlen_w AND len_h in fig_coord_setup need to be odd numbers.");
	hlen_w = floor(len_w/2);
	hlen_h = floor(len_h/2);
	
	// Modify peak coordinates if the resultant ROI is 'out of bounds'
	if (frm < 11) frm = 11;
	if (frm > (img_frames - 15)) frm = img_frames - 15;

	x = parseInt(x);
	if (x < (hlen_w + 1)) x = hlen_w + 1;
	if (x > (img_width - hlen_w )) x = img_width - hlen_w;

	y = parseInt(y);
	if (y < (hlen_h + 1)) y = hlen_h + 1;
	if (y > (img_height - hlen_h)) y = img_height - hlen_h;
	
	
	frm_start = frm-10;
	frm_end = frm+15;
	
	// Define top-left corner of ROI box
	x_start = x - ((len_w -1)/2);
	y_start = y - ((len_h -1)/2);
	
	// Return figure coordinates & dimensions
	return newArray(frm_start, frm_end, x_start, y_start, len_w, len_h);
}
