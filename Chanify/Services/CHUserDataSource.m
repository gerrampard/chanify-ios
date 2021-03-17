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
#import "CHNodeModel.h"
#import "CHLogic.h"

#define kCHDefChanCode  "0801"
#define kCHNSInitSql    \
    "CREATE TABLE IF NOT EXISTS `options`(`key` TEXT PRIMARY KEY,`value` BLOB);"   \
    "CREATE TABLE IF NOT EXISTS `messages`(`mid` TEXT PRIMARY KEY,`cid` BLOB,`from` TEXT,`raw` BLOB);"  \
    "CREATE TABLE IF NOT EXISTS `channels`(`cid` BLOB PRIMARY KEY,`deleted` BOOLEAN DEFAULT 0,`name` TEXT,`icon` TEXT,`unread` UNSIGNED INTEGER,`mute` BOOLEAN,`mid` TEXT);"   \
    "CREATE TABLE IF NOT EXISTS `nodes`(`nid` TEXT PRIMARY KEY,`deleted` BOOLEAN DEFAULT 0,`name` TEXT,`endpoint` TEXT,`icon` TEXT,`flags` INTEGER DEFAULT 0,`features` TEXT,`secret` BLOB);" \
    "INSERT OR IGNORE INTO `channels`(`cid`) VALUES(X'0801');"      \
    "INSERT OR IGNORE INTO `channels`(`cid`) VALUES(X'08011001');"  \
    "INSERT OR IGNORE INTO `nodes`(`nid`,`features`) VALUES(\"sys\",\"store.device,msg.text\");"  \

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
            if (db.applicationID < 1) {
                // Fix data
                if (![db columnExists:@"flags" inTableWithName:@"nodes"]) {
                    if ([db executeStatements:@"ALTER TABLE `nodes` ADD COLUMN `flags` INTEGER DEFAULT 0;"]) {
                        db.applicationID = 1;
                    }
                }
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

- (BOOL)insertNode:(CHNodeModel *)model secret:(NSData *)secret {
    __block BOOL res = NO;
    if (model != nil) {
        [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            res = [db executeUpdate:@"INSERT INTO `nodes`(`nid`,`name`,`endpoint`,`icon`,`flags`,`features`,`secret`) VALUES(?,?,?,?,?,?,?) ON CONFLICT(`nid`) DO UPDATE SET `name`=excluded.`name`,`endpoint`=excluded.`endpoint`,`icon`=excluded.`icon`,`flags`=excluded.`flags`,`features`=excluded.`features`,`secret`=excluded.`secret`,`deleted`=0;", model.nid, model.name, model.endpoint, model.icon, @(model.flags), [model.features componentsJoinedByString:@","], secret];
        }];
    }
    return res;
}

- (BOOL)updateNode:(CHNodeModel *)model {
    __block BOOL res = NO;
    if (model != nil) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            res = [db executeUpdate:@"UPDATE `nodes` SET `name`=?,`endpoint`=?,`icon`=?,`flags`=?,`features`=? WHERE `nid`=? LIMIT 1;", model.name, model.endpoint, model.icon, @(model.flags), [model.features componentsJoinedByString:@","], model.nid];
        }];
    }
    return res;
}

- (BOOL)deleteNode:(nullable NSString *)nid {
    __block BOOL res = NO;
    if (nid.length > 0) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            res = [db executeUpdate:@"UPDATE `nodes` SET `deleted`=1 WHERE `nid`=? LIMIT 1;", nid];
        }];
    }
    return res;
}

- (nullable NSData *)keyForNodeID:(nullable NSString *)nid {
    __block NSData *res = nil;
    if (nid.length > 0) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            res = [db dataForQuery:@"SELECT `secret` FROM `nodes` WHERE `nid`=? LIMIT 1;", nid];
        }];
    }
    return res;
}

- (NSArray<CHNodeModel *> *)loadNodes {
    __block NSMutableArray<CHNodeModel *> *nodes = [NSMutableArray new];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *res = [db executeQuery:@"SELECT `nid`,`name`,`endpoint`,`flags`,`features`,`icon` FROM `nodes` WHERE `deleted`=0;"];
        while(res.next) {
            CHNodeModel *model = [CHNodeModel modelWithNID:[res stringForColumnIndex:0] name:[res stringForColumnIndex:1] endpoint:[res stringForColumnIndex:2] flags:[res unsignedLongLongIntForColumnIndex:3] features:[res stringForColumnIndex:4]];
            if (model != nil) {
                model.icon = [res stringForColumnIndex:5];
                [nodes addObject:model];
            }
        }
        [res close];
        [res setParentDB:nil];
    }];
    return nodes;
}

- (nullable CHNodeModel *)nodeWithNID:(nullable NSString *)nid {
    __block CHNodeModel *model = nil;
    if (nid == nil) nid = @"";
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *res = [db executeQuery:@"SELECT `nid`,`name`,`endpoint`,`flags`,`features`,`icon` FROM `nodes` WHERE `nid`=? AND `deleted`=0; LIMIT 1;", nid];
        if (res.next) {
            model = [CHNodeModel modelWithNID:[res stringForColumnIndex:0] name:[res stringForColumnIndex:1] endpoint:[res stringForColumnIndex:2] flags:[res unsignedLongLongIntForColumnIndex:3] features:[res stringForColumnIndex:4]];
            if (model != nil) {
                model.icon = [res stringForColumnIndex:5];
            }
        }
        [res close];
        [res setParentDB:nil];
    }];
    return model;
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
                model.unread = [res boolForColumnIndex:3];
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
            if (model != nil) {
                model.unread = [res boolForColumnIndex:3];
                model.mid = [res stringForColumnIndex:4];
            }
        }
        [res close];
        [res setParentDB:nil];
    }];
    return model;
}

- (BOOL)deleteMessage:(NSString *)mid {
    if (mid.length > 0) {
        [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            NSData *cid = [db dataForQuery:@"SELECT `cid` FROM `channels` WHERE `mid`=? LIMIT 1;", mid];
            [db executeUpdate:@"DELETE FROM `messages` WHERE `mid`=? LIMIT 1;", mid];
            if (cid.length > 0) {
                NSString *msg = [db stringForQuery:@"SELECT `mid` FROM `messages` WHERE `cid`=? AND `mid`<? ORDER BY `mid` DESC LIMIT 1;", cid, mid];
                [db executeUpdate:@"UPDATE `channels` SET `mid`=? WHERE `cid`=?;", msg, cid];
            }
        }];
    }
    return YES;
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

- (nullable CHMessageModel *)messageWithMID:(nullable NSString *)mid {
    __block CHMessageModel *model = nil;
    if (mid.length > 0) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            NSData *data = [db dataForQuery:@"SELECT `raw` FROM `messages` WHERE `mid`=? LIMIT 1;", mid];
            model = [CHMessageModel modelWithData:data mid:mid];
        }];
    }
    return model;
}

- (BOOL)upsertMessageData:(NSData *)data uid:(NSString *)uid mid:(NSString *)mid cid:(NSString **)cid {
    __block BOOL res = NO;
    if (mid.length > 0) {
        NSData *raw = nil;
        CHMessageModel *model = [CHMessageModel modelWithKey:self.srvkey ds:CHLogic.shared.userDataSource mid:mid data:data raw:&raw];
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
