#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <all ip procedures>
Menu "acq4"
	"Import an acq4", loadAcq4Image()
	"Import acq4 encoder", loadACQ4EncoderData()
end

function/S acq4LoadIndex()
	variable indexRef
	pathinfo acq4Path	
	if(v_flag == 0)
		newPath/q acq4path
		open/r /P=acq4Path indexRef as ".index"
	else
		open/r /P=acq4Path indexRef as ".index"
	endif
	
	variable pixelWidth
	String buffer
	string/g indexFile = ""
	variable lineNumber = 0, len
	do
		FReadLine indexRef, buffer
		len = strlen(buffer)
		if (len == 0)
			break						// No more lines to be read
		endif
		indexFile += buffer
	while (1)
	killpath acq4path
	string/g acq4VariablesKeys = makeAcq4VariableList(indexFile)
	return acq4VariablesKeys
end

function/s makeAcq4VariableList(indexFile)
	string indexFile
	
	string acq4VariablesList = ""
	
	variable v1
	
	v1 = acq4VariablesFromIndex(indexFile, "pixel size")
	if(v1 > 0)
		acq4VariablesList += "pixelSize="+num2str(v1)+";"
	endif
	
	v1 = acq4VariablesFromIndex(indexFile, "Frame Time")
	if(v1 > 0)
		acq4VariablesList += "frameTime="+num2str(v1)+";"
	endif
	
	v1 = acq4VariablesFromIndex(indexFile, "pixelWidth")
	if(v1 > 0)
		acq4VariablesList += "pixelWidth="+num2str(v1)+";"
	endif	
	
	v1 = acq4VariablesFromIndex(indexFile, "pixelHeight")
	if(v1 > 0)
		acq4VariablesList += "pixelHeight="+num2str(v1)+";"
	endif
	
	v1 = acq4VariablesFromIndex(indexFile, "totalDuration")
	if(v1 > 0)
		acq4VariablesList += "totalDuration="+num2str(v1)+";"
	endif
	
	v1 = acq4VariablesFromIndex(indexFile, "frameDuration")
	if(v1 > 0)
		acq4VariablesList += "frameDuration="+num2str(v1)+";"
	endif
	
	
	wave zStackValues = acq4GetZinfo(indexFile)
	acq4VariablesList += "zOffset="+num2str(zStackValues[0])+";"
	if(numpnts(zStackValues) > 1)
		acq4VariablesList += "zResolution="+(num2str(zStackValues[1] - zStackValues[0])) +";"
	endif
	
	wave acq4Positions = getacq4Positons(indexFile)
	acq4VariablesList += "xOffset="+num2str(acq4Positions[0])+";"
	acq4VariablesList += "yOffset="+num2str(acq4Positions[1])+";"
	
	return acq4VariablesList
end

function/Wave getacq4Positons(indexFile)
	string indexFile
	
	variable zoffset, xOffset, yOffset, varPosition
	string varBuffer
	
	//first check if Michael fixed the position variables///////////////////////////////////////////////////////////////////////////////////
	varPosition = strsearch(indexFile, "Transform", 0, 2)
	varBuffer = indexFile[varPosition, (varPosition+1000)]
	varPosition = strsearch(varBuffer, "pos", 0, 2)
	varBuffer = varBuffer[varPosition, (varPosition+1000)]
	varBuffer = replaceString("'", varBuffer, "")	//remove '
	varBuffer = replaceString("(", varBuffer, "")	//remove (
	varBuffer = replaceString(")", varBuffer, "")	//remove )
	varBuffer = replaceString(":", varBuffer, "")	//remove :
	varBuffer = replaceString(",", varBuffer, "")	//remove ,
//	print varBuffer
	sscanf varBuffer, "%*s%f%f%f%*[^\t\n]", xOffset, yOffset, zOffset
//	print zOffset
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	make/n=3/o/free acq4Pos = {xOffset, yOffset, zOffset}
	return acq4Pos
end

function/wave acq4GetZinfo(indexFile)
	string indexFile
	variable varPosition, zoffset
	string varBuffer


	varPosition = strsearch(indexFile, "zStackValues", 0, 2)
	variable varStop = strsearch(indexFile, "timelapse", 0, 2)
	varBuffer = indexFile[varPosition,varStop]
	varBuffer = replaceString("zStackValues", varBuffer, "")	//remove text
	varBuffer = replaceString(":", varBuffer, "")	//remove :
	varBuffer = replaceString("[", varBuffer, "")	//remove [
	varBuffer = replaceString(",", varBuffer, ";")	//remove ,
//	print varBuffer
	if(itemsinlist(varbuffer) > 2)
		make/o/n=0 zStackValues
		variable i
		for(i=0; i< itemsInList(varbuffer); i+= 1)
			insertpoints (i), 1, zStackValues
			zStackValues[i] = str2num(stringfromlist(i, varBuffer))
		endfor
	else
		make/o/n=1 zStackValues = getacq4Positons(indexFile)[2]
	endif
	//Double differentiate the zStackValues to see if stepping was incremental
	differentiate zstackValues /d=testResolution
	differentiate testResolution
	if(wavemax(testResolution) - waveMin(testResolution) > 1e-7)
		print "***** possible problem with Z Stack stepping  *****"
	endif
	killwaves testResolution
	
	return zstackValues
	
end

