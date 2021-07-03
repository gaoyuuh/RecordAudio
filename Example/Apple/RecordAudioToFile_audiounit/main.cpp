/*

File:main.cpp

Abstract: simple audio-in recorder

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright ¬© 2006 Apple Computer, Inc., All Rights Reserved

*/ 

#include <Carbon/Carbon.h>
#include <sys/param.h>
#include "DCAudioFileRecorder.h"

static OSStatus			WindowEventHandler( EventHandlerCallRef inCaller, EventRef inEvent, void* inRefcon );
static IBNibRef			sNibRef;
static HIViewRef		gFileLocationView, gRecordButtonView;
static Boolean			gIsRecording = false;
DCAudioFileRecorder		*gAudioFileRecorder = NULL;
FSRef					gParentDir;
CFStringRef				gFileName= NULL;

const HIViewID	kFileLocationID = { 'fLoc', 128 };
const HIViewID	kRecordButtonID = { 'aRec', 129 };

AudioStreamBasicDescription	gAACFormat = {44100.0, kAudioFormatMPEG4AAC, 0, 0, 1024, 0, 2, 0, 0};

CFStringRef NavSaveFile(FSRef *fileRef)
{
    NavDialogCreationOptions dlgOpts;
    NavDialogRef rDialog;
    OSStatus err = noErr;
	NavReplyRecord outReply;
	CFStringRef outName = NULL;
	
	err = NavGetDefaultDialogCreationOptions(&dlgOpts);
    if (err != noErr)
    {
        fprintf(stderr, "NavGetDefaultDialogCreationOptions failed, err %d!\n", err);
        return NULL;
	}

	dlgOpts.clientName = CFSTR("RecordAudioToFile");
    dlgOpts.windowTitle = CFSTR("Select File Location");
	dlgOpts.saveFileName = CFSTR("Audio Recording.m4a");
    dlgOpts.optionFlags |= kNavDefaultNavDlogOptions;

	err = NavCreatePutFileDialog(&dlgOpts, '????', '????', NULL, NULL, &rDialog);
	if (err != noErr)
	{
		fprintf(stderr, "NavCreatePutFileDialog failed, err %d!\n", err);
        return NULL;
	}

	err = NavDialogRun(rDialog);
	if(err != noErr)
	{
		NavDialogDispose(rDialog);
        fprintf(stderr, "NavDialogRun failed, err %d!\n", err);
        return NULL;
	}

	if(NavDialogGetUserAction(rDialog) == kNavUserActionCancel || kNavUserActionNone)
	{
		NavDialogDispose(rDialog);
		return NULL;
	}
	
	if (noErr != (err = NavDialogGetReply(rDialog, &outReply)))
    {
		NavDialogDispose(rDialog);
		fprintf(stderr, "NavDialogGetReply failed, err %d!\n", err);
        return NULL;
	}

	NavDialogDispose(rDialog);

	AEKeyword theAEKeyword;
	DescType typeCode;
	Size actualSize = 0;
	
	err = AEGetNthPtr (&(outReply.selection), 1, typeFSRef, &theAEKeyword, &typeCode, fileRef, sizeof(FSRef), &actualSize);
    if (err != noErr)
    {
		NavDisposeReply(&outReply);
        fprintf(stderr, "doOpenFileDlg() - AEGetNthPtr() failed, returning %lu!\n", (unsigned long) err);
        return NULL;
    }
	 
	outName = CFStringCreateCopy(NULL, outReply.saveFileName);
	NavDisposeReply(&outReply);

	return outName;
}

OSStatus SelectFileLocation()
{
	OSStatus			err;
	
	if(gFileName)
		CFRelease(gFileName);
		
	// let user select file location
	gFileName = NavSaveFile(&gParentDir);
	if(gFileName == NULL)
		return -1;
	
	// create path to file and stick it in location text box
	CFURLRef dirurl = CFURLCreateFromFSRef(NULL, &gParentDir);
	if (dirurl == NULL)
	{
		fprintf(stderr, "CFURLCreateFromFSRef failed\n");
        return -1;
	}

	CFURLRef fullurl = CFURLCreateCopyAppendingPathComponent(NULL, dirurl, gFileName, false);
	if (fullurl == NULL)
	{
		CFRelease(dirurl);
		fprintf(stderr, "CFURLCreateCopyAppendingPathComponent failed\n");
        return -1;
	}
	
	CFStringRef fullpath = CFURLCopyFileSystemPath(fullurl, kCFURLPOSIXPathStyle);
	if (fullpath == NULL)
	{
		CFRelease(dirurl);
		CFRelease(fullurl);
		fprintf(stderr, "CFURLCopyFileSystemPath failed\n");
        return -1;
	}

	err = SetControlData(gFileLocationView, kControlEntireControl, kControlEditTextCFStringTag, sizeof(CFStringRef), &fullpath);
	CFRelease(dirurl);
	CFRelease(fullurl);
	CFRelease(fullpath);

	return err;
}

