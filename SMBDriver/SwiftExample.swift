//
//  SwiftExample.swift
//  SMBDriver
//
//  Created by Shay BC on 02/05/16.
//  Copyright © 2016 Obyect. All rights reserved.
//

import Foundation
import UIKit

class MediaDiscoveryViewController: UIViewController
{
    
    /**
     * view loaded, execute the example code
     */
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
//        //init the SMBDriver
//        let smbDriver: SMBDriver = SMBDriver()
//
//        // run the write test method
//        smbDriver.testWrite()
//        
//        // run the read test method
//        smbDriver.testRead()
//        
        // write content to file
        self.writeTextToFile()
        
        // read the file content
        self.readTextFromFile()
    }
    
    func writeTextToFile()
    {
        // variable to contain the write method returning value
        var writeResult: Int32 = -1
        
        // variable to contain the returning NSError (in case error occure)
        var error: NSError?
        
        // init the SMBDriver
        let smbDriver: SMBDriver = SMBDriver()
        
        // set debug mode to true
        smbDriver.debug = true
        
        // set the connect data you would like to use while writing
        let hostName: String = "MyPC"
        let userName: String = "test"
        let loginPassword: String = "1234"
        let fileNameAndPath: String = "/test.txt"
        let sharedFolder: String = "MyShare"
        
        // set the text you would like to write to the file
        let textToWrite: String = "This is my first line (1)\nthis is the second line (2)!"
        
        // write a string to a text file on SMB share, if the file does not exists (and the user has write permissions) the file will be created
        // if the file does exist - the file will be overwritten
        writeResult = smbDriver.writeTextFileFromHost(hostName, withLogin: userName, withPassword: loginPassword, withFileName: fileNameAndPath, onShare: sharedFolder, textToWrite: textToWrite, append: false, error: &error)
        
        if(writeResult == 0)
        {
            NSLog("Successfully written file")
        }
        else
        {
            NSLog("failed to write file content, errorCode: \(error!.code), errorMessage: \(error!.localizedDescription)");
        }
    }
    
    func readTextFromFile()
    {
        // variable to contain the read method returning value
        var fileContent: String = ""
        
        // init the SMBDriver
        let smbDriver: SMBDriver = SMBDriver()
        
        // set debug mode to true
        smbDriver.debug = true
        
        // set the connect data you would like to use while writing
        let hostName: String = "MyPC"
        let userName: String = "test"
        let loginPassword: String = "1234"
        let fileNameAndPath: String = "/test.txt"
        let sharedFolder: String = "MyShare"
        
        do
        {
            // write a string to a text file on SMB share, if the file does not exists (and the user has write permissions) the file will be created
            // if the file does exist - the file will be overwritten
            fileContent = try smbDriver.readTextFileFromHost(hostName, withLogin: userName, withPassword: loginPassword, withFileName: fileNameAndPath, onShare: sharedFolder)
            NSLog("Successfully read file, here is its content:\n\(fileContent)")
        }
        catch
        {
            NSLog("failed to write file content, errorCode: \((error as NSError).code), errorMessage: \((error as NSError).localizedDescription)");
        }
    }
}