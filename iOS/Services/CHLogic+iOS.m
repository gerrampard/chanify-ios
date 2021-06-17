//
//  CHLogic+iOS.m
//  Chanify
//
//  Created by WizJin on 2021/4/21.
//

#import "CHLogic+iOS.h"
#import <WatchConnectivity/WatchConnectivity.h>
#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CHUserDataSource.h"
#import "CHNSDataSource.h"
#import "CHMessageModel.h"
#import "CHChannelModel.h"
#import "CHNodeModel.h"
#import "CHNotification+Badge.h"
#import "CHDevice.h"
#import "CHRouter.h"
#import "CHWidget.h"
#import "CHToken.h"
#import "CHMock.h"
#import "CHTP.pbobjc.h"

@interface CHLogic () <WCSessionDelegate, CHNotificationMessageDelegate>

@property (nonatomic, readonly, strong) WCSession *watchSession;

@end

@implementation CHLogic

+ (instancetype)shared {
    static CHLogic *logic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logic = [CHLogic new];
    });
    return logic;
}

- (instancetype)init {
    if (self = [super initWithAppGroup:@kCHAppGroupName]) {
        if (!WCSession.isSupported) {
            _watchSession = nil;
        } else {
            _watchSession = WCSession.defaultSession;
            self.watchSession.delegate = self;
        }
        CHNotification.shared.delegate = self;
    }
    return self;
}

- (void)launch {
    [super launch];
    [self.watchSession activateSession];
}

- (void)active {
    [super active];
    [self updatePushMessage:NO];
    [self reloadBadge];
}

- (void)deactive {
    [CHWidget.shared reloadIfNeeded];
    [self reloadBadge];
    [super deactive];
}

- (BOOL)recivePushMessage:(NSDictionary *)userInfo {
    // TODO: Remove this update call.
    [self updatePushMessage:YES];

    BOOL res = NO;
    NSData *data = nil;
    NSString *mid = nil;
    NSString *uid = [CHMessageModel parsePacket:userInfo mid:&mid data:&data];
    if (uid.length > 0 && [uid isEqualToString:self.me.uid] && mid.length > 0 && data.length > 0) {
        CHUpsertMessageFlags flags= 0;
        CHMessageModel *model = [self.userDataSource upsertMessageData:data nsDB:self.nsDataSource uid:uid mid:mid checker:^BOOL(NSString * _Nonnull cid) {
            return ![self isReadChannel:cid];
        } flags:&flags];
        if (model != nil) {
            if (flags & CHUpsertMessageFlagChannel) {
                [self sendNotifyWithSelector:@selector(logicChannelUpdated:) withObject:model.channel.base64];
            }
            [self sendNotifyWithSelector:@selector(logicMessagesUpdated:) withObject:@[mid]];
            if (flags & CHUpsertMessageFlagUnread) {
                // TODO: Fix calc unread count
                [self sendNotifyWithSelector:@selector(logicMessagesUnreadChanged:) withObject:@(self.userDataSource.unreadSumAllChannel)];
            }
            res = YES;
        }
    }
    return res;
}

#pragma mark - API
- (void)createAccountWithCompletion:(nullable CHLogicBlock)completion {
    [self bindAccount:[CHSecKey new] completion:completion];
}

- (void)doLogin:(CHUserModel *)user key:(NSData *)key {
    [super doLogin:user key:key];
    [self updatePushMessage:NO];
    // TODO: wait seckey sync to Apple Watch
    [self syncDataToWatch:NO];
}

- (void)doLogout {
    [super doLogout];
    [self updateBadge:0];
    [self syncDataToWatch:NO];
}

#pragma mark - Nodes
- (void)reconnectNode:(nullable NSString *)nid completion:(nullable CHLogicBlock)completion {
    if (nid.length > 0) {
        CHNodeModel *node = [self.userDataSource nodeWithNID:nid];
        if (node.isStoreDevice) {
            [self updatePushToken:CHNotification.shared.pushToken node:node completion:completion];
            return;
        }
    }
    call_completion(completion, CHLCodeFailed);
}

#pragma mark - Watch
- (BOOL)hasWatch {
    return (self.watchSession != nil && self.watchSession.activationState == WCSessionActivationStateActivated && self.watchSession.isPaired);
}

- (BOOL)isWatchAppInstalled {
    return (self.hasWatch && self.watchSession.isWatchAppInstalled);
}

- (BOOL)syncDataToWatch:(BOOL)focus {
    BOOL res = NO;
    if (self.isWatchAppInstalled) {
        res = [self.watchSession updateApplicationContext:@{
            @"last": @(focus ? NSDate.date.timeIntervalSince1970 : 0),
            @"data": self.watchSyncedData,
        } error:nil];
    }
    return res;
}

#pragma mark - WCSessionDelegate
- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
}

- (void)sessionWatchStateDidChange:(WCSession *)session {
    [self sendNotifyWithSelector:@selector(logicWatchStatusChanged)];
    if (self.isWatchAppInstalled) {
        [self syncDataToWatch:NO];
    }
}

- (void)sessionDidBecomeInactive:(WCSession *)session {
}

- (void)sessionDidDeactivate:(WCSession *)session {
}

#pragma mark - CHNotificationMessageDelegate
- (void)registerForRemoteNotifications {
    dispatch_main_async(^{
        [UIApplication.sharedApplication registerForRemoteNotifications];
    });
}

- (void)receiveNotification:(UNNotification *)notification {
    [self recivePushMessage:try_mock_notification(notification.request.content.userInfo)];
}

