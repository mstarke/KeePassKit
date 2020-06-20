//
//  KPKMetaData.m
//  MacPass
//
//  Created by Michael Starke on 23.07.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "KPKMetaData.h"
#import "KPKExtendedModificationRecording.h"
#import "KPKMetaData_Private.h"
#import "KPKKdbxFormat.h"
#import "KPKIcon.h"
#import "KPKTree.h"
#import "KPKNode_Private.h"
#import "KPKGroup.h"
#import "KPKAESCipher.h"
#import "KPKAESKeyDerivation.h"

#import "KPKScopedSet.h"

#import "NSUUID+KPKAdditions.h"

#define KPK_METADATA_UPDATE_DATE(value) \
if( self.updateTiming ) { \
  value = NSDate.date; \
} \

@interface KPKMetaData () {
  NSMutableDictionary *_customIconCache;
}
@end

@implementation KPKMetaData

@synthesize updateTiming = _updateTiming;

+ (NSSet *)keyPathsForValuesAffectingEnforceMasterKeyChange {
  return [NSSet setWithObject:NSStringFromSelector(@selector(masterKeyChangeEnforcementInterval))];
}

+ (NSSet *)keyPathsForValuesAffectingRecommendMasterKeyChange {
  return [NSSet setWithObject:NSStringFromSelector(@selector(masterKeyChangeRecommendationInterval))];
}

+ (NSSet *)keyPathsForValuesAffectingCustomIcons {
  return [NSSet setWithObject:NSStringFromSelector(@selector(mutableCustomIcons))];
}

+ (NSSet *)keyPathsForValuesAffectingIsHistoryEnabled {
  return [NSSet setWithObject:NSStringFromSelector(@selector(historyMaxItems))];
}

- (instancetype)init {
  self = [super init];
  if(self){
    NSDate *now = [NSDate date];
    _mutableCustomData = [[NSMutableDictionary alloc] init];
    _mutableCustomPublicData = [[NSMutableDictionary alloc] init];
    _mutableCustomIcons = [[NSMutableArray alloc] init];
    _mutableUnknownMetaEntryData = [[NSMutableArray alloc] init];
    _customIconCache = [[NSMutableDictionary alloc] init];
    _keyDerivationParameters = [[KPKAESKeyDerivation defaultParameters] copy]; // aes parameters are used as default
    _cipherUUID = [[KPKAESCipher alloc] init].uuid;
    _compressionAlgorithm = KPKCompressionGzip;
    _protectNotes = NO;
    _protectPassword = YES;
    _protectTitle = NO;
    _protectUrl = NO;
    _protectUserName = NO;
    _generator = [@"MacPass" copy];
    _databaseName = [NSLocalizedStringFromTableInBundle(@"DATABASE", nil, [NSBundle bundleForClass:[self class]], "Default title for KDBX databases") copy];
    _databaseNameChanged = [now copy];
    _databaseDescription = [@"" copy];
    _databaseDescriptionChanged = [now copy];
    _defaultUserName = [@"" copy];
    _defaultUserNameChanged = [now copy];
    _entryTemplatesGroupChanged = [now copy];
    _entryTemplatesGroupUuid = [NSUUID.kpk_nullUUID copy];
    _trashChanged = [now copy];
    _settingsChanged = [now copy];
    _trashUuid = [NSUUID.kpk_nullUUID copy];
    _useTrash = YES; // use trash by default
    _lastSelectedGroup = [NSUUID.kpk_nullUUID copy];
    _lastTopVisibleGroup = [NSUUID.kpk_nullUUID copy];
    _historyMaxItems = 10;
    _historyMaxSize = 6 * 1024 * 1024; // 6 MB
    _maintenanceHistoryDays = 365;
    /* No Key change recommandation or enforcement */
    _masterKeyChangeRecommendationInterval=-1;
    _masterKeyChangeEnforcementInterval=-1;
    _enforceMasterKeyChangeOnce = NO;
    _updateTiming = YES;
  }
  return self;
}

#pragma mark -
#pragma mark Properties
- (NSArray *)customIcons {
  return [self.mutableCustomIcons copy];
}

- (NSDictionary<NSString *,NSString *> *)customData {
  return [self.mutableCustomData copy];
}

- (NSDictionary *)customPublicData {
  return [self.mutableCustomPublicData copy];
}

- (NSArray<KPKBinary *> *)unknownMetaEntryData {
  return [self.mutableUnknownMetaEntryData copy];
}

