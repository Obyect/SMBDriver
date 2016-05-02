
#import "SMBDriver.h"
#include <arpa/inet.h>
#include <bdsm/bdsm.h>
#include <string.h>

@implementation SMBDriver

@synthesize debug;

/**
 * empty constructor
 */
- (id)init
{
    debug = NO;
    return self;
}

/**
 * internal method for testing the read method
 */
-(void) testRead
{
    NSString * hostName = @"MyMac";
    NSString * userName = @"test";
    NSString * loginPassword = @"1234";
    NSString * fileNameAndPath = @"/test.txt";
    NSString * sharedFolder = @"MyShare";
    NSError * error;
    NSString * fileContent;
    
    fileContent = [self readTextFileFromHost:hostName withLogin:userName withPassword:loginPassword withFileName:fileNameAndPath onShare:sharedFolder error:&error];
    
    if(fileContent != NULL)
    {
        printf("File Content:\n%s\n", [fileContent UTF8String]);
    }
    else
    {
        printf("failed to read file content, errorCode: %ld, errorMessage: %s\n", (long)error.code, [error.localizedDescription UTF8String]);
    }
}

-(void) testWrite
{
    NSString * hostName = @"MyPC";
    NSString * userName = @"test";
    NSString * loginPassword = @"1234";
    NSString * fileNameAndPath = @"/test.txt";
    NSString * sharedFolder = @"MyShare";
    NSString * textToWrite = @"This is my first line (1)\nthis is the second line (2)!";
    NSError * error;
    int writeResult;
    
    writeResult = [self writeTextFileFromHost:hostName withLogin:userName withPassword:loginPassword withFileName:fileNameAndPath onShare:sharedFolder textToWrite:textToWrite append:NO error:&error];
    
    if(writeResult == 0)
    {
        printf("Successfully written file");
    }
    else
    {
        printf("failed to write file content, errorCode: %ld, errorMessage: %s\n", (long)error.code, [error.localizedDescription UTF8String]);
    }
}

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
                             error:(NSError **)error
{
    // convert incomming shareHostName parameter into a local const char hostName variable
    const char * hostName = [shareHostName cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming user parameter into a local const char userName variable
    const char * userName = [user cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming password parameter into a local const char loginPassword variable
    const char * loginPassword = [password cStringUsingEncoding:NSUTF8StringEncoding];
    
    // strip the filePath of its first '/' if it exists
    if([filePath hasPrefix: @"/"])
    {
        filePath = [filePath substringFromIndex:1];
    }
    
    // change every '/' to '\\'
    if([filePath containsString: @"/"])
    {
        filePath = [filePath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    }
    
    // convert incomming filePath parameter into a local const char fileNameAndPath variable
    const char * fileNameAndPath = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming shareName parameter into a local const char sharedFolder variable
    const char * sharedFolder = [shareName cStringUsingEncoding:NSUTF8StringEncoding];
    
    // variable to contain the ip address of the destination host
    struct sockaddr_in ipAddress;
    
    // variable to contain a NetBios name service
    netbios_ns * netbiosNameService;
    
    // variable to contain the SMB created session
    smb_session * smbSession;
    
    // the connected share id (share descriptor)
    smb_tid shareID;
    
    // the requested and opened file descriptor
    smb_fd fileDescriptor;
    
    // variable to contain the current read bytes from opened file
    char readBuffer[65535];
    
    // variable to contain the end result file content as a string
    NSMutableString * fileContent = [NSMutableString string];
    
    // create a NetBios name service instance
    netbiosNameService = netbios_ns_new();
    
    // make sure the requested host is resolveable and fetch it's IP address, otherwise - return error code
    int resolveResult = netbios_ns_resolve(netbiosNameService, hostName, NETBIOS_FILESERVER, &ipAddress.sin_addr.s_addr);
    
    if (resolveResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully reversed lookup host: %s into IP address: %s\n", hostName, inet_ntoa(ipAddress.sin_addr)]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to reverse lookup, could not resolve the host: %s IP address, libDSM errorCode: %d", hostName, resolveResult];
        [self logLine:errorMessageString];
        
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-1 userInfo:errorMessage];
        return NULL;
    }
    
    // create a new SMB session
    smbSession = smb_session_new();
    
    // try to connect to the requested host using the resolved IP address using a TCP connection
    int connectResult = smb_session_connect(smbSession, hostName, ipAddress.sin_addr.s_addr, SMB_TRANSPORT_TCP);
    
    // make sure the connection to the requested host has succeeded, else return error
    if (connectResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully connected to %s\n", hostName]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed connecting to host: %s, libDSM returned errorCode:%d", hostName, connectResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-2 userInfo:errorMessage];
        return NULL;
    }
    
    // login to the host using the userName and loginPassword
    smb_session_set_creds(smbSession, hostName, userName, loginPassword);
    
    // try to login to the connected host with the supplied user and password
    int loginResult = smb_session_login(smbSession);
    
    // check if the login is successful, and if it used a Guest user or the supplied credentials
    if (loginResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully loggedin to host: %s as user: %s\n", hostName, userName]];
    }
    else if (loginResult == 1)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"successfully login using a Guest user, due to failiour with supplied user and password\n"]];
    }
    else if (loginResult == -1)
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to login to host: %s as user: %s, and also failed to login as guest", hostName, userName];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-3 userInfo:errorMessage];
        return NULL;
    }
    
    // connect to the requested share folder
    int shareConnectResult = smb_tree_connect(smbSession, sharedFolder, &shareID);
    
    // check if connection to the shared folder was successful
    if (shareConnectResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully connected to share: %s\n", sharedFolder]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to connect to share: %s libDSM errorCode: %d", sharedFolder, shareConnectResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-4 userInfo:errorMessage];
        return NULL;
    }
    
    // open the requested file (using connected share) in a Read Only mode
    int openFileResult = smb_fopen(smbSession, shareID, fileNameAndPath, SMB_MOD_RO, &fileDescriptor);
    
    // make sure file was opened successfully
    if (openFileResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully opened file: %s\n", fileNameAndPath]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to open file: %s libDSM errorCode: %d", fileNameAndPath, openFileResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-5 userInfo:errorMessage];
        return NULL;
    }
    
    // loop through the file's bytes and read them until there are no more bytes to read
    ssize_t bytesRead = 0; // variable to contain the total number of bytes read from opened file
    do
    {
        // read bytes from file into buffer
        bytesRead = smb_fread(smbSession, fileDescriptor, readBuffer, 65535);
        
        // check if any bytes were read
        if(bytesRead > 0)
        {
            // append the read buffer into the fileContent result that would be returned
            [fileContent appendFormat:@"%s", readBuffer];
            // debug print
            [self logLine:[NSString stringWithFormat:@"%s\n", readBuffer]];
        }
    } while (bytesRead > 0);
    
    // deallocation - close file
    smb_fclose(smbSession, fileDescriptor);
    
    // deallocation - close session
    smb_session_destroy(smbSession);
    
    // deallocation - destroy the netbios service object since we don't need it anymore
    netbios_ns_destroy(netbiosNameService);
    
    // return the read file as a string
    return fileContent;
}

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
                       error:(NSError **)error
{
    // convert incomming shareHostName parameter into a local const char hostName variable
    const char * hostName = [shareHostName cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming user parameter into a local const char userName variable
    const char * userName = [user cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming password parameter into a local const char loginPassword variable
    const char * loginPassword = [password cStringUsingEncoding:NSUTF8StringEncoding];
    
    // strip the filePath of its first '/' if it exists
    if([filePath hasPrefix: @"/"])
    {
        filePath = [filePath substringFromIndex:1];
    }
    
    // change every '/' to '\\'
    if([filePath containsString: @"/"])
    {
        filePath = [filePath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    }
    
    // convert incomming filePath parameter into a local const char fileNameAndPath variable
    const char * fileNameAndPath = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    // convert incomming shareName parameter into a local const char sharedFolder variable
    const char * sharedFolder = [shareName cStringUsingEncoding:NSUTF8StringEncoding];
    
    // variable to contain the ip address of the destination host
    struct sockaddr_in ipAddress;
    
    // variable to contain a NetBios name service
    netbios_ns * netbiosNameService;
    
    // variable to contain the SMB created session
    smb_session * smbSession;
    
    // the connected share id (share descriptor)
    smb_tid shareID;
    
    // the requested and opened file descriptor
    smb_fd fileDescriptor;
    
    // create a NetBios name service instance
    netbiosNameService = netbios_ns_new();
    
    // make sure the requested host is resolveable and fetch it's IP address, otherwise - return error code
    int resolveResult = netbios_ns_resolve(netbiosNameService, hostName, NETBIOS_FILESERVER, &ipAddress.sin_addr.s_addr);
    
    if (resolveResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully reversed lookup host: %s into IP address: %s\n", hostName, inet_ntoa(ipAddress.sin_addr)]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to reverse lookup, could not resolve the host: %s IP address, libDSM errorCode: %d", hostName, resolveResult];
        [self logLine:errorMessageString];
        
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-1 userInfo:errorMessage];
        return -1;
    }
    
    // create a new SMB session
    smbSession = smb_session_new();
    
    // try to connect to the requested host using the resolved IP address using a TCP connection
    int connectResult = smb_session_connect(smbSession, hostName, ipAddress.sin_addr.s_addr, SMB_TRANSPORT_TCP);
    
    // make sure the connection to the requested host has succeeded, else return error
    if (connectResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully connected to %s\n", hostName]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed connecting to host: %s, libDSM returned errorCode:%d", hostName, connectResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-2 userInfo:errorMessage];
        return -1;
    }
    
    // login to the host using the userName and loginPassword
    smb_session_set_creds(smbSession, hostName, userName, loginPassword);
    
    // try to login to the connected host with the supplied user and password
    int loginResult = smb_session_login(smbSession);
    
    // check if the login is successful, and if it used a Guest user or the supplied credentials
    if (loginResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully loggedin to host: %s as user: %s\n", hostName, userName]];
    }
    else if (loginResult == 1)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"successfully login using a Guest user, due to failiour with supplied user and password\n"]];
    }
    else if (loginResult == -1)
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to login to host: %s as user: %s, and also failed to login as guest", hostName, userName];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-3 userInfo:errorMessage];
        return -1;
    }
    
    // connect to the requested share folder
    int shareConnectResult = smb_tree_connect(smbSession, sharedFolder, &shareID);
    
    // check if connection to the shared folder was successful
    if (shareConnectResult == 0)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully connected to share: %s\n", sharedFolder]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to connect to share: %s libDSM errorCode: %d", sharedFolder, shareConnectResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-4 userInfo:errorMessage];
        return -1;
    }
    
    // check if append requested, open the file in the requested manner (ReadWrite or Append)
    int openFileResult = -1;
    if(append)
    {
        // open the requested file (using connected share) in a Append mode
        openFileResult = smb_fopen(smbSession, shareID, fileNameAndPath, SMB_MOD_APPEND, &fileDescriptor);
    }
    else
    {
        // open the requested file (using connected share) in a Read/Write mode
        openFileResult = smb_fopen(smbSession, shareID, fileNameAndPath, SMB_MOD_RW, &fileDescriptor);
    }
    
    // make sure file was opened successfully
    if (!openFileResult)
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully opened file: %s\n", fileNameAndPath]];
    }
    else
    {
        // debug print
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to open file: %s libDSM errorCode: %d", fileNameAndPath, openFileResult];
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-5 userInfo:errorMessage];
        return -1;
    }
    
    // if append requested, then get current file size and set write pointer to the end of the file
    if(append)
    {
        // fetch the file stat (file metadata information)
        smb_stat fileStats = smb_stat_fd(smbSession, fileDescriptor);
        
        if(fileStats != NULL)
        {
            uint64_t fileSize = smb_stat_get(fileStats, SMB_STAT_SIZE);
            
            ssize_t currentFileSize = smb_fseek(smbSession, fileDescriptor, fileSize, SMB_SEEK_SET);
            [self logLine:[NSString stringWithFormat:@"%zd", currentFileSize]];
        }
        else
        {
            // debug print
            NSString * errorMessageString = [NSString stringWithFormat:@"Failed to get metadate of file: %s", fileNameAndPath];
            [self logLine:errorMessageString];
            
            // return relevant error message
            NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
            [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"SMBError" code:-6 userInfo:errorMessage];
            return -1;
        }
    }
    
    ssize_t writtenBytes = 0;
    ssize_t totalWrittenBytes = 0;
    ssize_t textLength = strlen([textToWrite UTF8String]);
    ssize_t charactersRemainingToWrite = 0;
    // substring the textToWrite from the last written position until the end of the string
    do
    {
        // calculate the length of characters remained to write
        charactersRemainingToWrite = textLength - totalWrittenBytes;
        
        // create a char array in the length of the characters that were not written yet
        char nextBufferToWrite[charactersRemainingToWrite + 1];
        
        // copy from the original textToWrite char array the characters that were not written yet into the new array
        memcpy(nextBufferToWrite, &[textToWrite UTF8String][totalWrittenBytes], charactersRemainingToWrite);
        
        // add at the last position of the array the null character (since strlen doesn't count it and memcpy doesn't copy it)
        nextBufferToWrite[charactersRemainingToWrite] = '\0';
        
        // write the nextBufferToWrite text into supplied file path and name
        writtenBytes = smb_fwrite(smbSession, fileDescriptor, (void *)nextBufferToWrite, charactersRemainingToWrite);
        
        // if bytes were written then add their total to the totalWrittenBytes accumelator
        if(writtenBytes > 0)
        {
            totalWrittenBytes = totalWrittenBytes + writtenBytes;
        }
    } while (totalWrittenBytes < textLength && writtenBytes > 0);
    
    // deallocation - close file
    smb_fclose(smbSession, fileDescriptor);
    
    int writeResult = -1;
    
    if(writtenBytes == -1 || textLength != totalWrittenBytes)
    {
        NSString * errorMessageString = [NSString stringWithFormat:@"Failed to write full text to file: %s", fileNameAndPath];
        
        // debug print
        [self logLine:errorMessageString];
        
        // return relevant error message
        NSMutableDictionary* errorMessage = [NSMutableDictionary dictionary];
        [errorMessage setValue:errorMessageString forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"SMBError" code:-7 userInfo:errorMessage];
    }
    else
    {
        // debug print
        [self logLine:[NSString stringWithFormat:@"Successfully written bytes: %zd to file: %s\n", writtenBytes, fileNameAndPath]];
        writeResult = 0;
    }
    
    // deallocation - close session
    smb_session_destroy(smbSession);
    
    // deallocation - destroy the netbios service object since we don't need it anymore
    netbios_ns_destroy(netbiosNameService);
    
    return writeResult;
}

/**
 * this method log message using printf depending on the debug member value (if debug == YES),
 * also append each end of log line with \n (new line)
 */
-(void) logLine:(NSString *) logMessage
{
    if(debug)
    {
        printf("%s\n", [logMessage UTF8String]);
    }
}

@end
