//CheckImageDimensions macro
//v0.1 08/12/2016 Daan van den Brink
//Disable Batchmode!

//Takes exactly 6 arguments (targetID, minimumWidth, minimumHeight, minimumChannels, minimumSlices, minimumFrames)
//Checks the image (target ImageID) to determine if it meets the minimum specified:
//	minimumWidth,
//	minimumHeight,
//	minimumChannels,
//	minimumSlices,
//	minimumFrames.

//print("In CheckImageDimensions");
inputArguments = getArgument();
args = split(inputArguments, " ,");
if (args.length != 6) {
	exit("CheckImageDimensions macro takes a string containing 6 arguments seperated by  a space or comma:\ntargetID, minimumWidth, minimumHeight, minimumChannels, minimumSlices, minimumFrames");
} else {
	//print ("args are: " + inputArguments);
	return toString( imageDimensionChecker( args[0],  args[1],args[2],args[3],args[4],args[5] ) );
}
exit;

function imageDimensionChecker(targetID, minimumWidth, minimumHeight, minimumChannels, minimumSlices, minimumFrames) {
//Checks the image (target ImageID) to determine if it has a valid width, number of Channels, etc.
//This order: (targetID, minimumWidth, minimumHeight, minimumChannels, minimumSlices, minimumFrames)
//If minimumCriterium == 0, it is ignored.
	selectImage(parseInt(targetID));
	getDimensions(width, height, channels, slices, frames);
	
	if		(width < minimumWidth && minimumWidth !=0 )				{	return false;	}
	else if (height < minimumHeight && minimumHeight !=0 ) 			{	return false;	}
	else if (channels < minimumChannels && minimumChannels !=0 ) 	{	return false;	}
	else if (slices < minimumSlices && minimumSlices !=0 )	 		{	return false;	}
	else if (frames < minimumFrames && minimumFrames !=0 ) 			{	return false;	}
	else	{
	print(">Image passed the CheckImageDimensions macro");
	return true;	
	}
}