//
//  CHMock.m
//  Chanify
//
//  Created by WizJin on 2021/2/9.
//

#import "CHMock.h"
#if TARGET_OS_SIMULATOR
#import "CHNSDataSource.h"
#import "CHLogic.h"
#import "CHCrpyto.h"
#import "CHTP.pbobjc.h"

NSDictionary *try_mock_notification(NSDictionary* info) {
    CHUserModel *me = CHLogic.shared.me;
    NSString *uid = me.uid;
    uint64_t mid = get_utc_time64();
    CHTPMsgContent *content = [CHTPMsgContent new];
    content.type = CHTPMsgType_Text;
    content.text = [info valueForKeyPath:@"aps.alert.body"];
    CHTPMessage *msg = [CHTPMessage new];
    msg.channel = [NSData dataFromHex:@"0801"];
    msg.content = content.data;
    NSData *payload = msg.data;
    NSMutableData *nonce = [NSMutableData dataWithLength:kCHAesGcmNonceBytes];
    uint8_t *ptr = (uint8_t *)nonce.mutableBytes;
    ptr[0] = 0x01;
    ptr[1] = 0x01;
    ptr[2] = 0x00;
    ptr[2] = 0x08;
    *(uint64_t *)(ptr + 4) = CFSwapInt64BigToHost(mid);
    CHNSDataSource *nsDS = CHLogic.shared.nsDataSource;
    NSData *key = [nsDS keyForUID:uid];
    NSData *data = [CHCrpyto aesSealWithKey:[key subdataWithRange:NSMakeRange(0, kCHAesGcmKeyBytes)] data:payload nonce:nonce auth:[key subdataWithRange:NSMakeRange(kCHAesGcmKeyBytes, key.length - kCHAesGcmKeyBytes)]];
    [nsDS pushMessage:data mid:mid uid:uid];
    return @{
        @"uid": uid,
        @"msg": data.base64,
    };
}

#endif
