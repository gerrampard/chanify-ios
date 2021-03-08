//
//  CHIconsViewController.m
//  Chanify
//
//  Created by WizJin on 2021/3/7.
//

#import "CHIconsViewController.h"
#import <Masonry/Masonry.h>
#import "CHIconConfiguration.h"
#import "CHColorConfiguration.h"
#import "CHIconView.h"
#import "CHTheme.h"

typedef UICollectionViewDiffableDataSource<NSString *, NSString *> CHIconDataSource;
typedef NSDiffableDataSourceSnapshot<NSString *, NSString *> CHIconDiffableSnapshot;

@interface CHIconsViewController () <UICollectionViewDelegate>

@property (nonatomic, readonly, strong) NSString *iconImage;
@property (nonatomic, readonly, strong) CHIconView *iconView;
@property (nonatomic, readonly, strong) UICollectionView *shapesView;
@property (nonatomic, readonly, strong) UICollectionView *colorsView;
@property (nonatomic, readonly, strong) UICollectionView *bgrndsView;
@property (nonatomic, readonly, strong) CHIconDataSource *shapesDataSource;
@property (nonatomic, readonly, strong) CHIconDataSource *colorsDataSource;
@property (nonatomic, readonly, strong) CHIconDataSource *bgrndsDataSource;
@property (nonatomic, readonly, strong) NSArray<UIView *> *panelViews;
@property (nonatomic, readonly, strong) UISegmentedControl *segmentedControl;

@end

@implementation CHIconsViewController

- (instancetype)initWithParameters:(NSDictionary *)params {
    if (self = [super init]) {
        _iconImage = [params valueForKey:@"icon"] ?: @"";
    }
    return self;
}

- (instancetype)initWithIcon:(NSString *)icon {
    return [self initWithParameters:@{ @"icon": icon }];
}

- (void)dealloc {
    if (self.delegate != nil) {
        [self.delegate iconChanged:self.iconView.image];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CHTheme *theme = CHTheme.shared;
    
    self.title = @"Icon".localized;
    
    self.view.backgroundColor = theme.groupedBackgroundColor;
    
    UIView *panel = [UIView new];
    [self.view addSubview:panel];
    [panel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.height.equalTo(self.view.mas_height).multipliedBy(0.4);
        make.left.right.equalTo(self.view);
    }];
    
    CHIconView *iconView = [CHIconView new];
    [panel addSubview:(_iconView = iconView)];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(panel);
        make.size.mas_equalTo(CGSizeMake(128, 128));
    }];
    iconView.image = self.iconImage;

    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Shape".localized, @"Color".localized, @"Background".localized]];
    [self.view addSubview:(_segmentedControl = segmentedControl)];
    [segmentedControl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(panel.mas_bottom);
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(40);
    }];
    [segmentedControl addTarget:self action:@selector(actionSegmentChanged:) forControlEvents:UIControlEventValueChanged];

    _panelViews = @[self.shapesCollectionView, self.colorsCollectionView, self.bgrndsCollectionView];
    NSInteger i = 0;
    for (UIView *view in self.panelViews) {
        view.tag = i++;
    }
    segmentedControl.selectedSegmentIndex = 0;
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    if (collectionView.tag == 0) {
        NSString *item = [self.shapesDataSource itemIdentifierForIndexPath:indexPath];
        if (item.length <= 0) {
            self.iconView.image = @"";
        } else {
            NSURLComponents *components = [NSURLComponents componentsWithString:self.iconView.image];
            if (![components.scheme isEqualToString:@"sys"]) {
                components.scheme = @"sys";
            }
            components.host = [self.shapesDataSource itemIdentifierForIndexPath:indexPath];
            self.iconView.image = components.URL.absoluteString;
        }
    } else if (collectionView.tag == 1) {
        NSString *item = [self.colorsDataSource itemIdentifierForIndexPath:indexPath];
        NSURLComponents *components = [NSURLComponents componentsWithString:self.iconView.image];
        components.scheme = @"sys";
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray new];
        for (NSURLQueryItem *itm in components.queryItems) {
            if (![itm.name isEqualToString:@"c"]) {
                [items addObject:itm];
            }
        }
        if (item.length > 0) {
            [items addObject:[NSURLQueryItem queryItemWithName:@"c" value:item]];
        }
        if (components.host.length <= 0 && items.count <= 0) {
            self.iconView.image = @"";
        } else {
            components.queryItems = (items.count > 0 ? items : nil);
            self.iconView.image = components.URL.absoluteString;
        }
    } else if (collectionView.tag == 2) {
        NSString *item = [self.bgrndsDataSource itemIdentifierForIndexPath:indexPath];
        NSURLComponents *components = [NSURLComponents componentsWithString:self.iconView.image];
        components.scheme = @"sys";
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray new];
        for (NSURLQueryItem *itm in components.queryItems) {
            if (![itm.name isEqualToString:@"b"]) {
                [items addObject:itm];
            }
        }
        if (item.length > 0) {
            [items addObject:[NSURLQueryItem queryItemWithName:@"b" value:item]];
        }
        if (components.host.length <= 0 && items.count <= 0) {
            self.iconView.image = @"";
        } else {
            components.queryItems = (items.count > 0 ? items : nil);
            self.iconView.image = components.URL.absoluteString;
        }
    }
}

