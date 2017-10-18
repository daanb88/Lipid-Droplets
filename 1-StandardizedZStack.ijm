//Macro to get equivalent-sized Z-projections
//for LD analysis
//v0.2 28/11/16 Daan van den Brink
//Requires a 2-Channel image.
//Do A Guassian Blur 3D
//Check channels: Green will be standardized, Red will be autocontrasted:

//Green channel must be on 1, user will be asked.
greenChannel = 1;
redChannel = 2; 
swapChannels = NaN;

fileNameStart = "";
fileExtension1 = "tif";
fileExtension2 = "czi";
exportLocation = newArray(true, "LD_Quant", "Export");	//Make a new export dir?, what's it's name?, name for JPG folder.

getDateAndTime(year, month, bin, day, hour, minute, second, msec);
//print("\\Clear");
print("\n" + hour + ":" + minute + "." + second);
//path = File.openDialog("Select a File");
importPath = getDirectory("Select an input-directory");

//Make a new directory if the flag in exportLocation[0] is set to true.
if (exportLocation[0] == true) {	//Make a dir or 
		exportPath = importPath + timeStamp() + "_" + exportLocation[1] + "/";
		exportPathJPG = exportPath + exportLocation[2] + "/";
		print("Making dirs:\n\t" + exportPath + " \n\t" + exportPathJPG);
		File.makeDirectory(exportPath);	//For files to be analysed.
		File.makeDirectory(exportPathJPG);	//For jpg's
	} else { exportPath = getDirectory("Please choose the Export Directory");	}
//exportPath = "/Volumes/DATA/Users/dvandenb/Documents/Imaging/160405 p22 54C Fatp Bodipy/Analysis/";

//run the macro:
processFolder(importPath);
//Clear memory
print("Free memory is: " +  IJ.freeMemory() + "; Clearing memory...");
for (i = 0; i < 4; i++) {
	call("java.lang.System.gc"); 
}
IJ.freeMemory()
print("Macro ended");

function processFolder(input) {
	list = getFileList(input);
	if (list.length == 0 ) { exit("No files in folder " + input) };
	skipList = newArray(0); //print (list.length);
	for (i = 0; i < list.length; i++) {
		//check if current file is one of two extensions and 
		//starts with a string (to process part of a folder).
		if ( (endsWith(list[i], fileExtension1) || endsWith(list[i], fileExtension2) ) && startsWith(list[i], fileNameStart) ) {
			setBatchMode(true);
			print("Opening: " + importPath + list[i]);
			run("Bio-Formats Windowless Importer", "open=["+ importPath + list[i] + "]");
			currentFile = getTitle();
			print("Opened: " + currentFile);
			//Need to check for multiple z, otherwise crash!
			getDimensions(bin,bin,channels,slices,bin);
			if (channels < 2  || slices < 2) { //skip, else process image
			 //when the file is not to be processed, put in on a list for troubleshooting
				print("Skipped because not enough channels of not a z-stack: " + list[i]);
				skipList = Array.concat(skipList, list[i]); 
			} else {
				run("Duplicate...", "duplicate");
				close("\\Others");	//close original and set colours
				run("Gaussian Blur 3D...", "x=1 y=1 z=1");
				rename(currentFile + "_GB3Dsigma1");
				print("Applied filter: Guassian Blur 3D (sigma xyz = 1) to " + currentFile);
				//Checking 1st file for order of channels
				Stack.setChannel(greenChannel);
				run("Green");
				run("Enhance Contrast", "saturated=0.35");
				Stack.setDisplayMode("color");
				setBatchMode("show");		
				if (isNaN(swapChannels)) {	
					swapChannels =getBoolean("Are the dots in this channel?");
					print("User to macro to swap channels? " + swapChannels);			
				}
				if (swapChannels == false) { 
					print("Swapped channels");
					Stack.swap(1,2); 
					Stack.setChannel(greenChannel);
					run("Green");
				}
				Stack.setChannel(redChannel)
				resetMinAndMax();
				run("Enhance Contrast", "saturated=0.35");
				run("Red");
				Stack.setDisplayMode("composite");
				
				Zstacker();
			}
		} else { //when the file is not to be processed, put in on a list for troubleshooting
			//print("Skipped " + list[i]);
			skipList = Array.concat(skipList, list[i]); 
		}
	}
	//feedback files that have been skipped.
	if (skipList.length > 0) {
		print(skipList.length + " out of " + list.length + " files didn't match the criteria: (Starts with: " + fileNameStart + "; Extension: " + fileExtension1 + " or " + fileExtension2 + ")" );
		Array.print(skipList);
	}
}

