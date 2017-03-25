//
//  AppDelegate.m
//  ReadingList
//
//  Created by Ryder Mackay on 2017-03-24.
//  Copyright © 2017 Ryder Mackay. All rights reserved.
//

#import "AppDelegate.h"
#import "ReadingList.h"
#import <objc/runtime.h>

@interface SwizzleLamb : NSObject
+ (BOOL)canPerformUserInitiatedBookmarkOperations;
@end

@implementation SwizzleLamb
+ (BOOL)canPerformUserInitiatedBookmarkOperations { return NO; }
@end

@interface AppDelegate () <NSTableViewDataSource>
@property (nonatomic) id <ReadingListController> readingListController;
@property (nonatomic) IBOutlet NSArrayController *arrayController;
@property (nonatomic) IBOutlet NSWindow *window;
@property (nonatomic) IBOutlet NSTableView *tableView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // if we don't disable undo support, we'll have to somehow make -frontmostUndoController return non-nil to get deletion to work
    Method m1 = class_getClassMethod(NSClassFromString(@"BookmarksUndoController"), @selector(canPerformUserInitiatedBookmarkOperations));
    Method m2 = class_getClassMethod([SwizzleLamb class], @selector(canPerformUserInitiatedBookmarkOperations));
    method_exchangeImplementations(m1, m2);
    
    self.window.titleVisibility = NSWindowTitleHidden;
    
    // -allItems is initially nil, so command line apps will have to block until the change notification
    self.readingListController = [NSClassFromString(@"ReadingListController") sharedController];
    
    // no apparent way to observe changes so we'll use the underlying store notifications directly
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingListDataStoreItemsDidChange:) name:@"ReadingListDataStoreItemsDidChange" object:nil];
    
    [self.tableView registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL]];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.readingListController savePendingChangesBeforeTermination];
}

- (void)readingListDataStoreItemsDidChange:(NSNotification *)note {
    self.arrayController.content = [self.readingListController.allItems mutableCopy]; // bindings lol
}

- (void)printReadingList {
    id <ReadingListController> controller = self.readingListController;
    NSLog(@"%lu items", (unsigned long)controller.itemCount);
    for (id <ReadingListItem> item in controller.allItems) {
        NSLog(@"%@: %@", (item.siteName ?: item.domainString), item.title);
        NSLog(@"Added %@", item.dateAdded);
        NSLog(@"%@", item.previewText);
    }
}

- (IBAction)search:(NSSearchField *)sender {
    NSString *searchTerm = sender.stringValue;
    if (searchTerm.length > 0) {
        NSPredicate *title = [NSPredicate predicateWithFormat:@"title contains[cd] %@", searchTerm];
        NSPredicate *domain = [NSPredicate predicateWithFormat:@"domainString contains[cd] %@", searchTerm];
        NSPredicate *preview = [NSPredicate predicateWithFormat:@"previewText contains[cd] %@", searchTerm];
        self.arrayController.filterPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[title, domain, preview]];
    } else {
        self.arrayController.filterPredicate = nil;
    }
}

- (IBAction)delete:(id)sender {
    for (id <ReadingListItem> item in self.arrayController.selectedObjects) {
        [self.readingListController removeItem:item];
    }
    [self.arrayController removeObjects:self.arrayController.selectedObjects];
}

- (IBAction)open:(id)sender {
    [self openSelectedURLsInBackground:NO];
}

- (IBAction)openInBackground:(id)sender {
    [self openSelectedURLsInBackground:YES];
}

- (void)openSelectedURLsInBackground:(BOOL)inBackground {
    NSMutableArray *urls = [NSMutableArray array];
    for (id <ReadingListItem> item in self.arrayController.selectedObjects) {
        NSURL *url = [NSURL URLWithString:item.urlString];
        if (url) {
            [urls addObject:url];
        }
    }
    NSWorkspaceLaunchOptions options = NSWorkspaceLaunchDefault;
    if (inBackground) {
        options |= NSWorkspaceLaunchWithoutActivation;
    }
    
    [[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:nil options:options additionalEventParamDescriptor:nil launchIdentifiers:nil];
}

#pragma mark - Dragging destination support

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    
    if (![[info draggingPasteboard] canReadObjectForClasses:@[[NSURL class]] options:nil]) {
        return NSDragOperationNone;
    }
    
    if (!([self validURLsForDropInfo:info].count > 0)) {
        return NSDragOperationNone;
    }
    
    [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
    
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSArray <NSURL *> *validURLs = [self validURLsForDropInfo:info];
    for (NSURL *url in validURLs) {
        [self.readingListController addItemWithTitle:nil url:url addUserInteraction:0 allowUndo:NO];
    }
    
    return validURLs.count > 0;
}

- (NSArray <NSURL *> *)validURLsForDropInfo:(id <NSDraggingInfo>)info {
    NSMutableArray *validURLs = [NSMutableArray array];
    for (NSURL *url in [[info draggingPasteboard] readObjectsForClasses:@[[NSURL class]] options:nil]) {
        if ([url isKindOfClass:[NSURL class]]) {
            if ([url.scheme.lowercaseString isEqual:@"http"] || [url.scheme.lowercaseString isEqualToString:@"https"]) {
                [validURLs addObject:url];
            }
        }
    }
    return [validURLs copy];
}

@end