#pragma mark - Action Methods
- (void)actionSegmentChanged:(UISegmentedControl *)segment {
    NSInteger selected = segment.selectedSegmentIndex;
    for (NSInteger i = 0; i < self.panelViews.count; i++) {
        [[self.panelViews objectAtIndex:i] setHidden:(selected != i ? YES : NO)];
    }
}

#pragma mark - Private Methods
- (UICollectionView *)shapesCollectionView {
    if (_shapesView == nil) {
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
        layout.minimumInteritemSpacing = 5;
        layout.minimumLineSpacing = 10;
        UICollectionView *shapesView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        [self.view addSubview:(_shapesView = shapesView)];
        [shapesView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.segmentedControl.mas_bottom);
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
            make.left.right.equalTo(self.view);
        }];
        shapesView.backgroundColor = CHTheme.shared.groupedBackgroundColor;
        shapesView.alwaysBounceHorizontal = YES;
        shapesView.pagingEnabled = YES;
        shapesView.delegate = self;

        UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewCell.class configurationHandler:^(UICollectionViewCell *cell, NSIndexPath *indexPath, NSString *item) {
            NSString *icon = (item.length > 0 ? [@"sys://" stringByAppendingString:item] : @"");
            cell.contentConfiguration = [CHIconConfiguration configurationWithIcon:icon];
        }];
        _shapesDataSource = [[CHIconDataSource alloc] initWithCollectionView:shapesView cellProvider:^UICollectionViewCell *(UICollectionView *collectionView, NSIndexPath *indexPath, NSString *item) {
            return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:item];
        }];

        CHIconDiffableSnapshot *snapshot = [CHIconDiffableSnapshot new];
        [snapshot appendSectionsWithIdentifiers:@[@""]];
        [snapshot appendItemsWithIdentifiers:self.icons];
        [self.shapesDataSource applySnapshot:snapshot animatingDifferences:NO];
    }
    return _shapesView;
}

- (UICollectionView *)colorsCollectionView {
    if (_colorsView == nil) {
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
        layout.minimumInteritemSpacing = 5;
        layout.minimumLineSpacing = 10;
        UICollectionView *colorsView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        [self.view addSubview:(_colorsView = colorsView)];
        [colorsView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.segmentedControl.mas_bottom);
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
            make.left.right.equalTo(self.view);
        }];
        colorsView.backgroundColor = CHTheme.shared.groupedBackgroundColor;
        colorsView.alwaysBounceHorizontal = YES;
        colorsView.pagingEnabled = YES;
        colorsView.delegate = self;
        [colorsView setHidden:YES];

        UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewCell.class configurationHandler:^(UICollectionViewCell *cell, NSIndexPath *indexPath, NSString *item) {
            CHColorConfiguration *colorConfiguration = [CHColorConfiguration configurationWithColor:item];
            colorConfiguration.defaultColor = UIColor.whiteColor;
            cell.contentConfiguration = colorConfiguration;
        }];
        _colorsDataSource = [[CHIconDataSource alloc] initWithCollectionView:colorsView cellProvider:^UICollectionViewCell *(UICollectionView *collectionView, NSIndexPath *indexPath, NSString *item) {
            return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:item];
        }];

        CHIconDiffableSnapshot *snapshot = [CHIconDiffableSnapshot new];
        [snapshot appendSectionsWithIdentifiers:@[@""]];
        [snapshot appendItemsWithIdentifiers:self.colors];
        [self.colorsDataSource applySnapshot:snapshot animatingDifferences:NO];
    }
    return _colorsView;
}

- (UICollectionView *)bgrndsCollectionView {
    if (_bgrndsView == nil) {
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
        layout.minimumInteritemSpacing = 5;
        layout.minimumLineSpacing = 10;
        UICollectionView *bgrndsView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        [self.view addSubview:(_bgrndsView = bgrndsView)];
        [bgrndsView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.segmentedControl.mas_bottom);
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
            make.left.right.equalTo(self.view);
        }];
        bgrndsView.backgroundColor = CHTheme.shared.groupedBackgroundColor;
        bgrndsView.alwaysBounceHorizontal = YES;
        bgrndsView.pagingEnabled = YES;
        bgrndsView.delegate = self;
        [bgrndsView setHidden:YES];

        UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewCell.class configurationHandler:^(UICollectionViewCell *cell, NSIndexPath *indexPath, NSString *item) {
            CHColorConfiguration *colorConfiguration = [CHColorConfiguration configurationWithColor:item];
            colorConfiguration.defaultColor = CHTheme.shared.tintColor;
            cell.contentConfiguration = colorConfiguration;
        }];
        _bgrndsDataSource = [[CHIconDataSource alloc] initWithCollectionView:bgrndsView cellProvider:^UICollectionViewCell *(UICollectionView *collectionView, NSIndexPath *indexPath, NSString *item) {
            return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:item];
        }];

        CHIconDiffableSnapshot *snapshot = [CHIconDiffableSnapshot new];
        [snapshot appendSectionsWithIdentifiers:@[@""]];
        [snapshot appendItemsWithIdentifiers:self.bgrnds];
        [self.bgrndsDataSource applySnapshot:snapshot animatingDifferences:NO];
    }
    return _bgrndsView;
}