- (BOOL)isHistoryEnabled {
  return (self.historyMaxItems != -1);
}

- (BOOL)enforceMasterKeyChange {
  return  self.masterKeyChangeEnforcementInterval > -1;
}

- (BOOL)recommendMasterKeyChange {
  return self.masterKeyChangeRecommendationInterval > -1;
}

- (void)setColor:(NSUIColor *)color {
  if(![_color isEqual:color]) {
    /*
     The color for databases does not support a alpha component
     thus we just stripp it
     */
    _color = [[color colorWithAlphaComponent:1.0] copy];
    KPK_METADATA_UPDATE_DATE(self.settingsChanged)
  }
}

- (void)setDatabaseName:(NSString *)databaseName {
  if(![_databaseName isEqualToString:databaseName]) {
    _databaseName = [databaseName copy];
    KPK_METADATA_UPDATE_DATE(self.databaseNameChanged)
  }
}

- (void)setDatabaseDescription:(NSString *)databaseDescription {
  if(![_databaseDescription isEqualToString:databaseDescription]) {
    _databaseDescription = [databaseDescription copy];
    KPK_METADATA_UPDATE_DATE(self.databaseDescriptionChanged)
  }
}

- (void)setDefaultUserName:(NSString *)defaultUserName {
  if(![_defaultUserName isEqualToString:defaultUserName]) {
    _defaultUserName = [defaultUserName copy];
    KPK_METADATA_UPDATE_DATE(self.defaultUserNameChanged)
  }
}

- (void)setEntryTemplatesGroup:(NSUUID *)entryTemplatesGroup {
  if(![_entryTemplatesGroupUuid isEqual:entryTemplatesGroup]) {
    _entryTemplatesGroupUuid = entryTemplatesGroup;
    KPK_METADATA_UPDATE_DATE(self.entryTemplatesGroupChanged)
  }
}

- (void)setUseTrash:(BOOL)useTrash {
  if(_useTrash != useTrash) {
    _useTrash = useTrash;
    KPK_METADATA_UPDATE_DATE(self.trashChanged)
  }
}

- (void)setTrashUuid:(NSUUID *)trashUuid {
  if(![_trashUuid isEqual:trashUuid]) {
    _trashUuid = trashUuid;
    KPK_METADATA_UPDATE_DATE(self.trashChanged)
  }
}


#pragma mark -
#pragma mark Equality
- (BOOL)isEqualToMetaData:(KPKMetaData *)other {
  if(self == other) {
    return YES; // Pointers match
  }
  /* no tree comparison, since the pointers cannot be encoded persitently */
  return [self.keyDerivationParameters isEqualToDictionary:other.keyDerivationParameters] &&
  self.compressionAlgorithm == other.compressionAlgorithm &&
  [self.cipherUUID isEqual:other.cipherUUID] &&
  [self.generator isEqualToString:other.generator] &&
  [self.settingsChanged isEqualToDate:other.settingsChanged] &&
  [self.databaseName isEqualToString:other.databaseName] &&
  [self.databaseNameChanged isEqualToDate:other.databaseNameChanged] &&
  [self.databaseDescription isEqualToString:other.databaseDescription] &&
  [self.databaseDescriptionChanged isEqualToDate:other.databaseDescriptionChanged] &&
  [self.defaultUserName isEqualToString:other.defaultUserName] &&
  [self.defaultUserNameChanged isEqualToDate:other.defaultUserNameChanged] &&
  self.maintenanceHistoryDays == other.maintenanceHistoryDays &&
  [self.color isEqual:other.color] &&
  [self.masterKeyChanged isEqualToDate:other.masterKeyChanged] &&
  self.recommendMasterKeyChange == other.recommendMasterKeyChange &&
  self.masterKeyChangeRecommendationInterval == other.masterKeyChangeRecommendationInterval &&
  self.enforceMasterKeyChange == other.enforceMasterKeyChange &&
  self.masterKeyChangeEnforcementInterval == other.masterKeyChangeEnforcementInterval &&
  self.enforceMasterKeyChangeOnce == other.enforceMasterKeyChangeOnce &&
  self.protectTitle == other.protectTitle &&
  self.protectUserName == other.protectUserName &&
  self.protectPassword == other.protectPassword &&
  self.protectUrl == other.protectUrl &&
  self.protectNotes == other.protectNotes &&
  self.useTrash == other.useTrash &&
  [self.trashUuid isEqual:other.trashUuid] &&
  [self.trashChanged isEqualToDate:other.trashChanged] &&
  [self.entryTemplatesGroupUuid isEqual:other.entryTemplatesGroupUuid] &&
  [self.entryTemplatesGroupChanged isEqualToDate:other.entryTemplatesGroupChanged] &&
  self.isHistoryEnabled == other.isHistoryEnabled &&
  self.historyMaxItems == other.historyMaxItems &&
  self.historyMaxSize == other.historyMaxSize &&
  [self.lastSelectedGroup isEqual:other.lastSelectedGroup] &&
  [self.lastTopVisibleGroup isEqual:other.lastTopVisibleGroup] &&
  [self.mutableCustomData isEqualToDictionary:other.mutableCustomData] &&
  [self.mutableCustomPublicData isEqualToDictionary:other.mutableCustomPublicData] &&
  [self.mutableCustomIcons isEqualToArray:other.mutableCustomIcons] &&
  [self.mutableUnknownMetaEntryData isEqualToArray:other.mutableUnknownMetaEntryData] &&
  self.updateTiming == other.updateTiming;
}

