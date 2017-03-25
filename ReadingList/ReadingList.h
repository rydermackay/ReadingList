//
//  ReadingList.h
//  ReadingList
//
//  Created by Ryder Mackay on 2017-03-24.
//  Copyright © 2017 Ryder Mackay. All rights reserved.
//

@import Foundation;

// Hopper is awesome

@protocol ReadingListItem

- (NSString *)title;
- (NSString *)urlString;
- (NSString *)previewText;
- (NSString *)domainString;
- (NSString *)siteName;
- (NSString *)localTitle;
- (NSString *)localPreviewText;
- (NSDate *)dateAdded;
- (NSDate *)dateLastViewed;
- (NSDate *)dateLastFetched;
- (NSImage *)icon;

@end



@protocol ReadingListController

+ (instancetype)sharedController;

- (NSInteger)itemCount;
- (NSArray <ReadingListItem>*)allItems;

- (void)addItemWithTitle:(NSString *)title url:(NSURL *)url addUserInteraction:(NSInteger)userInteraction allowUndo:(BOOL)allowUndo;
- (void)markItem:(id <ReadingListItem>)item asUnread:(BOOL)isUnread;
- (void)removeItem:(id <ReadingListItem>)item;

- (void)pruneWebArchives;
- (void)clearAllItems;
- (void)savePendingChangesBeforeTermination;

@end