function acq4VariablesFromIndex(indexFile, imageVariable)
	string indexFile, imageVariable
	
	variable varPosition = strsearch(indexFile, imageVariable, 0, 2)
	if(varPosition > 0)
		imageVariable =  replaceString(" ", imageVariable, "")	//remove space
		
		string varBuffer = indexFile[varPosition, (varPosition+50)]
		varBuffer = replaceString("'", varBuffer, "")	//remove '
		varBuffer = replaceString(" ", varBuffer, "")	//remove space
		varBuffer = replaceString(",", varBuffer, "")	//remove ,
		varBuffer = replaceString("(", varBuffer, "")	//remove (
		varBuffer = replaceString(")", varBuffer, "")	//remove )
		varBuffer = replaceString(":", varBuffer, "")	//remove :
		varBuffer = replaceString(imageVariable, varBuffer, imageVariable+" ")	//remove )
//		print varBuffer
		variable v1
		sscanf varBuffer, "%*s%f%*[^\t\n]", v1
	
//		print v1
		return v1
	else
		return -1
	endif
end


function/wave acq4Display(mat, pixelSize, [zResolution, zOffset, totalDuration, xOffset, yOffset])
	wave mat
	variable pixelSize, zResolution, totalDuration, zOffset, xOffset, yOffset
	
	imageTransform/g=3 transposeVol mat; wave m_volumeTranspose
	duplicate/o/free m_volumeTranspose mat2
	imageTransform/g=5 transposeVol mat2
	duplicate/o m_volumeTranspose acq4In
	setScale/P x xOffset, pixelSize, "m", acq4In
	setScale/P y (yOffset - (dimsize(mat,1)*pixelSize)), pixelSize, "m", acq4In
	if(zresolution != 0)
		setScale/P z zOffset, zResolution, "m", acq4In
		print "Z stack"
	endif
	if(totalDuration != 0)
		SetScale/I z 0,totalDuration,"s", acq4In
		print "Time Series"
	endif
	dowindow/k acq4Import
	newIMage/F/k=1/n=acq4Import acq4In
	if(dimsize(acq4in,2) > 1)
		WMAppend3DImageSlider()
	endif
	ModifyGraph height={Plan,1,left,bottom}
	killwaves m_volumeTranspose
	return acq4In
end

function loadAcq4Image()
	
	print "---------------"
	
	variable/g acq4FileID
	HDF5OpenFile/I/R acq4FileID as ""
	newPath acq4Path, s_path
	HDF5LoadData/q/n=acq4Image/o acq4FileID, "data"; wave acq4Image
	HDF5CloseFile acq4FileID
	
	string/g waveNote = acq4LoadIndex()
	
	variable pixelSize = numberbyKey("pixelSize", waveNote, "=",";")
	if(numType(pixelSize) == 2)
		pixelSize = numberbyKey("pixelHeight", waveNote, "=",";")
	endif
	variable zResolution = numberbyKey("zResolution", waveNote, "=",";")
	variable zOffset = numberbyKey("zOffset", waveNote, "=",";")
	if(numType(zResolution) == 2)
		zResolution = 0
	endif
	variable totalDuration = numberbyKey("totalDuration", waveNote, "=",";")
	if(numType(totalDuration) == 2)
		totalDuration = 0
	endif
	
	variable xOffset = numberbyKey("xOffset", waveNote, "=",";")
	variable yOffset = numberbyKey("yOffset", waveNote, "=",";")
	
	wave acq4in = acq4Display(acq4Image, pixelSize, zResolution=zResolution, zOffset=zOffset, totalDuration=totalDuration, xOffset=xOffset, yOffset=yOffset)
//	print pixelSize
	print waveNote
	note acq4in, waveNote
	killwaves acq4Image
end

function/wave convertEncoder2SPeed(encoder, frameRate)
	wave encoder
	variable frameRate		//seconds
	
	variable wheelCircumference = pi*25.5	//michael's wheel is 30 cm?
	
	variable encoderSampling = dimdelta(encoder,0)
	variable subSampling = framerate/encoderSampling
	
	duplicate/o/free encoder encoder_dif
	differentiate/meth=2 encoder_dif
	encoder_dif *= dimDelta(encoder, 0)
	make/o/n=(dimSize(encoder,0)/(subSampling)) encoder_speed
	encoder_speed = sum(encoder_dif, pnt2x(encoder_dif,p*subSampling), pnt2x(encoder_dif, (p*subSampling)+(subSampling+1)))
	
	encoder_Speed /= frameRate
	encoder_Speed /= (360 / wheelCircumference)
	
	SetScale/P x 0,framerate,"s", encoder_speed
	
	return encoder_speed
	
end

function/wave loadACQ4EncoderData()
	
	print "---------------"
	
	variable/g acq4FileID
	HDF5OpenFile/I/R acq4FileID as ""
	newPath acq4Path, s_path
	HDF5LoadData/q/n=acq4Enc/o acq4FileID, "data"; wave acq4Enc
	HDF5CloseFile acq4FileID
	
	duplicate/o/r=[4][] acq4Enc encoderDegrees
	redimension/n=(dimsize(acq4enc, 1)) encoderDegrees
	
	string/g waveNote = acq4LoadIndex(); print waveNote
	variable totalDuration = numberbyKey("totalDuration", waveNote, "=",";")
	variable frameDuration = numberbyKey("frameDuration", waveNote, "=",";")
	
	SetScale/I x 0,totalDuration,"s", encoderDegrees
	
	display/k=1 convertEncoder2SPeed(encoderDegrees, frameDuration)	//shows the speed in cm/s for each frame in the image
	Label left "cm / s"

end