- (BOOL)isEqual:(id)object {
  if(self == object) {
    return YES;
  }
  if([object isKindOfClass:self.class]) {
    return [self isEqualToMetaData:object];
  }
  return NO;
}

- (void)addCustomIcon:(KPKIcon *)icon {
  [self addCustomIcon:icon atIndex:_mutableCustomIcons.count];
}

- (void)addCustomIcon:(KPKIcon *)icon atIndex:(NSUInteger)index {
  [[self.tree.undoManager prepareWithInvocationTarget:self] removeCustomIcon:icon];
  [self.tree.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"ADD_CUSTOM_ICON", nil, [NSBundle bundleForClass:[self class]], @"Action name for adding a custom icon.")];
  index = MIN(_mutableCustomIcons.count, index);
  [self insertObject:icon inMutableCustomIconsAtIndex:index];
  /* trigger a change notification to encourage reavaluation*/
  [self.tree.root _traverseNodesWithBlock:^(KPKNode *node, BOOL *stop) {
    if([node.iconUUID isEqual:icon.uuid]) {
      [node willChangeValueForKey:NSStringFromSelector(@selector(iconUUID))];
      [node didChangeValueForKey:NSStringFromSelector(@selector(iconUUID))];
    }
  }];
}

- (void)removeCustomIcon:(KPKIcon *)icon {
  NSUInteger index = [_mutableCustomIcons indexOfObjectIdenticalTo:icon];
  if(index != NSNotFound) {
    [[self.tree.undoManager prepareWithInvocationTarget:self] addCustomIcon:icon atIndex:index];
    [self.tree.undoManager setActionName:NSLocalizedStringFromTableInBundle(@"DELETE_CUSTOM_ICON", nil, [NSBundle bundleForClass:[self class]], @"Action name for deleting a custom icon")];
    [self removeObjectFromMutableCustomIconsAtIndex:index];
    /* trigger a change notification to encourage reavaluation*/
    [self.tree.root _traverseNodesWithBlock:^(KPKNode *node, BOOL *stop) {
      if([node.iconUUID isEqual:icon.uuid]) {
        [node willChangeValueForKey:NSStringFromSelector(@selector(iconUUID))];
        [node didChangeValueForKey:NSStringFromSelector(@selector(iconUUID))];
      }
    }];
  }
}

- (void)setValue:(NSString *)value forCustomDataKey:(NSString *)key {

}

- (void)setValue:(id)value forPublicCustomDataKey:(NSString *)key {
  
  self.mutableCustomPublicData[key] = value;
}

- (KPKIcon *)findIcon:(NSUUID *)uuid {
  return _customIconCache[uuid];
}

- (BOOL)protectAttributeWithKey:(NSString *)key {
  
  if([key isEqualToString:kKPKNotesKey]) {
    return self.protectNotes;
  }
  if([key isEqualToString:kKPKPasswordKey] ) {
    return self.protectPassword;
  }
  if([key isEqualToString:kKPKTitleKey] ) {
    return self.protectTitle;
  }
  if([key isEqualToString:kKPKURLKey] ) {
    return self.protectUrl;
  }
  if([key isEqualToString:kKPKUsernameKey] ) {
    return self.protectUserName;
  }
  return NO;
}

