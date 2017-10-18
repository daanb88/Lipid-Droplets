/*
 * Macro to return Date and Time in 'Nice' format (yymmdd_hhmm)
 * Returns Date&Time 	if input == 0 or empty
 * Returns Date			if input == 1
 * Returns Time			if input == 2
 * v0.1 11/10 2017
 * Based on http://imagej.net/macros/GetDateAndTime.txt
 */

inputArguments = getArgument();
//print("In ReturnDateTime macro, with argument: '" + inputArguments + "'");

getDateAndTime(year, month, bin, day, hour, minute, second, msec);
if (month<10)	{month = "0" + toString(month);}
if (day<10) 	{day = "0" + toString(day);}
DateString = substring(year,2) + toString(month) + toString(day);
if (hour<10) 	{hour = "0" + toString(hour);}
if (minute<10) 	{minute = "0" + toString(minute);}
TimeString = toString(hour) + "h" + toString(minute);

if (inputArguments == 1) 		{ return toString(DateString) };
else if (inputArguments == 2) 	{ return toString(TimeString) };
else 							{ return DateString + "-" + TimeString };