# Audio Toolbox Convert File

The ConvertFile application provides sample code for converting audio data using the two main conversion mechanisms in CoreAudio: the ExtAudioFile and AudioConverter API. The project contains two targets, one for conversion using ExtAudioFile, and one using AudioConverter. The application provides examples of how to read in a data file, process data input arguments, and provide those to the conversion APIs.

## Main Files

UseAC-AF.cpp
- Source code for conversion using the AudioConverter API

UseExtAF.cpp
- Source code for conversion using the ExtAudioFile API

## Version History

Version 1.0 - Sample application for converting file data using the ExtAudioFile and AudioConverter API
	2010-02-05 - Add support for bit depth setting and layered formats
	2010-04-28 - Fixed typo in description.
	2010-06-16 - 1. Fixed problem of ConvertFile audio converter not trimming trailing zeros correctly.
				 2. AC can now decode samr, alac.
				 3. Fixed some memory leaks.
				 4. Corrected aach encoder's priming info.
	2012-07-25 - Analyzer errors are fixed.
Version 1.1 - Updated for Xcode 8, removed deprecation warnings.

## Requirements

### Build

Xcode 8.0, macOS 10.12 SDK

### Runtime

macOS 10.9 or greater

Copyright (C) 2009-2016 Apple Inc. All rights reserved.