
#import <Foundation/Foundation.h>

@interface SMBDriver : NSObject


// debug boolean member, if YES then debug messages are printed to the standart output
@property BOOL debug;

/**
 * empty constructor
 */
- (id)init;

/**
 * internal method for testing the readTextFileFromHost method
 */
-(void) testRead;

/**
 * internal method for testing the writeTextFileFromHost method
 */
-(void) testWrite;

/**
 * this method reads a file over the SMB protocol,
 * shareHostName - the host name you would like to connect to where the file is at
 * user - the user name to use while connecting to this share, in order to login as guest - leave it empty
 * password - the user's password to use while connecting to this share, in order to login as guest - leave it empty
 * filePath - the name, extenstion and path to the file (without the main share name) that you want to read
 * shareName - the share folder name that the file resides in
 * error - out parameter, returns errors:
 *         -1: failed to find host ip address
 *         -2: failed connecting to host
 *         -3: failed login to host (using supplied user and guest)
 *         -4: failed to connect to share folder
 *         -5: failed to open requested file
 * returns: NSString, NULL if error, if success - the file text content
 */
-(NSString *) readTextFileFromHost:(NSString *)shareHostName
                         withLogin:(NSString *)user
                      withPassword:(NSString *)password
                      withFileName:(NSString *)filePath
                           onShare:(NSString *)shareName
                             error:(NSError **)error;

/**
 * this method writes a text into file over the SMB protocol, if the file exists - it is overrwritten, if the file does not exist - it is created
 * shareHostName - the host name you would like to connect to where the file should be written to
 * user - the user name to use while connecting to this share, in order to login as guest - leave it empty
 * password - the user's password to use while connecting to this share, in order to login as guest - leave it empty
 * filePath - the name, extenstion and path to the file (without the main share name) that you want to write
 * shareName - the share folder name that the file should be written to
 * textToWrite - the text string you would like to write into the file
 * append - indicate should write be append or overwrite (appned = YES means write text to the end of file)
 * error - out parameter, returns errors:
 *         -1: failed to find host ip address
 *         -2: failed connecting to host
 *         -3: failed login to host (using supplied user and guest)
 *         -4: failed to connect to share folder
 *         -5: failed to open requested file
 *         -6: failed to get file's metadata (fileSize, isDirectory...)
 *         -7: failed to write the text into the file (usually write permissions or file read only)
 * returns: int, -1 if error, 0 if success
 */
-(int) writeTextFileFromHost:(NSString *)shareHostName
           withLogin:(NSString *)user
        withPassword:(NSString *)password
        withFileName:(NSString *)filePath
             onShare:(NSString *)shareName
         textToWrite:(NSString *)textToWrite
              append:(BOOL) append
               error:(NSError **)error;


/**
 * this method log message using printf depending on the debug member value (if debug == YES),
 * also append each end of log line with \n (new line)
 */
-(void) logLine:(NSString *) logMessage;

@end