- (void)_mergeWithMetaDataFromTree:(KPKTree *)tree mode:(KPKSynchronizationMode)mode {
  KPKMetaData *otherMetaData = tree.metaData;
  
  BOOL forceUpdate = (mode == KPKSynchronizationModeOverwriteExisting);
  BOOL otherIsNewer = NSOrderedAscending == [otherMetaData.settingsChanged compare:self.settingsChanged];
  KPK_SCOPED_NO_BEGIN(self.updateTiming)
  if(forceUpdate || otherIsNewer) {
    self.settingsChanged = otherMetaData.settingsChanged;
    self.color = otherMetaData.color;
  }
  if(forceUpdate || NSOrderedAscending == [self.databaseNameChanged compare:otherMetaData.databaseNameChanged]) {
    self.databaseName = otherMetaData.databaseName;
    self.databaseNameChanged = otherMetaData.databaseNameChanged;
  }

  if(forceUpdate || NSOrderedAscending == [self.databaseDescriptionChanged compare:otherMetaData.databaseDescriptionChanged]) {
    self.databaseDescription = otherMetaData.databaseDescription;
    self.databaseDescriptionChanged = otherMetaData.databaseDescriptionChanged;
  }

  if(forceUpdate || NSOrderedAscending == [self.defaultUserNameChanged compare:otherMetaData.defaultUserNameChanged]) {
    self.defaultUserName = otherMetaData.defaultUserName;
    self.defaultUserNameChanged = otherMetaData.defaultUserNameChanged;
  }

  if(forceUpdate || NSOrderedAscending == [self.trashChanged compare:otherMetaData.trashChanged]) {
    
    self.trashChanged = otherMetaData.trashChanged;
    self.useTrash = otherMetaData.useTrash;
    
    if([tree.root groupForUUID:otherMetaData.trashUuid]) {
      self.trashUuid = otherMetaData.trashUuid;
    }
    else if(![tree.root groupForUUID:self.trashUuid]) {
      self.trashUuid = [NSUUID kpk_nullUUID];
    }
    // else keep old uuid!
  }
  
  if(forceUpdate || NSOrderedAscending == [self.entryTemplatesGroupChanged compare:otherMetaData.entryTemplatesGroupChanged]) {
    self.entryTemplatesGroupChanged = otherMetaData.entryTemplatesGroupChanged;
    
    if([tree.root groupForUUID:otherMetaData.entryTemplatesGroupUuid]) {
      self.entryTemplatesGroupUuid = otherMetaData.entryTemplatesGroupUuid;
    }
    else if(![tree.root groupForUUID:self.entryTemplatesGroupUuid]) {
      self.entryTemplatesGroupUuid = [NSUUID kpk_nullUUID];
    }
    // else keep old uuid
  }
  for(NSString *key in otherMetaData.mutableCustomData) {
    if(otherIsNewer || (nil == self.mutableCustomData[key])) {
      self.mutableCustomData[key] = otherMetaData.mutableCustomData[key];
    }
  }
  NSDictionary *backup = [[NSDictionary alloc] initWithDictionary:self.mutableCustomPublicData copyItems:YES];
  self.mutableCustomPublicData = [[NSMutableDictionary alloc] initWithDictionary:otherMetaData.mutableCustomPublicData copyItems:YES];
  if(!otherIsNewer) {
    for(NSString *key in backup) {
      self.mutableCustomPublicData[key] = [backup[key] copy];
    }
  }
  KPK_SCOPED_NO_END(self.updateTiming)
}

#pragma mark KVO
- (NSUInteger)countOfMutableCustomIcons {
  return _mutableCustomIcons.count;
}

- (void)insertObject:(KPKIcon *)icon inMutableCustomIconsAtIndex:(NSUInteger)index {
  index = MIN(_mutableCustomIcons.count, index);
  [_mutableCustomIcons insertObject:icon atIndex:index];
  _customIconCache[icon.uuid] = icon;
}

- (void)removeObjectFromMutableCustomIconsAtIndex:(NSUInteger)index {
  index = MIN(_mutableCustomIcons.count, index);
  KPKIcon *icon = _mutableCustomIcons[index];
  [_mutableCustomIcons removeObjectAtIndex:index];
  if(icon) {
    _customIconCache[icon.uuid] = nil;
  }
}

- (NSUInteger)countOfCustomData {
  return self.mutableCustomData.count;
}

- (NSEnumerator *)enumeratorOfCustomData {
  return self.mutableCustomData.objectEnumerator;
}

- (NSString *)memberOfCustomData:(NSString *)object {
  return self.mutableCustomData[object];
}


@end