OSStatus StartRecording()
{
	OSStatus err = noErr;
	
	if(gIsRecording)
		return noErr;
	
	if(gAudioFileRecorder)
		delete gAudioFileRecorder; gAudioFileRecorder = NULL;
	
	gAudioFileRecorder = new DCAudioFileRecorder;
	err = gAudioFileRecorder->Configure(gParentDir, gFileName, &gAACFormat);
	if(err != noErr)
	{
		delete gAudioFileRecorder; gAudioFileRecorder = NULL;
		return err;
	}
	
	err = gAudioFileRecorder->Start();
	if(err != noErr)
	{
		delete gAudioFileRecorder; gAudioFileRecorder = NULL;
		return err;
	}
	
	err = SetControlTitleWithCFString(gRecordButtonView, CFSTR("Stop"));
	gIsRecording = true;
	return err;
}

OSStatus StopRecording()
{
	OSStatus err = noErr;
	
	if(!gIsRecording)
		return noErr;
	
	err = gAudioFileRecorder->Stop();
	err = SetControlTitleWithCFString(gRecordButtonView, CFSTR("Record"));

	// delete the object here so the async file I/O flushs
	delete gAudioFileRecorder; gAudioFileRecorder = NULL;
	gIsRecording = false;
	
	return err;
}

//--------------------------------------------------------------------------------------------
DEFINE_ONE_SHOT_HANDLER_GETTER( WindowEventHandler )

int main(int argc, char* argv[])
{
    OSStatus                    err;
    WindowRef                    window;
    static const EventTypeSpec    kWindowEvents[] =
    {
        { kEventClassCommand, kEventCommandProcess }
    };

    // Create a Nib reference, passing the name of the nib file (without the .nib extension).
    // CreateNibReference only searches into the application bundle.
    err = CreateNibReference( CFSTR("main"), &sNibRef );
    require_noerr( err, CantGetNibRef );
    
    // Once the nib reference is created, set the menu bar. "MainMenu" is the name of the menu bar
    // object. This name is set in InterfaceBuilder when the nib is created.
    err = SetMenuBarFromNib( sNibRef, CFSTR("MenuBar") );
    require_noerr( err, CantSetMenuBar );
    
    
    // Create a window. "MainWindow" is the name of the window object. This name is set in 
    // InterfaceBuilder when the nib is created.
    err = CreateWindowFromNib( sNibRef, CFSTR("MainWindow"), &window );
    require_noerr( err, CantCreateWindow );

    // Install a command handler on the window. We don't use this handler yet, but nearly all
    // Carbon apps will need to handle commands, so this saves everyone a little typing.
    InstallWindowEventHandler( window, GetWindowEventHandlerUPP(),
                               GetEventTypeCount( kWindowEvents ), kWindowEvents,
                               window, NULL );
    
    // Position new windows in a staggered arrangement on the main screen
    RepositionWindow( window, NULL, kWindowCascadeOnMainScreen );
    
	err = HIViewFindByID( HIViewGetRoot(window), kFileLocationID, &gFileLocationView );
    require_noerr( err, CantGetLocationView );

	err = HIViewFindByID( HIViewGetRoot(window), kRecordButtonID, &gRecordButtonView );
    require_noerr( err, CantGetRecordButtonView );

    // The window was created hidden, so show it
    ShowWindow( window );

    
    // Run the event loop
    RunApplicationEventLoop();

CantSetMenuBar:
CantGetNibRef:
CantCreateWindow:
CantGetLocationView:
CantGetProgressView:
CantGetRecordButtonView:
    return err;
}

//--------------------------------------------------------------------------------------------
static OSStatus
WindowEventHandler( EventHandlerCallRef inCaller, EventRef inEvent, void* inRefcon )
{
    OSStatus    err = eventNotHandledErr;
    
    switch ( GetEventClass( inEvent ) )
    {
        case kEventClassCommand:
        {
            HICommandExtended cmd;
            verify_noerr( GetEventParameter( inEvent, kEventParamDirectObject, typeHICommand, NULL, sizeof( cmd ), NULL, &cmd ) );
            
            switch ( GetEventKind( inEvent ) )
            {
                case kEventCommandProcess:
                    switch ( cmd.commandID )
                    {
						case 'fBro':
							if(SelectFileLocation() == noErr)
								HIViewSetEnabled(gRecordButtonView, true);
						break;
						
						case 'fRec':
							if(gIsRecording)
								StopRecording();
							else
								StartRecording();
						break;
                        
                        default:
                            break;
                    }
                    break;
            }
            break;
        }
            
        default:
            break;
    }
    
    return err;
}
