//
//  XAccessory.h
//  PrinterSDK
//
//  Created by max on 2024/5/29.
//

@import Foundation;
@import ExternalAccessory;

/// Declare an external NSString type variable EADSessionDataReceivedNotification for receiving data notification
extern NSString *EADSessionDataReceivedNotification;

/// External Accessory Communication Class
@interface XAccessory : NSObject

/// The external accessory object.
@property (nonatomic, readonly) EAAccessory *accessory;

/// The communication protocol string in use.
@property (nonatomic, readonly) NSString *protocolString;

/// Returns the shared instance of XAccessory.
+ (XAccessory *)sharedInstance;

/// Configure the specified external accessory and protocol string.
/// @param accessory The external accessory object to configure.
/// @param protocolString The communication protocol string to use.
- (void)setupControllerForAccessory:(EAAccessory *)accessory withProtocolString:(NSString *)protocolString;

/// Open the session with the external accessory.
/// @return Whether the session was opened successfully.
- (BOOL)openSession;

/// Close the session with the external accessory.
/// @return Whether the session was closed successfully.
- (BOOL)closeSession;

/// Write data to the external accessory.
/// @param data The data to write.
- (void)writeData:(NSData *)data;

/// Return the number of bytes currently available for reading.
/// @return The number of bytes currently available for reading.
- (NSUInteger)readBytesAvailable;

/// Read the specified number of bytes from the external accessory.
/// @param bytesToRead The number of bytes to read.
/// @return The data read from the external accessory.
- (NSData *)readData:(NSUInteger)bytesToRead;

@end



