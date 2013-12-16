//
//  AppDelegate.m
//  Sysex Split
//
//  Created by Jakob Penca on 16/12/13.
//  Copyright (c) 2013 Jakob Penca. All rights reserved.
//

#import "AppDelegate.h"

typedef enum A4SysexMessageID
{
	A4SysexMessageID_Kit		= 0x52,
	A4SysexMessageID_Sound		= 0x53,
	A4SysexMessageID_Pattern	= 0x54,
	A4SysexMessageID_Song		= 0x55,
	A4SysexMessageID_Settings	= 0x56,
	A4SysexMessageID_Global		= 0x57,
	
	A4SysexMessageID_Kit_X		= 0x58,
	A4SysexMessageID_Sound_X	= 0x59,
	A4SysexMessageID_Pattern_X	= 0x5A,
	A4SysexMessageID_Song_X		= 0x5B,
	A4SysexMessageID_Settings_X	= 0x5C,
	A4SysexMessageID_Global_X	= 0x5D,
}
A4SysexMessageID;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.messages = @[].mutableCopy;
}

- (IBAction)openFiles:(id)sender
{
	NSLog(@"open files...");
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.canChooseDirectories = NO;
	openPanel.canChooseFiles = YES;
	openPanel.allowsMultipleSelection = YES;
	
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
	 {
		 
		 if(result == NSFileHandlingPanelOKButton)
		 {
			 NSArray *urls = [openPanel URLs];
			 NSLog(@"opening %ld files", urls.count);
			 
			 for (NSURL *url in urls)
			 {
				 NSData *d = [NSData dataWithContentsOfFile:[url path]];
				 if(d)
				 {
					 NSArray *splits = [self splitData:d];
					 
					 for (NSData *d in splits)
					 {
						 if(d.length > 16 && [self messageLengthIsValidInSysexData:d] && [self checksumIsValidInSysexData:d])
						 {
							 [self.messages addObject:d];
						 }
					 }
					 
					 [self updateLabel];
					 [self enableActions:self.messages.count];
					 if(self.messages.count == 1)
					 {
						 [self.splitButton setEnabled:NO];
					 }
				 }
			 }
		 }
	 }];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (void) saveCombinedFiles
{
	if(!self.messages.count) return;
	
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.canCreateDirectories = YES;
	savePanel.allowedFileTypes = @[@"syx"];
	
	[savePanel beginSheetModalForWindow:self.window
					  completionHandler:^(NSInteger result)
	 {
		 if(result == NSFileHandlingPanelOKButton)
		 {
			 
			 NSMutableData *data = [NSMutableData data];
			 for (NSData *message in self.messages)
			 {
				 [data appendData:message];
			 }
			 [data writeToFile:savePanel.URL.path atomically:YES];
		 }
		 
	 }];
	
	
}

- (void) saveSplitFiles
{
	if(!self.messages.count) return;

	NSOpenPanel *savePanel = [NSOpenPanel openPanel];
	savePanel.canChooseDirectories = YES;
	savePanel.canCreateDirectories = YES;
	savePanel.canChooseFiles = NO;
	savePanel.allowsMultipleSelection = NO;
	
	[savePanel beginSheetModalForWindow:self.window
					  completionHandler:^(NSInteger result)
	 {
		 if(result == NSFileHandlingPanelOKButton)
		 {
			 NSURL *url = [savePanel URL];
			 
			 NSUInteger i = 0;
			 for (NSData *data in self.messages)
			 {
				 const uint8_t *bytes = data.bytes;
				 if(data.length <= 16) continue;
				 
				 NSData *packedPayload = [data subdataWithRange:NSMakeRange(0xA, data.length - 0xA - 0x5)];
				 NSData *unpackedPayload = [self dataUnpackedFrom7BitSysexEncoding:packedPayload];
				 if(unpackedPayload.length < 12) continue;
				 
				 NSString *fileName = nil;
				 switch (bytes[0x06])
				 {
					 case A4SysexMessageID_Kit:
					 {
						 const char *payloadBytes = unpackedPayload.bytes;
						 NSString *kitName = [NSString stringWithCString:&payloadBytes[0x04] encoding:NSASCIIStringEncoding];
						 
						 if([kitName isEqualToString:@""]) kitName = @"UNNAMED KIT";
						 fileName = [NSString stringWithFormat:@"Kit %03d - \"%@\"", bytes[0x09] + 1, kitName];
						 break;
					 }
					 case A4SysexMessageID_Sound:
					 {
						 const char *payloadBytes = unpackedPayload.bytes;
						 if(unpackedPayload.length < 0x152) continue;
						 NSString *soundName = @"";
						 
						 if(unpackedPayload.length == 0x162)
						 {
							 soundName = [NSString stringWithCString:&payloadBytes[0x152] encoding:NSASCIIStringEncoding];
						 }
						 else
						 {
							 soundName = [NSString stringWithCString:&payloadBytes[0x0C] encoding:NSASCIIStringEncoding];
						 }
						 
						 if([soundName isEqualToString:@""]) soundName = @"UNNAMED SOUND";
						 fileName = [NSString stringWithFormat:@"Sound %03d - \"%@\"", bytes[0x09] + 1, soundName];
						 break;
					 }
					 case A4SysexMessageID_Pattern:
					 {
						 fileName = [NSString stringWithFormat:@"Pattern %c%02d", 'A' + bytes[0x09]/16, (bytes[0x09] % 16) + 1];
						 break;
					 }
					 case A4SysexMessageID_Song:
					 {
						 fileName = [NSString stringWithFormat:@"Song %02d", bytes[0x09]+1];
						 break;
					 }
					 case A4SysexMessageID_Global:
					 {
						 fileName = [NSString stringWithFormat:@"Global %d", bytes[0x09]+1];
						 break;
					 }
					 case A4SysexMessageID_Settings:
					 {
						 fileName = @"Settings";
						 break;
					 }
					 default:
					 {
						 fileName = [NSString stringWithFormat:@"%d", (int)i];
						 break;
					 }
						 
				 }
				 
				 if(fileName)
				 {
					 [self saveFile:unpackedPayload withFileName:fileName toBaseURL:url];
				 }
				 i++;
			 }
		 }
		 
	 }];
}