function Zstacker() {
	//Zstackmacro slimmed down
	//if slices-subset is selected, put the begin- and end-slice in title?
	setBatchMode("show");
	waitForUser("Determine the Z-range\n(default: select first z-slice for range)");
	appendString = "";
	flagRange = true;
	appendZrange = true;
	defaultRange = 5; //um
	
	imageName = getTitle();
	getDimensions(w,h,c,slices,f);
	getVoxelSize(voxelX, voxelY, voxelZ, voxelUnit);
	Stack.getPosition(current_channel, current_slice, current_frame);
	//Sets the range
	startSlice = current_slice;
	proposedRange = round(defaultRange/voxelZ);
	if ( (startSlice + proposedRange) < slices ) { 
		stopSlice = startSlice + proposedRange; 
	} else {
		stopSlice = slices;
		startSlice = stopSlice - proposedRange;
		if (startSlice < 1) {
			startSlice = 1;
			waitForUser("Mind you! Not enough slices for " + proposedRange); 
		}
	}

	Dialog.create("Z-stacker");
	Dialog.addNumber("Start slice: ", startSlice);
	Dialog.addNumber("Stop slice: ", stopSlice);
	Dialog.addCheckbox("Append range (in " + voxelUnit + ")", flagRange);
	Dialog.addMessage("Selected range: " + d2s((1+stopSlice-startSlice)*voxelZ,2) + " " + voxelUnit +"; \n(Z is: " + d2s(voxelZ,3) + " " + voxelUnit + "; \nTotal Z is: " + d2s(voxelZ*stopSlice,3) + "\nZ Slices per " + voxelUnit + ": " + d2s(1/voxelZ,3) +")");
	Dialog.addMessage("5um is: " + d2s(5/voxelZ,3) + " slices");
	Dialog.show()
	checkRange	= Dialog.getCheckbox;
	startSlice	= Dialog.getNumber();
	stopSlice	= Dialog.getNumber();
	setBatchMode("hide");
	//print("Range: ",checkRange,"; Av: ",checkAv,"; Max ",checkMax, "; StDev ",checkStDev,"; Med ",checkMed," ; Sum ",checkSum);	//print("Range: ", startSlice, " to ", stopSlice, "out of total ", slices);
	
	//Check if the Z-range is about right.
	selectWindow(imageName);
	if (0 >= startSlice || startSlice > stopSlice) {
		print("Selected range: ", startSlice, " to ", stopSlice, "out of ", slices, " stacks.");
		exit("Start slice is incorrect.");
	} else if (stopSlice > slices) {
		print("Selected range: ", startSlice, " to ", stopSlice, "out of ", slices, " stacks.");
		exit("Slices out of bounds.");
	}
	
	//for adding some info about Z on file name			
	if (startSlice > 1 || stopSlice < slices) {		//if a subset of stacks is selected
		//print("\"_z\"+startSlice+\"-\"+stopSlice");
		if (appendZrange == true) {
			appendString = ""+startSlice+"-"+stopSlice;
		}
	}
	if (checkRange == 1 && voxelUnit == "microns") {	//"microns" to test for calibrated image
		appendString = appendString + "_" + ( d2s((1+stopSlice-startSlice)*voxelZ,2) ) + voxelUnit;
	}
	if (appendString != "") {
		appendString = "-Z" + appendString;		//if anything is appended, write a Z- before it. 
	}
	
	//Do the selected projections
	listIDs= newArray();	//contains the IDs for the Z-projection windows
	wSize = 640;			//defines the size of the new windows
	windowPosition = newArray(0,100);		//defines where the window goes
	setBatchMode(false);
	if (1 == 0) {		//Always make a MAX projection, or not
		selectWindow(imageName);
		run("Z Project...", "start="+startSlice+" stop="+stopSlice+" projection=[Max Intensity]");
		rename(imageName+"_MAX"+appendString);
		listIDs = Array.concat( listIDs, getImageID() );
		windowPosition[0] = listIDs.length-1;
		//print("\nDoing Max");
		//print("listIDs.length is: " + listIDs.length + " containing: ");
		//Array.print(listIDs);
		//Array.print(windowPosition);
		//print("MaxLocation is: " + (100+0*windowPosition[0]+wSize*windowPosition[0]) );
		//waitForUser("check arrays");
		setLocation( (100+0*windowPosition[0]+wSize*windowPosition[0]), windowPosition[1], wSize, wSize);
		Stack.setChannel(greenChannel);
		setMinAndMax( 0,pow(2,bitDepth()) );
		Stack.setChannel(redChannel)
		run("Enhance Contrast", "saturated=0.35");
	}
	if (1 == 1) {		//Always make a SUM projection
		selectWindow(imageName);
		run("Z Project...", "start="+startSlice+" stop="+stopSlice+" projection=[Sum Slices]");
		rename(imageName+"_SUM"+appendString);
		listIDs = Array.concat( listIDs, getImageID() );
		windowPosition[0] = listIDs.length-1;
		//print("\nDoing Max");
		//print("listIDs.length is: " + listIDs.length + " containing: ");
		//Array.print(listIDs);
		//Array.print(windowPosition);
		//print("MaxLocation is: " + (100+0*windowPosition[0]+wSize*windowPosition[0]) );
		//waitForUser("check arrays");
		setLocation( (100+0*windowPosition[0]+wSize*windowPosition[0]), windowPosition[1], wSize, wSize);
		Stack.setChannel(greenChannel);
		setMinAndMax( 0,pow(2,bitDepth()) );
		Stack.setChannel(redChannel)
		run("Enhance Contrast", "saturated=0.35");
	}
	//print out info on Z-projection
	print("Original image: " + imageName);
	print("Made projections of range: " + startSlice + "-" + stopSlice + " (" + ( (1+stopSlice-startSlice)*voxelZ ) + " " + voxelUnit + ")");
	print("created the following windows:");
	
	//put Z-projections on foreground
	close(imageName);
	//Array.print(listIDs);
	zProjectString = "";
	zProjectArray = newArray();
	for (i=0; i<listIDs.length;i++) {
		//print(listIDs[i]);
		selectImage(listIDs[i]); 
		print(getTitle());
		//generate string with filenames
		zProjectString = zProjectString + "\n" + getTitle();
		zProjectArray = Array.concat(zProjectArray,getTitle() );
	}
	
	Dialog.create("Saving result");
	Dialog.addMessage("Do you want to save:" + zProjectString + "\nin:\n " + exportPath );
	Dialog.addChoice("Save?", newArray("Yes","No"), "Yes")
	Dialog.show();
	choise = Dialog.getChoice();
	for (i=0; i<zProjectArray.length;i++) {
		if (choise == "Yes") {
			//Set the brightness to standard (0 to max)
			//If you don't see any green, use the BIOP plugin to standardize B/C.
			Stack.setChannel(greenChannel);
			setMinAndMax( 0,pow(2,bitDepth()) );
			print("Saving " + zProjectArray[i]);
			saveAs("Tiff", exportPath + zProjectArray[i] + ".tif");
			saveAs("Jpeg", exportPathJPG + zProjectArray[i] + ".jpg");
		} else {
			print("Not saving " + zProjectArray[i]);
		}
	} 
	close();
}

function timeStamp() {
	yearString = toString( substring(year,2) );
	if (month<9) { monthString = "0" + toString( (1 + month) ); } else { monthString = toString(1 + month); }
	if (day<10)	 { dayString = "0" + toString(day); } else { dayString = toString(day); }
	return ( yearString + monthString + dayString );
}

