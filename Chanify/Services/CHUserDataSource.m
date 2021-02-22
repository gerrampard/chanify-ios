//
//  CHUserDataSource.m
//  Chanify
//
//  Created by WizJin on 2021/2/8.
//

#import "CHUserDataSource.h"
#import <FMDB/FMDB.h>
#import "CHMessageModel.h"
#import "CHChannelModel.h"

#define kCHDefChanCode  "0801"
#define kCHNSInitSql    \
    "CREATE TABLE IF NOT EXISTS `options`(`key` TEXT PRIMARY KEY,`value` BLOB);"   \
    "CREATE TABLE IF NOT EXISTS `messages`(`mid` TEXT PRIMARY KEY,`cid` BLOB,`from` TEXT,`raw` BLOB);"  \
    "CREATE TABLE IF NOT EXISTS `channels`(`cid` BLOB PRIMARY KEY,`deleted` BOOLEAN DEFAULT 0,`name` TEXT,`icon` TEXT,`unread` UNSIGNED INTEGER,`mute` BOOLEAN,`mid` TEXT);"   \
    "INSERT OR IGNORE INTO `channels`(`cid`) VALUES(X'0801');"      \
    "INSERT OR IGNORE INTO `channels`(`cid`) VALUES(X'08011001');"  \

@interface CHUserDataSource ()

@property (nonatomic, readonly, strong) FMDatabaseQueue *dbQueue;
@property (nonatomic, nullable, strong) NSData *srvkeyCache;

@end

@implementation CHUserDataSource

@dynamic srvkey;

+ (instancetype)dataSourceWithURL:(NSURL *)url {
    return [[self.class alloc] initWithURL:url];
}

- (instancetype)initWithURL:(NSURL *)url {
    if (self = [super init]) {
        _dsURL = url;
        _srvkeyCache = nil;
        _dbQueue = [FMDatabaseQueue databaseQueueWithURL:url];
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            if ([db executeStatements:@kCHNSInitSql]) {
                CHLogI("Open database: %s", db.databaseURL.path.cstr);
            }
        }];
    }
    return self;
}

- (void)close {
    [self.dbQueue close];
}

- (nullable NSData *)srvkey {
    if (self.srvkeyCache == nil) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            self.srvkeyCache = [db dataForQuery:@"SELECT `value` FROM `options` WHERE `key`=\"srvkey\" LIMIT 1;"];
        }];
    }
    return self.srvkeyCache;
}

- (void)setSrvkey:(nullable NSData *)srvkey {
    if (![self.srvkeyCache isEqual:srvkey]) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            BOOL res = NO;
            if (srvkey.length > 0 ) {
                res = [db executeUpdate:@"INSERT INTO `options`(`key`,`value`) VALUES(\"srvkey\",?) ON CONFLICT(`key`) DO UPDATE SET `value`=excluded.`value`;", srvkey];
            } else {
                [db executeUpdate:@"DELETE FROM `options` WHERE `key`=\"srvkey\";"];
                res = YES;
            }
            if (res) {
                self.srvkeyCache = srvkey;
            }
        }];
    }
}

- (BOOL)insertChannel:(CHChannelModel *)model {
    __block BOOL res = NO;
    if (model != nil) {
        NSData *ccid = [NSData dataFromBase64:model.cid];
        [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            NSString *mid = [db stringForQuery:@"SELECT `mid` FROM `messages` WHERE `cid`=? ORDER BY `mid` DESC LIMIT 1;", ccid];
            res = [db executeUpdate:@"INSERT INTO `channels`(`cid`,`name`,`icon`,`mid`) VALUES(?,?,?,?) ON CONFLICT(`cid`) DO UPDATE SET `name`=excluded.`name`,`icon`=excluded.`icon`,`mid`=excluded.`mid`,`deleted`=0;", ccid, model.name, model.icon, mid];
        }];
    }
    return res;
}

- (BOOL)updateChannel:(CHChannelModel *)model {
    __block BOOL res = NO;
    if (model != nil) {
        NSData *ccid = [NSData dataFromBase64:model.cid];
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            res = [db executeUpdate:@"UPDATE `channels` SET `name`=?,`icon`=? WHERE `cid`=? LIMIT 1;", model.name, model.icon, ccid];
        }];
    }
    return res;
}

- (BOOL)deleteChannel:(nullable NSString *)cid {
    __block BOOL res = NO;
    NSData *ccid = [NSData dataFromBase64:cid];
    if (ccid.length > 0) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            res = [db executeUpdate:@"UPDATE `channels` SET `deleted`=1 WHERE `cid`=? LIMIT 1;", ccid];
        }];
    }
    return res;
}

