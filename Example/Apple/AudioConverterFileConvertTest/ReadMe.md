# Audio Converter File Convert Test

This sample demonstrates using the Audio Converter APIs to convert from a PCM audio format to a compressed format including AAC.

## Using the Sample

Build and run the sample on an iOS device or the iOS Simulator running iOS 10 or later using Xcode 8.  

To demonstrate using the Audio Converter APIs, this sample provides several options for formats and sample rates to convert to.  To use this sample, select the audio format and sample rate (if appropriate) and tap the "Convert & Play" button.  Once the audio file is successfully converted, it is played automatically using AVAudioPlayer.

## Important Notes

Audio Format and Sample Rate choices presented in the UI are simply used for testing purposes, developers are free to choose any other supported file type or encoding format and present these choices however they wish.

For more information on the importance of interruption handling and Audio Session setup when performing offline encoding please see the Audio Session Programming Guide:

Audio Session Programming Guide: <https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html> 

Offline format conversion requires interruption handling. Specifically, you must handle interruptions at the audio data buffer level.

By way of background, you can use a hardware assisted-codec—on certain devices—to encode linear PCM audio to AAC format. You use the codec as part of an Audio Converter object (of type AudioConverterRef). For information on these opaque types, refer to Audio Converter Services Reference and Extended Audio File Services Reference.

Audio Converter Services Reference: <https://developer.apple.com/reference/audiotoolbox/1653485-audio_converter_services>

Extended Audio File Services Reference: <https://developer.apple.com/reference/audiotoolbox/1664681-extended_audio_file_services>

To handle an interruption during hardware-assisted encoding, take two things into account:

1. The codec may or may not be able to resume encoding after the interruption ends.
2. The codec may be unavailable, probably due to an interruption.

Note: iOS 7 provides for software AAC encode, devices with hardware encoder will show as having two encoders, devices such as the iPhone 5s only has a software encoder that is much faster and more flexible than the older hardware encoders.

Encoding takes place as you repeatedly call the AudioConverterFillComplexBuffer function supplying new buffers of input audio data via the input data procedure producing buffers of audio encoded in the output format. To handle an interruption, you respond to the function’s result code, as described here:

* kAudioConverterErr_HardwareInUse — This result code indicates that the underlying hardware codec has become unavailable, probably due to an interruption. In this case, your application must stop calling AudioConverterFillComplexBuffer.  If you can resume conversion, wait for an interruption-ended call from the audio session. In your interruption-end handler, reactivate the session and then resume converting the audio data.

To check if the AAC codec can resume, obtain the value of the associated converter’s kAudioConverterPropertyCanResumeFromInterruption property.  The value is 1 (can resume) or 0 (cannot resume) or the property itself may not be supported (implies software codec use where we can resume).  You can obtain this value any time after instantiating the converter—immediately after instantiation, upon interruption, or after interruption ends.

If the converter cannot resume, then on interruption you must abandon the conversion. After the interruption ends, or after the user relaunches your application and indicates they want to resume conversion, re-instantiate the extended audio file object and perform the conversion again.

## Main Files

__AudioFileConvertOperation.h/.m__:

- AudioFileConvertOperation is the main class in this sample that demonstrates use of the Audio Converter APIs to convert an input file to another file format.  All the code demonstrating how to perform conversion is contained in this one file, the rest of the sample may be thought of as a simple framework for the demonstration code in this file.  This class also handles tracking if the active AVAudioSession is interrupted as well as checking if a codec does not support resuming from an interruption.  For details about this see the "Important Notes" section above.

## Requirements

### Build

Xcode 8.0 or later; iOS 10.0 SDK or later

### Runtime

iOS 10.0 or later.

Copyright (C) 2016 Apple Inc. All rights reserved.