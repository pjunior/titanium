/**
 * Appcelerator Titanium - licensed under the Apache Public License 2
 * see LICENSE in the root folder for details on the license.
 * Copyright (c) 2009 Appcelerator, Inc. All Rights Reserved.
 */
#import "Controller.h"
#import <string>
#import "file_utils.h"
#import <zlib.h>

#define RUNTIME_UUID_FRAGMENT @"uuid=A2AC5CB5-8C52-456C-9525-601A5B0725DA"
#define MODULE_UUID_FRAGMENT @"uuid=1ACE5D3A-2B52-43FB-A136-007BD166CFD0"

@implementation Controller

-(void)simulate
{
	[progress setDoubleValue:[progress doubleValue]+1.0];
}

-(NSProgressIndicator*)progress
{
	return progress;
}

-(void)updateMessage:(NSString*)msg
{
	[textField setStringValue:msg];
}

-(NSArray*)urls
{
	return urls;
}

-(NSString*)directory
{
	return directory;
}

-(NSString*)installDirectory
{
	return installDirectory;
}

-(void)bailWithMessage: (NSString *) errorString;
{
	NSLog(@"Bailing with error: %@",errorString);
	NSRunCriticalAlertPanel(nil, errorString, @"Cancel", nil, nil);
	[NSApp terminate:nil];
}

-(void)generateDirectory:(NSString *) newDirectoryPath;
{
	NSFileManager * theFM = [[NSFileManager alloc] init];
	BOOL isDirectory;
	BOOL isExistent = [theFM fileExistsAtPath:newDirectoryPath isDirectory:&isDirectory];
	if (!isExistent) {
		[self generateDirectory:[newDirectoryPath stringByDeletingLastPathComponent]];
		[theFM createDirectoryAtPath:newDirectoryPath attributes:nil];
	} else if (!isDirectory) {
		NSString * errorMessage = [NSString stringWithFormat:@"Installer tried to create the folder \"%@\", but found a file in its place.",newDirectoryPath];
		[self performSelectorOnMainThread:@selector(bailWithMessage:) withObject:errorMessage waitUntilDone:YES];
	}
}

-(void)install:(NSString *)file forUrl:(NSURL *)url destination:(NSString*)dir
{
	NSArray *parts = [[[url query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] componentsSeparatedByString:@"&"];
	BOOL isRuntime = NO;
	BOOL isModule = NO;
	NSString *destdir = nil;
	NSString *subtype = nil;
	NSString *version = nil;
	
	NSEnumerator * partsEnumerator = [parts objectEnumerator];
	NSString *thisPart;
	while ((thisPart = [partsEnumerator nextObject])){
		if ([thisPart isEqualToString:RUNTIME_UUID_FRAGMENT]){
			isRuntime = YES;
			continue;
		}

		if ([thisPart isEqualToString:MODULE_UUID_FRAGMENT]){
			isModule = YES;
			continue;
		}
		
		if ([thisPart hasPrefix:@"name="]){
			subtype = [thisPart substringFromIndex:5];
			continue;
		}

		if ([thisPart hasPrefix:@"version="]){
			version = [thisPart substringFromIndex:8];
			continue;
		}
	}

	if (isRuntime){
		destdir = [NSString stringWithFormat:@"%@/runtime/osx/%@",dir,version];
	} else if (isModule) {
		destdir = [NSString stringWithFormat:@"%@/modules/osx/%@/%@",dir,subtype,version];
	} else {
		NSLog(@"Not sure what to do with %@ for %@",file,url);
		return;
	}

#ifdef DEBUG	
	NSLog(@"subtype=%@,version=%@,runtime=%d,module=%d",subtype,version,isRuntime,isModule);
#endif

	NSLog(@"Installing %@ for %@ into %@",file,url,destdir);
	[self generateDirectory:destdir];
	std::string src([file UTF8String]);
	std::string dest([destdir UTF8String]);
	kroll::FileUtils::Unzip(src,dest);
#ifdef DEBUG
	NSLog(@"After unzip %s to %s",src.c_str(),dest.c_str());
#endif
}
-(void)download:(Controller*)controller 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSArray *u = [controller urls];
	int count = [u count];
	NSString *dir = [controller directory];
	NSMutableDictionary *files = [[[NSMutableDictionary alloc] init] autorelease];
	NSProgressIndicator *progressBar = [controller progress];
	
	for (int c=0;c<count;c++)
	{
		NSURL *url = [u objectAtIndex:c];
		[controller updateMessage:[NSString stringWithFormat:@"Downloading %d of %d",c+1,count]];
		Downloader *downloader = [[Downloader alloc] initWithURL:url progress:progressBar];
		while ([downloader isDownloadComplete] == NO)
		{
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]; // this could be more elegant, but it works
		}
		NSString *filename = [downloader suggestedFileName];
		NSData *data = [downloader data];
		NSString *path = [NSString stringWithFormat:@"%@/%@",dir,filename];
		// write out our data
		BOOL isValidName = [filename length] > 5;
		BOOL isValidData = [data length] > 100;
		
		
		if (isValidData && isValidName) 
		{
			[data writeToFile:path atomically:YES];
			[files setObject:path forKey:url];
		} 
		else 
		{
			NSLog(@"Error in handling url \"%@\":",url);
			if (!isValidName) {
				NSLog(@"File name is too small to specify a file. \"%@\" was made instead.",filename);
			}
			if (!isValidData){
				NSString * dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				NSLog(@"Response data was too small to be a file. Received \"%@\" instead.",dataString);
				[dataString release];
			}
		}
		
		[downloader release];
	}
	
	[progressBar setIndeterminate:NO];
	[progressBar setMinValue:0.0];
	[progressBar setMaxValue:[files count]];
	[progressBar setDoubleValue:0.0];
	[controller updateMessage:[NSString stringWithFormat:@"Installing %d file%s",[files count],[files count]>1?"s":""]];
	
	NSString *destination = [controller installDirectory];
