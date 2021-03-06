//
// Copyright (c) 2019 Emarsys. All rights reserved.
//
#import "EMSRequestFactory.h"
#import "EMSRequestModel.h"
#import "MERequestContext.h"
#import "EMSEndpoint.h"
#import "EMSDeviceInfo+MEClientPayload.h"
#import "NSDate+EMSCore.h"
#import "EmarsysSDKVersion.h"
#import "EMSNotification.h"
#import "EMSAuthentication.h"

@interface EMSRequestFactory ()

@property(nonatomic, strong) MERequestContext *requestContext;
@property(nonatomic, strong) EMSDeviceInfo *deviceInfo;
@property(nonatomic, strong) EMSEndpoint *endpoint;

@end

@implementation EMSRequestFactory

- (instancetype)initWithRequestContext:(MERequestContext *)requestContext
                              endpoint:(EMSEndpoint *)endpoint {
    NSParameterAssert(requestContext);
    NSParameterAssert(endpoint);
    if (self = [super init]) {
        _requestContext = requestContext;
        _deviceInfo = requestContext.deviceInfo;
        _endpoint = endpoint;
    }
    return self;
}

- (EMSRequestModel *)createDeviceInfoRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint clientUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodPOST];
                [builder setPayload:[weakSelf.deviceInfo clientPayload]];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createPushTokenRequestModelWithPushToken:(NSString *)pushToken {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint pushTokenUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodPUT];
                [builder setPayload:@{@"pushToken": pushToken}];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createClearPushTokenRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint pushTokenUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodDELETE];
                [builder setPayload:@{}];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createContactRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setMethod:HTTPMethodPOST];
                BOOL anonymousLogin = NO;
                NSDictionary *payload = @{};
                if (weakSelf.requestContext.contactFieldId && weakSelf.requestContext.contactFieldValue) {
                    payload = @{
                            @"contactFieldId": weakSelf.requestContext.contactFieldId,
                            @"contactFieldValue": weakSelf.requestContext.contactFieldValue
                    };
                } else {
                    anonymousLogin = YES;
                }
                [builder setUrl:[weakSelf.endpoint contactUrlWithApplicationCode:weakSelf.requestContext.applicationCode]
                queryParameters:@{@"anonymous": anonymousLogin ? @"true" : @"false"}];
                [builder setPayload:payload];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createEventRequestModelWithEventName:(NSString *)eventName
                                          eventAttributes:(nullable NSDictionary<NSString *, NSString *> *)eventAttributes
                                                eventType:(EventType)eventType {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setMethod:HTTPMethodPOST];
                [builder setUrl:[weakSelf.endpoint eventUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];

                NSMutableDictionary *mutableEvent = [NSMutableDictionary dictionary];
                mutableEvent[@"type"] = [weakSelf eventTypeStringRepresentationFromEventType:eventType];
                mutableEvent[@"name"] = eventName;
                mutableEvent[@"timestamp"] = [[weakSelf.requestContext.timestampProvider provideTimestamp] stringValueInUTC];
                mutableEvent[@"attributes"] = eventAttributes;

                NSMutableDictionary *mutablePayload = [NSMutableDictionary dictionary];
                mutablePayload[@"clicks"] = @[];
                mutablePayload[@"viewedMessages"] = @[];
                mutablePayload[@"events"] = @[
                        [NSDictionary dictionaryWithDictionary:mutableEvent]
                ];
                [builder setPayload:[NSDictionary dictionaryWithDictionary:mutablePayload]];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createRefreshTokenRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setMethod:HTTPMethodPOST];
                [builder setUrl:[weakSelf.endpoint contactTokenUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];
                NSMutableDictionary *mutablePayload = [NSMutableDictionary dictionary];
                mutablePayload[@"refreshToken"] = weakSelf.requestContext.refreshToken;
                [builder setPayload:[NSDictionary dictionaryWithDictionary:mutablePayload]];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createDeepLinkRequestModelWithTrackingId:(NSString *)trackingId {
    __weak typeof(self) weakSelf = self;
    NSString *userAgent = [NSString stringWithFormat:@"Emarsys SDK %@ %@ %@", EMARSYS_SDK_VERSION,
                                                     self.requestContext.deviceInfo.deviceType,
                                                     self.requestContext.deviceInfo.osVersion];
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setMethod:HTTPMethodPOST];
                [builder setUrl:[weakSelf.endpoint deeplinkUrl]];
                [builder setHeaders:@{@"User-Agent": userAgent}];
                [builder setPayload:@{@"ems_dl": trackingId}];
            }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createMessageOpenWithNotification:(EMSNotification *)notification {
    __weak typeof(self) weakSelf = self;
    EMSRequestModel *requestModel = [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint v2EventServiceUrl]];
                [builder setMethod:HTTPMethodPOST];

                NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                payload[@"application_id"] = self.requestContext.applicationCode;
                payload[@"hardware_id"] = self.requestContext.deviceInfo.hardwareId;
                payload[@"sid"] = notification.sid;
                payload[@"source"] = @"inbox";

                if (self.requestContext.contactFieldId && self.requestContext.contactFieldValue) {
                    payload[@"contact_field_id"] = self.requestContext.contactFieldId;
                    payload[@"contact_field_value"] = self.requestContext.contactFieldValue;
                }

                [builder setPayload:[NSDictionary dictionaryWithDictionary:payload]];
                [builder setHeaders:@{@"Authorization": [EMSAuthentication createBasicAuthWithUsername:self.requestContext.applicationCode]}];
            }
                                                   timestampProvider:self.requestContext.timestampProvider
                                                        uuidProvider:self.requestContext.uuidProvider];
    return requestModel;
}

- (EMSRequestModel *)createGeofenceRequestModel {
    __weak typeof(self) weakSelf = self;
    EMSRequestModel *requestModel = [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint geofenceUrlWithApplicationCode:self.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodGET];
                [builder setHeaders:@{@"Authorization": [EMSAuthentication createBasicAuthWithUsername:self.requestContext.applicationCode]}];
            }
                                                   timestampProvider:self.requestContext.timestampProvider
                                                        uuidProvider:self.requestContext.uuidProvider];
    return requestModel;
}

- (EMSRequestModel *)createMessageInboxRequestModel {
    __weak typeof(self) weakSelf = self;
    EMSRequestModel *requestModel = [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint v3MessageInboxUrlApplicationCode:weakSelf.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodGET];
                [builder setHeaders:@{@"Authorization": [EMSAuthentication createBasicAuthWithUsername:weakSelf.requestContext.applicationCode]}];
            }
                                                   timestampProvider:self.requestContext.timestampProvider
                                                        uuidProvider:self.requestContext.uuidProvider];
    return requestModel;
}

- (EMSRequestModel *)createInlineInappRequestModelWithViewId:(NSString *)viewId {
    __weak typeof(self) weakSelf = self;
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    payload[@"viewIds"] = @[viewId];
    payload[@"clicks"] = @[];
    EMSRequestModel *requestModel = [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
                [builder setUrl:[weakSelf.endpoint inlineInappUrlWithApplicationCode:weakSelf.requestContext.applicationCode]];
                [builder setMethod:HTTPMethodPOST];
                [builder setPayload:[NSDictionary dictionaryWithDictionary:payload]];
            }
                                                   timestampProvider:self.requestContext.timestampProvider
                                                        uuidProvider:self.requestContext.uuidProvider];
    return requestModel;
}

- (NSString *)eventTypeStringRepresentationFromEventType:(EventType)eventType {
    NSString *result = @"custom";
    if (eventType == EventTypeInternal) {
        result = @"internal";
    }
    return result;
}

@end
