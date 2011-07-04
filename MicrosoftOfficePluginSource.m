//
//  MicrosoftOfficePluginSource.m
//  MicrosoftOfficePlugin
//
//  Created by Patrick Robertson on 17/06/2011.
//  Copyright Patrick Robertson 2011. All rights reserved.
//

#import "MicrosoftOfficePluginSource.h"
#import <QSCore/QSObject.h>


@implementation MicrosoftOfficePluginSource
- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry{
    return YES;
}

- (NSImage *) iconForEntry:(NSDictionary *)dict{
    return nil;
}


// Return a unique identifier for an object (if you haven't assigned one before)
//- (NSString *)identifierForObject:(id <QSObject>)object{
//    return nil;
//}

- (NSArray *) objectsForEntry:(NSDictionary *)theEntry{
	return nil;
    
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
	// Structure of the com.microsoft.office.plist file — where the recent docs are stored
	NSDictionary *IDPreferenceValuePairs = [NSDictionary dictionaryWithObjectsAndKeys:@"14\\File MRU\\MSWD", @"com.microsoft.Word",
								  @"14\\File MRU\\XCEL", @"com.microsoft.Excel",
								   @"14\\File MRU\\PPT3", @"com.microsoft.Powerpoint", nil];
											
	NSString *preferencesValue = nil, *bundleIdentifier = nil;
	
	NSString *path = [object singleFilePath];
	
	bundleIdentifier = [[NSBundle bundleWithPath:path] bundleIdentifier];
	preferencesValue = [IDPreferenceValuePairs objectForKey:bundleIdentifier];
	
	// incase something went wrong
	if (!preferencesValue) {
		return NO;
	}
	
	NSMutableArray *documentsArray = [[NSMutableArray alloc] init];
	NSURL *url;
	NSError *err;
	
	NSArray *recentDocuments = [(NSArray *)CFPreferencesCopyValue((CFStringRef) preferencesValue, 
																  (CFStringRef) @"com.microsoft.office", 
																  kCFPreferencesCurrentUser, 
																  kCFPreferencesAnyHost) autorelease];
	NSData *fileData;
	NSString *filepath;
	
	
	
	for(NSDictionary *eachFile in recentDocuments) {
		fileData = [eachFile objectForKey:@"File Alias"];
		
		filepath = [[NDAlias aliasWithData:fileData] quickPath];
		
		if (filepath == nil) {
			// couldn't resolve bookmark, so skip
			continue;
		}
		[documentsArray addObject:filepath];
	}
	if (!documentsArray) {
		return NO;
	}
	NSArray *newChildren = [QSObject fileObjectsWithPathArray:documentsArray];
	for(QSObject * child in newChildren) {
		[child setObject:@"com.apple.Xcode" forMeta:@"QSPreferredApplication"];
	}
	[object setChildren:newChildren];
	
	[documentsArray release];
	return YES;
	
}


// Object Handler Methods

/*
- (void)setQuickIconForObject:(QSObject *)object{
    [object setIcon:nil]; // An icon that is either already in memory or easy to load
}
- (BOOL)loadIconForObject:(QSObject *)object{
	return NO;
    id data=[object objectForType:kMicrosoftOfficePluginType];
	[object setIcon:nil];
    return YES;
}
*/
@end