#ifdef DEBUG
	NSLog(@"installing to: %@, count: %d",destination,[files count]);
#endif

	NSArray * filesKeys = [files allKeys];
	
	for (int c=0;c<(int)[filesKeys count];c++)
	{
		[progressBar setDoubleValue:c+1];
		[controller updateMessage:[NSString stringWithFormat:@"Installing %d of %d file%s",c+1,[files count],[files count]>1?"s":""]];
		NSURL * thisFileKey = [filesKeys objectAtIndex:c];
		NSString * thisFileString = [files objectForKey:thisFileKey];
		[controller install:thisFileString forUrl:thisFileKey destination:destination];
	}
	[progressBar setDoubleValue:[files count]];

	[controller updateMessage:@"Installation complete"];

	NSLog(@"Installation is complete, exiting after installing %d files",[filesKeys count]);
	[pool release];
	[NSApp terminate:self];
}

-(void)dealloc
{
	[urls release];
	[directory release];
	[installDirectory release];
	[super dealloc];
}

-(void)awakeFromNib
{ 
	[NSApp setDelegate:self];
	[textField setStringValue:@"Connecting to download site..."];
	[progress setUsesThreadedAnimation:NO];
	[progress setIndeterminate:NO];
	[progress setMinValue:0.0];
	[progress setMaxValue:100.0];
	[progress setDoubleValue:0.0];
	[window center];
	
	NSBeep();

	NSProcessInfo *p = [NSProcessInfo processInfo];
	NSArray *args = [p arguments];
#ifdef DEBUG
	NSLog(@"arguments = %@",args);
#endif
	int count = [args count];
	
	NSString *appname = count > 1 ? [args objectAtIndex:1] : @"Application Installer";
	NSString *title = count > 2 ? [args objectAtIndex:2] : @"Additional application libraries required";
	NSString *message = count > 3 ? [args objectAtIndex:3] : @"The application needs to download additional libraries to continue.";
	
	NSString *appTitle = [NSString stringWithFormat:@"%@ Installer",appname];
	
	// dynamically set the window based on the name of the app
	[window setTitle:appTitle];
	
	// figure out where the caller wants us to write the files once download
	if (count >5) {
		directory = [[args objectAtIndex:4] stringByExpandingTildeInPath];
		[directory retain];

		// figure out where the caller wants us to install once download
		installDirectory = [[args objectAtIndex:5] stringByExpandingTildeInPath];
		[installDirectory retain];
	} else {
		[self bailWithMessage:@"Sorry, but the Application Installer was not given enough information to determine which libraries need downloading."];
		return;
	}

	
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL dir = NO;
	if (![fm fileExistsAtPath:directory isDirectory:&dir] && dir == NO)
	{
		[fm createDirectoryAtPath:directory attributes:nil];
	}
	
	// slurp in the URLS
	urls = [[NSMutableArray alloc] init];
	for (int c=6;c<count;c++)
	{
		NSURL *url = [NSURL URLWithString:[args objectAtIndex:c]];
		[urls addObject:url];
	}

	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Continue"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	[alert setAlertStyle:NSInformationalAlertStyle];
	
	if ([alert runModal] != NSAlertFirstButtonReturn) 
	{
		[NSApp terminate:nil];
		return;
	}
	[alert release];

	[NSApp arrangeInFront:window];
	[window makeKeyAndOrderFront:window];
	[NSApp activateIgnoringOtherApps:YES];
}

-(IBAction)cancel:(id)sender
{
	[button setEnabled:NO];
	[progress setDoubleValue:100.0];
	[textField setStringValue:@"Cancelling..."];
	[NSApp terminate:self];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notif
{
	[NSThread detachNewThreadSelector:@selector(download:) toTarget:self withObject:self];
}

@end