- (NSArray<NSString *> *)colors {
    return @[
        @"",
        @"000000",
        @"007aff",
        @"34c759",
        @"5856d6",
        @"ff9500",
        @"ff2d55",
        @"af52de",
        @"ff3b30",
        @"ffcc00",
    ];
}

- (NSArray<NSString *> *)bgrnds {
    return @[
        @"",
        @"000000",
        @"ffffff",
        @"34c759",
        @"5856d6",
        @"ff9500",
        @"ff2d55",
        @"af52de",
        @"ff3b30",
        @"ffcc00",
        @"264653",
        @"2a9d8f",
        @"e9c46a",
        @"f4a261",
        @"fde8cd",
        @"e76f51",
        @"433520",
        @"025955",
        @"440a67",
        @"93329e",
        @"b4aee8",
        @"ffe3fe",
        @"c8c6a7",
        @"92967d",
        @"6e7c7c",
        @"435560",
        @"ffefa1",
        @"94ebcd",
        @"6ddccf",
        @"822659",
        @"b34180",
        @"e36bae",
        @"f8a1d1",
        @"493323",
        @"91684a",
        @"eaac7f",
        @"ffdf91",
        @"52057b",
        @"892cdc",
        @"bc6ff1",
        @"e23e57",
        @"522546",
        @"3490de",
        @"769fcd",
        @"b9d7ea",
        @"d6e6f2",
    ];
}

