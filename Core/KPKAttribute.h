//
//  KPKAttribute.h
//  KeePassKit
//
//  Created by Michael Starke on 15.07.13.
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

#import <Foundation/Foundation.h>

@class KPKEntry;

@interface KPKAttribute : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, assign) BOOL isProtected;
@property (nonatomic, readonly) NSString *referencedValue;
@property (nonatomic, readonly) NSString *placeholderValue;
/**
 *  @return Value evaluated with references and replaced placeholders
 */
@property (nonatomic, readonly) NSString *evaluatedValue;


@property (weak) KPKEntry *entry; /// Reference to entry to be able to validate keys

/**
 *  Designates initalizer. Creats a Attribute with the given key, value and set the protetection
 *  @param key       Key for the attributes
 *  @param value     Value for the attribute
 *  @param protected YES if the attribute should be protected, NO otherwise
 *  @return Created KPKAttribute with the supplied values
 */
- (instancetype)initWithKey:(NSString *)key value:(NSString *)value isProtected:(BOOL)protected;
/**
 *  Creats an unprotected Attribute
 *  @param key   Key for the attributes
 *  @param value Value for the attribute
 *  @return The KPKAttribure initalizes with key and value. isProtected is NO
 */
- (instancetype)initWithKey:(NSString *)key value:(NSString *)value;
/**
 *  Determines if the reviever is equal to the provided attribute
 *  @param attribtue The attribute to test for equality
 *  @return YES if the reciever is euqal to the attribute. This is a value based equality!
 */
- (BOOL)isEqualToAttribute:(KPKAttribute *)attribtue;
/**
 *  Determines if the reciever is a default attribute or not
 *  @return YES if the reciever is a defautl attribute, NO otherwise
 */
- (BOOL)isDefault;
/**
 *  Sets the value for the given reciever without registering and undo action.
 *  This is used for higher level calls to ensure a singel undo registration
 *  as the call needs to be done to the higher leve function not the low level value change
 *  @param value The Value to be set.
 */
- (void)setValueWithoutUndoRegistration:(NSString *)value;

@end
