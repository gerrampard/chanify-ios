//
//  CHBlockeModel.m
//  Chanify
//
//  Created by WizJin on 2021/6/5.
//

#import "CHBlockeModel.h"
#import "CHToken.h"

@interface CHBlockeModel ()

@property (nonatomic, nullable, strong) CHToken *token;

@end

@implementation CHBlockeModel

+ (instancetype)modelWithRaw:(NSString *)raw {
    return [[self.class alloc] initWithRaw:raw];
}

- (instancetype)initWithRaw:(NSString *)raw {
    if (self = [super init]) {
        _raw = raw;
        _token = [CHToken tokenWithString:raw];
    }
    return self;
}

- (nullable NSDate *)expired {
    NSDate *date = nil;
    if (self.token != nil) {
        date = self.token.expired;
    }
    return date;
}

- (nullable NSData *)channel {
    NSData *chan = nil;
    if (self.token != nil) {
        chan = self.token.channel;
    }
    return chan;
}

- (BOOL)isEqual:(CHBlockeModel *)rhs {
    return [self.raw isEqualToString:rhs.raw];
}

- (NSUInteger)hash {
    return self.raw.hash;
}


@end