- (NSArray<NSString *> *)icons {
    return @[
        @"",
        @"a.circle",
        @"a.circle.fill",
        @"a.magnify",
        @"a.square",
        @"a.square.fill",
        @"abc",
        @"airplane",
        @"airplane.circle",
        @"airplane.circle.fill",
        @"alarm",
        @"alarm.fill",
        @"alt",
        @"amplifier",
        @"ant",
        @"ant.circle",
        @"ant.circle.fill",
        @"ant.fill",
        @"antenna.radiowaves.left.and.right",
        @"app",
        @"app.badge",
        @"app.badge.fill",
        @"app.gift",
        @"app.gift.fill",
        @"apps.ipad",
        @"apps.ipad.landscape",
        @"apps.iphone",
        @"apps.iphone.badge.plus",
        @"apps.iphone.landscape",
        @"aqi.high",
        @"aqi.low",
        @"aqi.medium",
        @"archivebox",
        @"archivebox.circle",
        @"archivebox.circle.fill",
        @"archivebox.fill",
        @"aspectratio",
        @"aspectratio.fill",
        @"asterisk.circle",
        @"asterisk.circle.fill",
        @"at",
        @"at.badge.minus",
        @"at.badge.plus",
        @"at.circle",
        @"at.circle.fill",
        @"atom",
        @"australsign.circle",
        @"australsign.circle.fill",
        @"australsign.square",
        @"australsign.square.fill",
        @"b.circle",
        @"b.circle.fill",
        @"b.square",
        @"b.square.fill",
        @"badge.plus.radiowaves.forward",
        @"badge.plus.radiowaves.right",
        @"bag",
        @"bag.badge.minus",
        @"bag.badge.plus",
        @"bag.circle",
        @"bag.circle.fill",
        @"bag.fill",
        @"bag.fill.badge.minus",
        @"bag.fill.badge.plus",
        @"bahtsign.circle",
        @"bahtsign.circle.fill",
        @"bahtsign.square",
        @"bahtsign.square.fill",
        @"bandage",
        @"bandage.fill",
        @"banknote",
        @"banknote.fill",
        @"barcode",
        @"barcode.viewfinder",
        @"barometer",
        @"battery.0",
        @"battery.25",
        @"battery.100",
        @"battery.100.bolt",
        @"bed.double",
        @"bed.double.fill",
        @"bell",
        @"bell.badge",
        @"bell.badge.fill",
        @"bell.circle",
        @"bell.circle.fill",
        @"bell.fill",
        @"bell.slash",
        @"bell.slash.circle",
        @"bell.slash.circle.fill",
        @"bell.slash.fill",
        @"bicycle",
        @"bicycle.circle",
        @"bicycle.circle.fill",
        @"binoculars",
        @"binoculars.fill",
        @"bitcoinsign.circle",
        @"bitcoinsign.circle.fill",
        @"bitcoinsign.square",
        @"bitcoinsign.square.fill",
        @"bold",
        @"bold.italic.underline",
        @"bold.underline",
        @"bolt",
        @"bolt.badge.a",
        @"bolt.badge.a.fill",
        @"bolt.car",
        @"bolt.car.fill",
        @"bolt.circle",
        @"bolt.circle.fill",
        @"bolt.fill",
        @"bolt.fill.batteryblock",
        @"bolt.fill.batteryblock.fill",
        @"bolt.heart",
        @"bolt.heart.fill",
        @"bolt.horizontal",
        @"bolt.horizontal.circle",
        @"bolt.horizontal.circle.fill",
        @"bolt.horizontal.fill",
        @"bolt.slash",
        @"bolt.slash.circle",
        @"bolt.slash.circle.fill",
        @"bolt.slash.fill",
        @"book",
        @"book.circle",
        @"book.circle.fill",
        @"book.closed",
        @"book.closed.fill",
        @"book.fill",
        @"bookmark",
        @"bookmark.circle",
        @"bookmark.circle.fill",
        @"bookmark.fill",
        @"bookmark.slash",
        @"bookmark.slash.fill",
        @"books.vertical",
        @"books.vertical.fill",
        @"brazilianrealsign.circle",
        @"brazilianrealsign.circle.fill",
        @"brazilianrealsign.square",
        @"brazilianrealsign.square.fill",
        @"briefcase",
        @"briefcase.fill",
        @"bubble.left",
        @"bubble.left.and.bubble.right",
        @"bubble.left.and.bubble.right.fill",
        @"bubble.left.fill",
        @"bubble.middle.bottom",
        @"bubble.middle.bottom.fill",
        @"bubble.middle.top",
        @"bubble.middle.top.fill",
        @"bubble.right",
        @"bubble.right.fill",
        @"building",
        @"building.2",
        @"building.2.crop.circle",
        @"building.2.crop.circle.fill",
        @"building.2.fill",
        @"building.columns",
        @"building.columns.fill",
        @"building.fill",
        @"burn",
        @"burst",
        @"burst.fill",
        @"bus",
        @"bus.doubledecker",
        @"bus.doubledecker.fill",
        @"bus.fill",
        @"c.circle",
        @"c.circle.fill",
        @"c.square",
        @"c.square.fill",
        @"calendar",
        @"calendar.badge.clock",
        @"calendar.badge.exclamationmark",
        @"calendar.badge.minus",
        @"calendar.badge.plus",
        @"calendar.circle",
        @"calendar.circle.fill",
        @"camera",
        @"camera.aperture",
        @"camera.badge.ellipsis",
        @"camera.circle",
        @"camera.circle.fill",
        @"camera.fill",
        @"camera.fill.badge.ellipsis",
        @"camera.filters",
        @"camera.metering.center.weighted",
        @"camera.metering.center.weighted.average",
        @"camera.metering.matrix",
        @"camera.metering.multispot",
        @"camera.metering.none",
        @"camera.metering.partial",
        @"camera.metering.spot",
        @"camera.metering.unknown",
        @"camera.on.rectangle",
        @"camera.on.rectangle.fill",
        @"camera.viewfinder",
        @"candybarphone",
        @"capslock",
        @"capslock.fill",
        @"capsule",
        @"capsule.fill",
        @"capsule.portrait",
        @"capsule.portrait.fill",
        @"captions.bubble",
        @"captions.bubble.fill",
        @"car",
        @"car.2",
        @"car.2.fill",
        @"car.circle",
        @"car.circle.fill",
        @"car.fill",
        @"cart",
        @"cart.badge.minus",
        @"cart.badge.plus",
        @"cart.circle",
        @"cart.circle.fill",
        @"cart.fill",
        @"cart.fill.badge.minus",
        @"cart.fill.badge.plus",
        @"case",
        @"case.fill",
        @"cedisign.circle",
        @"cedisign.circle.fill",
        @"cedisign.square",
        @"cedisign.square.fill",
        @"centsign.circle",
        @"centsign.circle.fill",
        @"centsign.square",
        @"centsign.square.fill",
        @"character",
        @"character.book.closed",
        @"character.book.closed.fill",
        @"chart.bar",
        @"chart.bar.doc.horizontal",
        @"chart.bar.doc.horizontal.fill",
        @"chart.bar.fill",
        @"chart.bar.xaxis",
        @"chart.pie",
        @"chart.pie.fill",
        @"checkerboard.rectangle",
        @"checkmark",
        @"checkmark.circle",
        @"checkmark.circle.fill",
        @"checkmark.rectangle",
        @"checkmark.rectangle.fill",
        @"checkmark.rectangle.portrait",
        @"checkmark.rectangle.portrait.fill",
        @"checkmark.seal",
        @"checkmark.seal.fill",
        @"checkmark.shield",
        @"checkmark.shield.fill",
        @"checkmark.square",
        @"checkmark.square.fill",
        @"circle",
        @"circle.bottomhalf.fill",
        @"circle.circle",
        @"circle.circle.fill",
        @"circle.dashed",
        @"circle.dashed.inset.fill",
        @"circle.fill",
        @"circle.fill.square.fill",
        @"circle.grid.2x2",
        @"circle.grid.2x2.fill",
        @"circle.grid.3x3",
        @"circle.grid.3x3.fill",
        @"circle.grid.cross",
        @"circle.grid.cross.down.fill",
        @"circle.grid.cross.fill",
        @"circle.grid.cross.left.fill",
        @"circle.grid.cross.right.fill",
        @"circle.grid.cross.up.fill",
        @"circle.lefthalf.fill",
        @"circle.righthalf.fill",
        @"circle.square",
        @"circle.tophalf.fill",
        @"circlebadge",
        @"circlebadge.2",
        @"circlebadge.2.fill",
        @"circlebadge.fill",
        @"circles.hexagongrid",
        @"circles.hexagongrid.fill",
        @"circles.hexagonpath",
        @"circles.hexagonpath.fill",
        @"clear",
        @"clear.fill",
        @"clock",
        @"clock.fill",
        @"cloud",
        @"cloud.bolt",
        @"cloud.bolt.fill",
        @"cloud.bolt.rain",
        @"cloud.bolt.rain.fill",
        @"cloud.drizzle",
        @"cloud.drizzle.fill",
        @"cloud.fill",
        @"cloud.fog",
        @"cloud.fog.fill",
        @"cloud.hail",
        @"cloud.hail.fill",
        @"cloud.heavyrain",
        @"cloud.heavyrain.fill",
        @"cloud.moon",
        @"cloud.moon.bolt",
        @"cloud.moon.bolt.fill",
        @"cloud.moon.fill",
        @"cloud.moon.rain",
        @"cloud.moon.rain.fill",
        @"cloud.rain",
        @"cloud.rain.fill",
        @"cloud.sleet",
        @"cloud.sleet.fill",
        @"cloud.snow",
        @"cloud.snow.fill",
        @"cloud.sun",
        @"cloud.sun.bolt",
        @"cloud.sun.bolt.fill",
        @"cloud.sun.fill",
        @"cloud.sun.rain",
        @"cloud.sun.rain.fill",
        @"coloncurrencysign.circle",
        @"coloncurrencysign.circle.fill",
        @"coloncurrencysign.square",
        @"coloncurrencysign.square.fill",
        @"comb",
        @"comb.fill",
        @"command",
        @"command.circle",
        @"command.circle.fill",
        @"command.square",
        @"command.square.fill",
        @"cone",
        @"cone.fill",
        @"control",
        @"cpu",
        @"creditcard",
        @"creditcard.circle",
        @"creditcard.circle.fill",
        @"creditcard.fill",
        @"crop",
        @"crop.rotate",
        @"cross",
        @"cross.case",
        @"cross.case.fill",
        @"cross.circle",
        @"cross.circle.fill",
        @"cross.fill",
        @"crown",
        @"crown.fill",
        @"cruzeirosign.circle",
        @"cruzeirosign.circle.fill",
        @"cruzeirosign.square",
        @"cruzeirosign.square.fill",
        @"cube",
        @"cube.fill",
        @"cube.transparent",
        @"cube.transparent.fill",
        @"curlybraces",
        @"curlybraces.square",
        @"curlybraces.square.fill",
        @"cylinder",
        @"cylinder.fill",
        @"cylinder.split.1x2",
        @"cylinder.split.1x2.fill",
        @"d.circle",
        @"d.circle.fill",
        @"d.square",
        @"d.square.fill",
        @"decrease.indent",
        @"decrease.quotelevel",
        @"deskclock",
        @"deskclock.fill",
        @"desktopcomputer",
        @"dial.max",
        @"dial.max.fill",
        @"dial.min",
        @"dial.min.fill",
        @"diamond",
        @"diamond.fill",
        @"die.face.1",
        @"die.face.1.fill",
        @"die.face.2",
        @"die.face.2.fill",
        @"die.face.3",
        @"die.face.3.fill",
        @"die.face.4",
        @"die.face.4.fill",
        @"die.face.5",
        @"die.face.5.fill",
        @"die.face.6",
        @"die.face.6.fill",
        @"directcurrent",
        @"display",
        @"display.2",
        @"display.trianglebadge.exclamationmark",
        @"divide",
        @"divide.circle",
        @"divide.circle.fill",
        @"divide.square",
        @"divide.square.fill",
        @"doc",
        @"doc.append",
        @"doc.append.fill",
        @"doc.badge.ellipsis",
        @"doc.badge.gearshape",
        @"doc.badge.gearshape.fill",
        @"doc.badge.plus",
        @"doc.circle",
        @"doc.circle.fill",
        @"doc.fill",
        @"doc.fill.badge.ellipsis",
        @"doc.fill.badge.plus",
        @"doc.on.clipboard",
        @"doc.on.clipboard.fill",
        @"doc.on.doc",
        @"doc.on.doc.fill",
        @"doc.plaintext",
        @"doc.plaintext.fill",
        @"doc.richtext",
        @"doc.richtext.fill",
        @"doc.text",
        @"doc.text.below.ecg",
        @"doc.text.below.ecg.fill",
        @"doc.text.fill",
        @"doc.text.fill.viewfinder",
        @"doc.text.magnifyingglass",
        @"doc.text.viewfinder",
        @"doc.zipper",
        @"dock.rectangle",
        @"dollarsign.circle",
        @"dollarsign.circle.fill",
        @"dollarsign.square",
        @"dollarsign.square.fill",
        @"dongsign.circle",
        @"dongsign.circle.fill",
        @"dongsign.square",
        @"dongsign.square.fill",
        @"dot.radiowaves.forward",
        @"dot.radiowaves.left.and.right",
        @"dot.radiowaves.right",
        @"dot.square",
        @"dot.square.fill",
        @"dot.squareshape",
        @"dot.squareshape.fill",
        @"dot.squareshape.split.2x2",
        @"dpad",
        @"dpad.down.fill",
        @"dpad.fill",
        @"dpad.left.fill",
        @"dpad.right.fill",
        @"dpad.up.fill",
        @"drop",
        @"drop.fill",
        @"drop.triangle",
        @"drop.triangle.fill",
        @"e.circle",
        @"e.circle.fill",
        @"e.square",
        @"e.square.fill",
        @"ear",
        @"ear.badge.checkmark",
        @"ear.fill",
        @"ear.trianglebadge.exclamationmark",
        @"eject",
        @"eject.circle",
        @"eject.circle.fill",
        @"eject.fill",
        @"ellipsis",
        @"ellipsis.bubble",
        @"ellipsis.bubble.fill",
        @"ellipsis.circle",
        @"ellipsis.circle.fill",
        @"ellipsis.rectangle",
        @"ellipsis.rectangle.fill",
        @"envelope",
        @"envelope.badge",
        @"envelope.badge.fill",
        @"envelope.badge.shield.leadinghalf.fill",
        @"envelope.circle",
        @"envelope.circle.fill",
        @"envelope.fill",
        @"envelope.fill.badge.shield.trailinghalf.fill",
        @"envelope.open",
        @"envelope.open.fill",
        @"equal",
        @"equal.circle",
        @"equal.circle.fill",
        @"equal.square",
        @"equal.square.fill",
        @"escape",
        @"esim",
        @"esim.fill",
        @"eurosign.circle",
        @"eurosign.circle.fill",
        @"eurosign.square",
        @"eurosign.square.fill",
        @"exclamationmark.bubble",
        @"exclamationmark.bubble.fill",
        @"exclamationmark.circle",
        @"exclamationmark.circle.fill",
        @"exclamationmark.octagon",
        @"exclamationmark.octagon.fill",
        @"exclamationmark.shield",
        @"exclamationmark.shield.fill",
        @"exclamationmark.square",
        @"exclamationmark.square.fill",
        @"exclamationmark.triangle",
        @"exclamationmark.triangle.fill",
        @"externaldrive",
        @"externaldrive.badge.checkmark",
        @"externaldrive.badge.icloud",
        @"externaldrive.badge.minus",
        @"externaldrive.badge.person.crop",
        @"externaldrive.badge.plus",
        @"externaldrive.badge.timemachine",
        @"externaldrive.badge.wifi",
        @"externaldrive.badge.xmark",
        @"externaldrive.connected.to.line.below",
        @"externaldrive.connected.to.line.below.fill",
        @"externaldrive.fill",
        @"externaldrive.fill.badge.checkmark",
        @"externaldrive.fill.badge.icloud",
        @"externaldrive.fill.badge.minus",
        @"externaldrive.fill.badge.person.crop",
        @"externaldrive.fill.badge.plus",
        @"externaldrive.fill.badge.timemachine",
        @"externaldrive.fill.badge.wifi",
        @"externaldrive.fill.badge.xmark",
        @"eye",
        @"eye.circle",
        @"eye.circle.fill",
        @"eye.fill",
        @"eye.slash",
        @"eye.slash.fill",
        @"eyebrow",
        @"eyedropper",
        @"eyedropper.full",
        @"eyedropper.halffull",
        @"eyeglasses",
        @"eyes",
        @"eyes.inverse",
        @"face.dashed",
        @"face.dashed.fill",
        @"face.smiling",
        @"face.smiling.fill",
        @"faxmachine",
        @"fiberchannel",
        @"figure.stand",
        @"figure.stand.line.dotted.figure.stand",
        @"figure.walk",
        @"figure.walk.circle",
        @"figure.walk.circle.fill",
        @"figure.walk.diamond",
        @"figure.walk.diamond.fill",
        @"figure.wave",
        @"figure.wave.circle",
        @"figure.wave.circle.fill",
        @"filemenu.and.cursorarrow",
        @"filemenu.and.selection",
        @"film",
        @"film.fill",
        @"flag",
        @"flag.badge.ellipsis",
        @"flag.badge.ellipsis.fill",
        @"flag.circle",
        @"flag.circle.fill",
        @"flag.fill",
        @"flag.slash",
        @"flag.slash.circle",
        @"flag.slash.circle.fill",
        @"flag.slash.fill",
        @"flame",
        @"flame.fill",
        @"flashlight.off.fill",
        @"flashlight.on.fill",
        @"flipphone",
        @"florinsign.circle",
        @"florinsign.circle.fill",
        @"florinsign.square",
        @"florinsign.square.fill",
        @"flowchart",
        @"flowchart.fill",
        @"fn",
        @"folder",
        @"folder.badge.gear",
        @"folder.badge.minus",
        @"folder.badge.person.crop",
        @"folder.badge.plus",
        @"folder.badge.questionmark",
        @"folder.circle",
        @"folder.circle.fill",
        @"folder.fill",
        @"folder.fill.badge.gear",
        @"folder.fill.badge.minus",
        @"folder.fill.badge.person.crop",
        @"folder.fill.badge.plus",
        @"folder.fill.badge.questionmark",
        @"function",
        @"fx",
        @"gamecontroller",
        @"gamecontroller.fill",
        @"gauge",
        @"gauge.badge.minus",
        @"gauge.badge.plus",
        @"gear",
        @"gearshape",
        @"gearshape.2",
        @"gearshape.2.fill",
        @"gearshape.fill",
        @"gift",
        @"gift.circle",
        @"gift.circle.fill",
        @"gift.fill",
        @"giftcard",
        @"giftcard.fill",
        @"globe",
        @"graduationcap",
        @"graduationcap.fill",
        @"greetingcard",
        @"greetingcard.fill",
        @"guitars",
        @"guitars.fill",
        @"gyroscope",
        @"hammer",
        @"hammer.fill",
        @"hare",
        @"hare.fill",
        @"headphones",
        @"headphones.circle",
        @"headphones.circle.fill",
        @"heart",
        @"heart.circle",
        @"heart.circle.fill",
        @"heart.fill",
        @"heart.slash",
        @"heart.slash.circle",
        @"heart.slash.circle.fill",
        @"heart.slash.fill",
        @"heart.text.square",
        @"heart.text.square.fill",
        @"helm",
        @"hexagon",
        @"hexagon.fill",
        @"hifispeaker",
        @"hifispeaker.2",
        @"hifispeaker.2.fill",
        @"hifispeaker.fill",
        @"highlighter",
        @"hourglass",
        @"hourglass.badge.plus",
        @"hourglass.bottomhalf.fill",
        @"hourglass.tophalf.fill",
        @"house",
        @"house.circle",
        @"house.circle.fill",
        @"house.fill",
        @"infinity",
        @"infinity.circle",
        @"infinity.circle.fill",
        @"info",
        @"info.circle",
        @"info.circle.fill",
        @"internaldrive",
        @"internaldrive.fill",
        @"key",
        @"key.fill",
        @"keyboard",
        @"keyboard.badge.ellipsis",
        @"ladybug",
        @"ladybug.fill",
        @"laptopcomputer",
        @"lasso",
        @"lasso.sparkles",
        @"latch.2.case",
        @"latch.2.case.fill",
        @"leaf",
        @"leaf.arrow.triangle.circlepath",
        @"leaf.fill",
        @"level",
        @"level.fill",
        @"lifepreserver",
        @"lifepreserver.fill",
        @"lightbulb",
        @"lightbulb.fill",
        @"lightbulb.slash",
        @"lightbulb.slash.fill",
        @"line.3.crossed.swirl.circle",
        @"line.3.crossed.swirl.circle.fill",
        @"link",
        @"link.badge.plus",
        @"link.circle",
        @"link.circle.fill",
        @"list.and.film",
        @"list.bullet",
        @"list.bullet.below.rectangle",
        @"list.bullet.indent",
        @"list.bullet.rectangle",
        @"list.dash",
        @"list.number",
        @"list.star",
        @"list.triangle",
        @"location",
        @"location.circle",
        @"location.circle.fill",
        @"location.fill",
        @"location.fill.viewfinder",
        @"lock",
        @"lock.circle",
        @"lock.circle.fill",
        @"lock.doc",
        @"lock.doc.fill",
        @"lock.fill",
        @"lock.rectangle",
        @"lock.rectangle.fill",
        @"lock.rectangle.on.rectangle",
        @"lock.rectangle.on.rectangle.fill",
        @"lock.rectangle.stack",
        @"lock.rectangle.stack.fill",
        @"lock.rotation",
        @"lock.rotation.open",
        @"lock.shield",
        @"lock.shield.fill",
        @"lock.square",
        @"lock.square.fill",
        @"lock.square.stack",
        @"lock.square.stack.fill",
        @"loupe",
        @"lungs",
        @"lungs.fill",
        @"magnifyingglass",
        @"magnifyingglass.circle",
        @"magnifyingglass.circle.fill",
        @"mail",
        @"mail.and.text.magnifyingglass",
        @"mail.fill",
        @"mail.stack",
        @"mail.stack.fill",
        @"map",
        @"map.fill",
        @"mappin",
        @"mappin.and.ellipse",
        @"mappin.circle",
        @"mappin.circle.fill",
        @"megaphone",
        @"megaphone.fill",
        @"memorychip",
        @"metronome",
        @"metronome.fill",
        @"mic",
        @"mic.circle",
        @"mic.circle.fill",
        @"mic.fill",
        @"minus.plus.batteryblock",
        @"minus.plus.batteryblock.fill",
        @"moon",
        @"moon.circle",
        @"moon.circle.fill",
        @"moon.fill",
        @"moon.stars",
        @"moon.stars.fill",
        @"moon.zzz",
        @"moon.zzz.fill",
        @"music.mic",
        @"music.note",
        @"music.note.house",
        @"music.note.house.fill",
        @"music.note.list",
        @"music.quarternote.3",
        @"network",
        @"newspaper",
        @"newspaper.fill",
        @"paperclip",
        @"paperclip.badge.ellipsis",
        @"paperclip.circle",
        @"paperclip.circle.fill",
        @"paperplane",
        @"paperplane.circle",
        @"paperplane.circle.fill",
        @"paperplane.fill",
        @"pc",
        @"pencil",
        @"pencil.and.outline",
        @"pencil.circle",
        @"pencil.circle.fill",
        @"person",
        @"person.2",
        @"person.2.circle",
        @"person.2.circle.fill",
        @"person.2.fill",
        @"person.2.square.stack",
        @"person.2.square.stack.fill",
        @"person.3",
        @"person.3.fill",
        @"person.circle",
        @"person.circle.fill",
        @"person.crop.circle",
        @"personalhotspot",
        @"perspective",
        @"phone",
        @"phone.bubble.left",
        @"phone.bubble.left.fill",
        @"phone.circle",
        @"phone.circle.fill",
        @"phone.down.circle",
        @"phone.down.circle.fill",
        @"phone.down.fill",
        @"phone.fill",
        @"photo",
        @"photo.fill",
        @"photo.fill.on.rectangle.fill",
        @"photo.on.rectangle",
        @"photo.on.rectangle.angled",
        @"photo.tv",
        @"pianokeys",
        @"pianokeys.inverse",
        @"pills",
        @"pills.fill",
        @"pin",
        @"pin.circle",
        @"pin.circle.fill",
        @"pin.fill",
        @"printer",
        @"printer.dotmatrix",
        @"printer.dotmatrix.fill",
        @"printer.dotmatrix.fill.and.paper.fill",
        @"printer.fill",
        @"printer.fill.and.paper.fill",
        @"slowmo",
        @"smoke",
        @"smoke.fill",
        @"snow",
        @"sparkle",
        @"sparkles",
        @"speedometer",
        @"sportscourt",
        @"sportscourt.fill",
        @"square.stack.fill",
        @"square.tophalf.fill",
        @"squares.below.rectangle",
        @"star",
        @"star.circle",
        @"star.circle.fill",
        @"star.fill",
        @"star.square",
        @"star.square.fill",
        @"staroflife",
        @"staroflife.circle",
        @"staroflife.circle.fill",
        @"staroflife.fill",
        @"stethoscope",
        @"stopwatch",
        @"stopwatch.fill",
        @"studentdesk",
        @"suit.club",
        @"suit.club.fill",
        @"suit.diamond",
        @"suit.diamond.fill",
        @"suit.heart",
        @"suit.heart.fill",
        @"suit.spade",
        @"suit.spade.fill",
        @"sun.dust",
        @"sun.dust.fill",
        @"sun.haze",
        @"sun.haze.fill",
        @"sun.max",
        @"sun.max.fill",
        @"sun.min",
        @"sun.min.fill",
        @"sunrise",
        @"sunrise.fill",
        @"sunset",
        @"sunset.fill",
        @"switch.2",
        @"tablecells",
        @"tablecells.fill",
        @"tag",
        @"tag.circle",
        @"tag.circle.fill",
        @"tag.fill",
        @"target",
        @"terminal",
        @"terminal.fill",
        @"text.book.closed",
        @"text.book.closed.fill",
        @"thermometer",
        @"thermometer.snowflake",
        @"thermometer.sun",
        @"thermometer.sun.fill",
        @"ticket",
        @"ticket.fill",
        @"timer",
        @"timer.square",
        @"togglepower",
        @"tornado",
        @"tortoise",
        @"tortoise.fill",
        @"tram",
        @"tram.circle",
        @"tram.circle.fill",
        @"tram.fill",
        @"tram.tunnel.fill",
        @"trash",
        @"trash.circle",
        @"trash.circle.fill",
        @"trash.fill",
        @"tray",
        @"tray.2",
        @"tray.2.fill",
        @"tray.circle",
        @"tray.circle.fill",
        @"tray.fill",
        @"tray.full",
        @"tray.full.fill",
        @"tropicalstorm",
        @"tuningfork",
        @"tv",
        @"tv.and.hifispeaker.fill",
        @"tv.and.mediabox",
        @"tv.music.note",
        @"tv.music.note.fill",
        @"umbrella",
        @"umbrella.fill",
        @"wake",
        @"wallet.pass",
        @"wallet.pass.fill",
        @"waveform",
        @"waveform.circle",
        @"waveform.circle.fill",
        @"waveform.path",
        @"waveform.path.ecg",
        @"waveform.path.ecg.rectangle",
        @"waveform.path.ecg.rectangle.fill",
        @"wifi",
        @"wrench",
        @"wrench.and.screwdriver",
        @"wrench.and.screwdriver.fill",
        @"wrench.fill",
        @"xmark.bin",
        @"xmark.bin.circle",
        @"xmark.bin.circle.fill",
        @"xmark.bin.fill",
        @"xmark.circle",
        @"xmark.circle.fill",
        @"xmark.diamond",
        @"xmark.diamond.fill",
        @"xmark.seal",
        @"xmark.seal.fill",
        @"xmark.shield",
        @"xmark.shield.fill",
        @"zzz",
    ];
}


@end
