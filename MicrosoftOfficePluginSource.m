//
//  MicrosoftOfficePluginSource.m
//  MicrosoftOfficePlugin
//
//  Created by Patrick Robertson on 17/06/2011.
//  Copyright Patrick Robertson 2011. All rights reserved.
//

#import "MicrosoftOfficePluginSource.h"

@implementation MicrosoftOfficePluginSource
- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry{
    return YES;
}

- (NSImage *) iconForEntry:(NSDictionary *)dict{
    return nil;
}


- (NSArray *) objectsForEntry:(NSDictionary *)theEntry{
	return nil;
    
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
	
	// Structure of the com.microsoft.office.plist file — where the recent docs are stored (MS Office 2011)
	NSDictionary *IDPreferenceValuePairs = [NSDictionary dictionaryWithObjectsAndKeys:@"14\\File MRU\\MSWD", @"com.microsoft.Word",
                                            @"14\\File MRU\\XCEL", @"com.microsoft.Excel",
                                            @"14\\File MRU\\PPT3", @"com.microsoft.Powerpoint", nil];
    
	NSString *preferencesValue = nil, *bundleIdentifier = nil;
	
	// Find the correct preferences value for this app (bundle ID)
	NSString *path = [object singleFilePath];
	bundleIdentifier = [[NSBundle bundleWithPath:path] bundleIdentifier];
	preferencesValue = [IDPreferenceValuePairs objectForKey:bundleIdentifier];
	
	// incase something went wrong
	if (!preferencesValue) {
		return NO;
	}
    
    NSFileManager *fm = [NSFileManager defaultManager];
	
    // synchronise the file to save the latest changes
    CFPreferencesSynchronize((CFStringRef) @"com.microsoft.office",
							 kCFPreferencesCurrentUser,
							 kCFPreferencesAnyHost);
    
	// Get an array of recent docs from the office .plist (MS 2011 case)
	NSArray *recentDocuments = [(NSArray *)CFPreferencesCopyValue((CFStringRef) preferencesValue, 
																  (CFStringRef) @"com.microsoft.office", 
																  kCFPreferencesCurrentUser, 
																  kCFPreferencesAnyHost) autorelease];
	
	NSMutableArray *documentsArray = [[NSMutableArray alloc] initWithCapacity:20];
	NSData *fileData;
	NSString *filepath;
	
	if (recentDocuments) { // MS Office 2011
		
		for(NSDictionary *eachFile in recentDocuments) {
			fileData = [eachFile objectForKey:@"File Alias"];
			
			filepath = [[NDAlias aliasWithData:fileData] quickPath];
			
			if (filepath == nil) {
				// couldn't resolve bookmark, so skip
				continue;
			}
            if ([fm fileExistsAtPath:filepath]) {
                [documentsArray addObject:filepath];
            }
			
			if ([documentsArray count] > 20) {
				break;
			}
		}
	} // End MS Office 2011
	
	else { // MS Office 2008
		
		// Recent docs are stored in different key/value pairs for MS 2008
		NSDictionary *IDPreferenceValuePairs = [NSDictionary dictionaryWithObjectsAndKeys:@"2008\\File Aliases\\MSWD", @"com.microsoft.Word",
												@"2008\\File Aliases\\XCEL", @"com.microsoft.Excel",
												@"2008\\File Aliases\\PPT3", @"com.microsoft.Powerpoint", nil];		
		
		preferencesValue = [IDPreferenceValuePairs objectForKey:bundleIdentifier];
		
		
		// incase something went wrong
		if (!preferencesValue) {
			return NO;
		}
		
		NSData *fileData;
		NSUInteger i;
		
		@autoreleasepool {
            for (i = 1 ; i <= 100; ++i) {
                // MS Office '08 recent docs are stored in the format 2008\\FileAliases\\MSWD1,2,3...
                fileData = [(NSData *)CFPreferencesCopyValue((CFStringRef) [NSString stringWithFormat:@"%@%lu",preferencesValue,(unsigned long)i], 
                                                             (CFStringRef) @"com.microsoft.office", 
                                                             kCFPreferencesCurrentUser, 
                                                             kCFPreferencesAnyHost) autorelease];
                
                // break if there are no more key/value pairs
                if (!fileData) {
                    break;
                }
                
                filepath = [[NDAlias aliasWithData:fileData] quickPath];
                
                if (filepath == nil) {
                    // couldn't resolve bookmark, so skip
                    continue;
                }
                if ([fm fileExistsAtPath:filepath]) {
                    [documentsArray addObject:filepath];
                }
            }
        } // end @autoreleasepool
	} // End MS Office 2008
    
	// If there's been some kind of problem
	if (!documentsArray) {
		return NO;
	}
	
	NSArray *newChildren = [QSObject fileObjectsWithPathArray:documentsArray];
	for(QSObject * child in newChildren) {
		[child setObject:bundleIdentifier forMeta:@"QSPreferredApplication"];
	}
	
	[object setChildren:newChildren];
	[documentsArray release];
	return YES;
}

@end
