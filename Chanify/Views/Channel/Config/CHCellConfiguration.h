//
//  CHCellConfiguration.h
//  Chanify
//
//  Created by WizJin on 2021/2/8.
//

#import <UIKit/UIKit.h>
#import "CHMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface CHCellConfiguration : NSObject<UIContentConfiguration>

@property (nonatomic, readonly, strong) NSString *mid;

+ (instancetype)cellConfiguration:(CHMessageModel *)model;
+ (NSDictionary<NSString *, UICollectionViewCellRegistration *> *)cellRegistrations;
- (instancetype)initWithMID:(NSString *)mid;
- (NSDate *)date;
- (void)setNeedRecalcLayout;
- (CGFloat)calcHeight:(CGSize)size;


@end

NS_ASSUME_NONNULL_END