- (NSArray<CHChannelModel *> *)loadChannels {
    __block NSMutableArray<CHChannelModel *> *cids = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *res = [db executeQuery:@"SELECT `cid`,`name`,`icon`,`unread`,`mid` FROM `channels` WHERE `deleted`=0;"];
        while(res.next) {
            CHChannelModel *model = [CHChannelModel modelWithCID:[res dataForColumnIndex:0].base64 name:[res stringForColumnIndex:1] icon:[res stringForColumnIndex:2]];
            if (model != nil) {
                model.mute = [res boolForColumnIndex:3];
                model.mid = [res stringForColumnIndex:4];
                [cids addObject:model];
            }
        }
        [res close];
        [res setParentDB:nil];
    }];
    return cids;
}

- (nullable CHChannelModel *)channelWithCID:(nullable NSString *)cid {
    __block CHChannelModel *model = nil;
    NSData *ccid = [NSData dataFromBase64:cid];
    if (ccid == nil) ccid = [NSData dataFromHex:@kCHDefChanCode];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *res = [db executeQuery:@"SELECT `cid`,`name`,`icon`,`unread`,`mid` FROM `channels` WHERE `cid`=? LIMIT 1;", ccid];
        if (res.next) {
            model = [CHChannelModel modelWithCID:[res dataForColumnIndex:0].base64 name:[res stringForColumnIndex:1] icon:[res stringForColumnIndex:2]];
            model.mute = [res boolForColumnIndex:3];
            model.mid = [res stringForColumnIndex:4];
        }
        [res close];
        [res setParentDB:nil];
    }];
    return model;
}

- (NSArray<CHMessageModel *> *)messageWithCID:(nullable NSString *)cid from:(NSString *)from to:(NSString *)to count:(NSUInteger)count {
    NSData *ccid = [NSData dataFromBase64:cid];
    if (ccid == nil) ccid = [NSData dataFromHex:@kCHDefChanCode];
    __block NSMutableArray<CHMessageModel *> *items = [NSMutableArray arrayWithCapacity:count];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *res = [db executeQuery:@"SELECT `mid`,`raw` FROM `messages` WHERE `cid`=? AND `mid`<? AND `mid`>? ORDER BY `mid` DESC LIMIT ?;", ccid, from, to, @(count)];
        while(res.next) {
            CHMessageModel *model = [CHMessageModel modelWithData:[res dataForColumnIndex:1] mid:[res stringForColumnIndex:0]];
            if (model != nil) {
                [items addObject:model];
            }
        }
        [res close];
        [res setParentDB:nil];
    }];
    return items;
}

- (nullable CHMessageModel *)messageWithMID:(NSString *)mid {
    __block CHMessageModel *model = nil;
    if (mid.length > 0) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            NSData *data = [db dataForQuery:@"SELECT `raw` FROM `messages` WHERE `mid`=? LIMIT 1;", mid];
            model = [CHMessageModel modelWithData:data mid:mid];
        }];
    }
    return model;
}

- (BOOL)upsertMessageData:(NSData *)data mid:(NSString *)mid cid:(NSString **)cid {
    __block BOOL res = NO;
    if (mid.length > 0) {
        NSData *raw = nil;
        CHMessageModel *model = [CHMessageModel modelWithKey:self.srvkey mid:mid data:data raw:&raw];
        if (model != nil) {
            __block NSString *cidStr = nil;
            [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSData *ccid = model.channel;
                res = [db executeUpdate:@"INSERT OR IGNORE INTO `messages`(`mid`,`cid`,`from`,`raw`) VALUES(?,?,?,?);", mid, ccid, model.from, raw];
                if (!res) {
                    *rollback = YES;
                } else {
                    NSString *oldMid = nil;
                    BOOL chanFound = NO;
                    FMResultSet *result = [db executeQuery:@"SELECT `mid` FROM `channels` WHERE `cid`=? AND `deleted`=0 LIMIT 1;", ccid];
                    if (result.next) {
                        oldMid = [result stringForColumnIndex:0];
                        chanFound = YES;
                    }
                    [result close];
                    [result setParentDB:nil];
                    if (!chanFound) {
                        if([db executeUpdate:@"INSERT INTO `channels`(`cid`,`mid`) VALUES(?,?) ON CONFLICT(`cid`) DO UPDATE SET `mid`=excluded.`mid`,`deleted`=0;", ccid, mid]) {
                            cidStr = ccid.base64;
                        }
                    }
                    if (oldMid.length <= 0 || [oldMid compare:mid] == NSOrderedAscending) {
                        [db executeUpdate:@"UPDATE `channels` SET `mid`=? WHERE `cid`=?;", mid, ccid];
                    }
                }
            }];
            if (cid != nil && cidStr.length > 0) {
                *cid = cidStr;
            }
        }
    }
    return res;
}


@end