- (void)receiveNotificationResponse:(UNNotificationResponse *)response {
    NSString *mid = nil;
    NSDictionary *info = try_mock_notification(response.notification.request.content.userInfo);
    NSString *uid = [CHMessageModel parsePacket:info mid:&mid data:nil];
    if (uid.length > 0 && mid.length > 0) {
        CHLogI("Launch with message %u", mid);
        [self recivePushMessage:info];
        CHMessageModel *model = [self.userDataSource messageWithMID:mid];
        if (model.channel.length > 0) {
            NSString *cid = model.channel.base64;
            dispatch_main_async(^{
                [CHRouter.shared routeTo:@"/page/channel" withParams:@{ @"cid": cid, @"singleton": @YES, @"show": @"detail" }];
            });
        }
    }
}

#pragma mark - Subclass Methods
- (void)reloadUserDB:(BOOL)force {
    [super reloadUserDB:force];
    [CHWidget.shared reloadDB:self.me.uid];
}

- (void)sendBlockTokenChanged {
    [super sendBlockTokenChanged];
    [self syncDataToWatch:NO];
}

#pragma mark - Private Methods
- (void)updatePushMessage:(BOOL)alert {
    NSString *uid = self.me.uid;
    if (uid.length > 0) {
        __block BOOL unreadChanged = NO;
        __block BOOL needAlertUnread= NO;
        NSMutableSet<NSString *> *cids = [NSMutableSet new];
        NSMutableArray<NSString *> *mids = [NSMutableArray new];
        [self.nsDataSource enumerateMessagesWithUID:uid block:^(FMDatabase *db, NSString *mid, NSData *data) {
            CHUpsertMessageFlags flags = 0;
            CHMessageModel *msg = [self.userDataSource upsertMessageData:data nsDB:[CHTempNSDatasource datasourceFromDB:db] uid:uid mid:mid checker:^BOOL(NSString * _Nonnull cid) {
                return ![self isReadChannel:cid];
            } flags:&flags];
            if (msg != nil) {
                if (flags & CHUpsertMessageFlagChannel) {
                    [cids addObject:msg.channel.base64];
                }
                if (flags & CHUpsertMessageFlagUnread) {
                    unreadChanged = YES;
                    if ([msg.sound boolValue] > 0) {
                        needAlertUnread = YES;
                    }
                }
            }
            if (mid.length > 0) {
                [mids addObject:mid];
            }
        }];
        if (mids.count > 0) {
            [self.nsDataSource removeMessages:mids uid:uid];
            [self sendNotifyWithSelector:@selector(logicMessagesUpdated:) withObject:mids];
        }
        [self.nsDataSource flush];
        if (cids.count > 0) {
            [self sendNotifyWithSelector:@selector(logicChannelsUpdated:) withObject:cids.allObjects];
        }
        if (unreadChanged) {
            // TODO: Fix calc unread count
            [self sendNotifyWithSelector:@selector(logicMessagesUnreadChanged:) withObject:@(self.userDataSource.unreadSumAllChannel)];
        }
        if (alert && needAlertUnread) {
            [self sendAlertNewMessage];
        }
    }
}

- (NSData *)watchSyncedData {
    CHTPWatchConfig *cfg = [CHTPWatchConfig new];
    CHUserModel *me = self.me;
    if (me != nil) {
        cfg.userKey = me.key.seckey;
        for (CHNodeModel *node in self.userDataSource.loadNodes) {
            if (node.isSupportWatch && !node.isSystem) {
                CHTPNode *n = [CHTPNode new];
                n.nid = node.nid;
                n.flags = node.flags;
                n.name = node.name;
                n.version = node.version;
                n.endpoint = node.endpoint;
                n.icon = node.icon;
                n.pubkey = node.pubkey;
                [cfg.nodesArray addObject:n];
            }
        }
        for (NSString *token in self.blockedTokens) {
            CHToken *tk = [CHToken tokenWithString:token];
            if (!tk.isExpired) {
                CHTPBlockItem *item = [CHTPBlockItem new];
                item.token = token;
                [cfg.blocklistArray addObject:item];
            }
        }
    }
    return cfg.data;
}

- (void)reloadBadge {
    NSInteger badge = 0;
    if (self.userDataSource != nil) {
        NSMutableArray<NSString *> *cids = [NSMutableArray new];
        for (NSString *cid in self.readChannelIDs) {
            if ([self.userDataSource clearUnreadWithChannel:cid]) {
                [cids addObject:cid];
            }
        }
        badge = [self.userDataSource unreadSumAllChannel];
        if (cids.count > 0) {
            [self sendNotifyWithSelector:@selector(logicChannelsUpdated:) withObject:cids];
            [self sendNotifyWithSelector:@selector(logicMessagesUnreadChanged:) withObject:@(badge)];
        }
    }
    [self updateBadge:badge];
}

- (void)updateBadge:(NSInteger)badge {
    CHNotification.shared.notificationBadge = badge;
    [self.nsDataSource updateBadge:badge uid:self.me.uid];
}

- (BOOL)clearUnreadWithChannel:(nullable NSString *)cid {
    BOOL res = [self.userDataSource clearUnreadWithChannel:cid];
    if (res) {
        [self sendNotifyWithSelector:@selector(logicChannelUpdated:) withObject:cid];
        // TODO: Fix calc unread count
        [self sendNotifyWithSelector:@selector(logicMessagesUnreadChanged:) withObject:@(self.userDataSource.unreadSumAllChannel)];
    }
    return res;
}

- (void)sendAlertNewMessage {
    dispatch_main_async(^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            AudioServicesPlaySystemSound(1007);
        }
    });
}

static inline void call_completion(CHLogicBlock completion, CHLCode result) {
    if (completion != nil) {
        dispatch_main_async(^{
            completion(result);
        });
    }
}


@end
