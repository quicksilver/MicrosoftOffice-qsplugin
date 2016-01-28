//
//  MicrosoftOfficePluginSource.m
//  MicrosoftOfficePlugin
//
//  Created by Patrick Robertson on 17/06/2011.
//  Copyright Patrick Robertson 2011. All rights reserved.
//

#import "MicrosoftOfficePluginSource.h"

#define kWordBundleId @"com.microsoft.Word"
#define kExcelBundleId @"com.microsoft.Excel"
#define kPowerpointBundleId @"com.microsoft.Powerpoint"
#define kOfficeBundleId @"com.microsoft.office"

#define kOffice2016RecentDocumentsPlist @"~/Library/Containers/%@/Data/Library/Preferences/%@.securebookmarks.plist"

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
    NSDictionary *IDPreferenceValuePairs = @{kWordBundleId: @"14\\File MRU\\MSWD",
                                             kExcelBundleId: @"\\File MRU\\XCEL",
                                             kPowerpointBundleId: @"\\File MRU\\PPT3"};
    
	NSString *preferencesValue = nil, *bundleIdentifier = nil;
	
	// Find the correct preferences value for this app (bundle ID)
	NSString *path = [object singleFilePath];
	bundleIdentifier = [[NSBundle bundleWithPath:path] bundleIdentifier];
	preferencesValue = [IDPreferenceValuePairs objectForKey:bundleIdentifier];
	
	// incase something went wrong
	if (!preferencesValue) {
		return NO;
	}
    

    
    // ms2016
    NSDictionary *ms2016Dict = [NSDictionary dictionaryWithContentsOfFile:[[NSString stringWithFormat:kOffice2016RecentDocumentsPlist, bundleIdentifier, bundleIdentifier] stringByExpandingTildeInPath]];
    
    NSMutableArray *documentsArray = [[NSMutableArray alloc] initWithCapacity:20];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *recentDocuments = nil;
    if (ms2016Dict) { // MS Office 2016
        for (NSDictionary *fileDict in [ms2016Dict allValues]) {
            NSData *d = [fileDict objectForKey:@"kBookmarkDataKey"];
            NSDictionary *dd = [NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:d];
            if (![dd count]) {
                continue;
            }
            NSString *posixPath = [dd objectForKey:NSURLPathKey];
            if ([fm fileExistsAtPath:posixPath]) {
                [documentsArray addObject:posixPath];
            }
        }
        // sort the files based on last accessed date - word doesn't seem to do this.
        [documentsArray sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
            NSDate *d1 = [[fm attributesOfItemAtPath:path1 error:nil] objectForKey:NSFileModificationDate];
            NSDate *d2 = [[fm attributesOfItemAtPath:path2 error:nil] objectForKey:NSFileModificationDate];
            return d1 < d2;
        }];
    } else {
                
        // synchronise the file to save the latest changes
        CFPreferencesSynchronize((CFStringRef) kOfficeBundleId,
                                 kCFPreferencesCurrentUser,
                                 kCFPreferencesAnyHost);
        
        // Get an array of recent docs from the office .plist (MS 2011 case)
        recentDocuments = [(NSArray *)CFPreferencesCopyValue((CFStringRef) preferencesValue,
                                                             (CFStringRef) kOfficeBundleId,
                                                             kCFPreferencesCurrentUser,
                                                             kCFPreferencesAnyHost) autorelease];
        
        
        
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
        } else { // MS Office 2008
            
            // Recent docs are stored in different key/value pairs for MS 2008
            NSDictionary *IDPreferenceValuePairs = @{kWordBundleId: @"2008\\File Aliases\\MSWD",
                                                     kExcelBundleId: @"2008\\File Aliases\\XCEL",
                                                     kPowerpointBundleId: @"\\File Aliases\\PPT3"};
            
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
                                                                 (CFStringRef) kOfficeBundleId,
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
        
    }
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
