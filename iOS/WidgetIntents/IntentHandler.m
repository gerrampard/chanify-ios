//
//  IntentHandler.m
//  WidgetIntents
//
//  Created by WizJin on 2021/6/16.
//

#import "IntentHandler.h"
#import <FMDB.h>
#import <sqlite3.h>
#import "ShortcutsConfigurationIntent.h"
#import "CHUserModel.h"

@interface IntentHandler () <ShortcutsConfigurationIntentHandling>

@property (nonatomic, readonly, strong) FMDatabaseQueue *dbQueue;

@end

@implementation IntentHandler

- (instancetype)init {
    if (self = [super init]) {
        NSURL *url = [NSFileManager.defaultManager URLForGroupId:@kCHAppWidgetGroupName path:@kCHDBWidgetName];
        _dbQueue = [FMDatabaseQueue databaseQueueWithURL:url flags:SQLITE_OPEN_READONLY|kCHDBFileProtectionFlags];
    }
    return self;
}

- (id)handlerForIntent:(INIntent *)intent {
    // This is the default implementation.  If you want different objects to handle different intents,
    // you can override this and return the handler you want for that particular intent.
    return self;
}

#pragma mark - ShortcutsConfigurationIntentHandling
- (void)provideEntriesOptionsCollectionForShortcutsConfiguration:(ShortcutsConfigurationIntent *)intent withCompletion:(void (^)(INObjectCollection<EntryType *> * _Nullable entriesOptionsCollection, NSError * _Nullable error))completion {
    if (completion) {
        NSMutableArray<EntryType *> *items = [NSMutableArray new];
        [items addObject:self.noneEntry];
        [items addObject:self.scanEntry];

        CHUserModel *me = [CHUserModel modelWithKey:[CHSecKey secKeyWithName:@kCHUserSecKeyName device:NO created:NO]];
        if (me.uid.length > 0) {
            [self.dbQueue inDatabase:^(FMDatabase *db) {
                FMResultSet *rows = [db executeQuery:@"SELECT `cid`,`name` FROM `channels` WHERE `uid`=?;", me.uid];
                while (rows.next) {
                    NSString *eid = [@"channel." stringByAppendingString:[rows stringForColumnIndex:0]];
                    NSString *title = [NSString stringWithFormat:@"%@: %@", @"channel".localized, [rows stringForColumnIndex:1].localized];
                    [items addObject:[[EntryType alloc] initWithIdentifier:eid displayString:title]];
                }
            }];
        }
        completion([[INObjectCollection alloc] initWithItems:items], nil);
    }
}

- (nullable NSArray<EntryType *> *)defaultEntriesForShortcutsConfiguration:(ShortcutsConfigurationIntent *)intent {
    return  @[self.scanEntry];
}

#pragma mark - Private Methods
- (EntryType *)noneEntry {
    return [[EntryType alloc] initWithIdentifier:@"none" displayString:@"none".localized];
}

- (EntryType *)scanEntry {
    return [[EntryType alloc] initWithIdentifier:@"action.scan" displayString:@"scan".localized];
}


@end