- (NSData *)dataUnpackedFrom7BitSysexEncoding:(NSData *)inData
{
	const signed char *inBytes = inData.bytes;
	NSUInteger inLength = inData.length;
	
	NSUInteger cnt;
	NSUInteger cnt2 = 0;
	uint8_t msbByte = 0;
	NSUInteger outLength = 0;
	
	for (cnt = 0; cnt < inLength; cnt++)
		if(cnt % 8) outLength++;
	
	void *outBytes = malloc(outLength);
	
	for (cnt = 0; cnt < inLength; cnt++)
	{
		if ((cnt % 8) == 0)
		{
			msbByte = inBytes[cnt];
		}
		else
		{
			msbByte <<= 1;
			uint8_t *currentOutByte = outBytes + cnt2++;
			*currentOutByte = inBytes[cnt] | (msbByte & 0x80);
		}
	}
	
	return [NSData dataWithBytesNoCopy:outBytes length:outLength freeWhenDone:YES];
}

- (BOOL)checksumIsValidInSysexData:(NSData *)data
{
	const uint8_t *bytes = (const uint8_t *) data.bytes;
	uint16_t checksum = 0;
	NSUInteger checksumStartPos = 0x0a;
	NSUInteger checksumEndPos = data.length - 5;
	
	for (NSUInteger j = checksumStartPos; j < checksumEndPos; j++)
	{
		checksum += bytes[j];
	}
	
	checksum &= 0x3fff;
	
	if(bytes[checksumEndPos] != checksum >> 7
	   ||
	   bytes[checksumEndPos + 1] != (checksum & 0x7f))
	{
		return NO;
	}
	return YES;
}

- (BOOL)messageLengthIsValidInSysexData:(NSData *)data
{
	const uint8_t *bytes = (const uint8_t *)data.bytes;
	uint16_t dLen = data.length;
	uint16_t len = data.length - 10;
	uint16_t mLen = (bytes[dLen - 3] << 7) | (bytes[dLen - 2] & 0x7f);
	if(len != mLen)
	{
		return NO;
	}
	return YES;
}

- (void) saveFile:(NSData *)d withFileName:(NSString *)name toBaseURL:(NSURL *)url
{
	name = [name stringByAppendingString:@".syx"];
	url = [url URLByAppendingPathComponent:name];
	[d writeToFile:[url path] atomically:YES];
}

- (void) updateLabel
{
	self.Label.stringValue = [NSString stringWithFormat:@"%d SysEx %@",
							  (int)self.messages.count,
							  self.messages.count == 1 ? @"Message" : @"Messages"];
}

- (NSArray *)splitData:(NSData *)d
{
	NSMutableArray *array = [NSMutableArray array];
	const uint8_t *bytes = d.bytes;
	NSUInteger dataLength = d.length;
	
	
	for (NSUInteger start = 0; start < dataLength - 1; start++)
	{
		uint8_t current = bytes[start];
		BOOL isSysexStart = current == 0xf0;
		
		if(isSysexStart) // sysex begin
		{
			int chunkLength = 0;
			while (YES)
			{
				chunkLength++;
				
				if(start + chunkLength == dataLength ||
				   bytes[start + chunkLength] == 0xF7)
					break;
			}
			chunkLength++;
			
			NSData *chunk = [NSData dataWithBytes: bytes+start length:chunkLength];
			const uint8_t *bytes = chunk.bytes;
			NSUInteger len = chunk.length;
			if(len >= 2 && bytes[0] == 0xF0 && bytes[len-1] == 0xF7)
			{
				[array addObject:chunk];
			}
		}
	}
	
	return array;
}



- (IBAction)clear:(id)sender
{
	[self.messages removeAllObjects];
	[self enableActions:NO];
	[self updateLabel];
}

- (IBAction)combine:(id)sender
{
	if(!self.messages.count) return;
	[self saveCombinedFiles];
}

- (IBAction)split:(id)sender
{
	if(!self.messages.count) return;
	[self saveSplitFiles];
}

- (void) enableActions:(BOOL)enabled
{
	[self.clearButton setEnabled:enabled];
	[self.splitButton setEnabled:enabled];
	[self.combineButton setEnabled:enabled];
}

@end
