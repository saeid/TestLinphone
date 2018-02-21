//
//  Manager.swift
//  TestVoip
//
//  Created by Saeid Basirnia on 2/20/18.
//  Copyright © 2018 Saeid. All rights reserved.
//

import Foundation



var answerCall: Bool = false

struct theLinphone {
    static var lc: OpaquePointer?
    static var lct: LinphoneCoreVTable?
    static var manager: LinphoneManager?
}

let registrationStateChanged: LinphoneCoreRegistrationStateChangedCb  = {
    (lc: Optional<OpaquePointer>, proxyConfig: Optional<OpaquePointer>, state: _LinphoneRegistrationState, message: Optional<UnsafePointer<Int8>>) in
    
    switch state{
    case LinphoneRegistrationNone: /**<Initial state for registrations */
        print("Hey!!! LinphoneRegistrationNone")
        
    case LinphoneRegistrationProgress:
        print("Hey!!! LinphoneRegistrationProgress")
        
    case LinphoneRegistrationOk:
        print("Hey!!! LinphoneRegistrationOk")
        
    case LinphoneRegistrationCleared:
        print("Hey!!! LinphoneRegistrationCleared")
        
    case LinphoneRegistrationFailed:
        print("Hey!!! LinphoneRegistrationFailed")
        
    default:
        print("Hey!!! Unkown registration state")
    }
    } as LinphoneCoreRegistrationStateChangedCb

let callStateChanged: LinphoneCoreCallStateChangedCb = {
    (lc: Optional<OpaquePointer>, call: Optional<OpaquePointer>, callSate: LinphoneCallState,  message: Optional<UnsafePointer<Int8>>) in
    
    switch callSate{
    case LinphoneCallIncomingReceived: /**<This is a new incoming call */
        print("Hey!!! callStateChanged: LinphoneCallIncomingReceived")
        
        if answerCall{
            ms_usleep(3 * 1000 * 1000) // Wait 3 seconds to pickup
            linphone_call_accept_update(call, lc)
        }
        
    case LinphoneCallStreamsRunning: /**<The media streams are established and running*/
        print("Hey!!! callStateChanged: LinphoneCallStreamsRunning")
        
    case LinphoneCallError: /**<The call encountered an error*/
        print("Hey!!! callStateChanged: LinphoneCallError")
        
    default:
        print("Hey!!! Default call state")
    }
}


class LinphoneManager {
    static var iterateTimer: Timer?
    
    init(){
        theLinphone.lct = LinphoneCoreVTable()

        // Enable debug log to stdout
        linphone_logging_service_set_log_level(linphone_logging_service_get(), LinphoneLogLevelDebug)
        
        // Load config
        let configFilename = documentFile("linphonerc222")
        let factoryConfigFilename = bundleFile("linphonerc-factory")
        
        let configFilenamePtr: UnsafePointer<Int8> = configFilename.cString(using: String.Encoding.utf8.rawValue)!
        let factoryConfigFilenamePtr: UnsafePointer<Int8> = factoryConfigFilename.cString(using: String.Encoding.utf8.rawValue)!
//        let lpConfig = linphone_config_new_with_factory(configFilenamePtr, factoryConfigFilenamePtr)
        
        // Set Callback
        theLinphone.lct?.registration_state_changed = registrationStateChanged
        theLinphone.lct?.call_state_changed = callStateChanged
        
        let factory = linphone_factory_get()
        
        theLinphone.lc = linphone_factory_create_core(factory, nil, configFilenamePtr, factoryConfigFilenamePtr)
        
        // Set ring asset
        let ringbackPath = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("/ringback.wav").absoluteString
        linphone_core_set_ringback(theLinphone.lc, ringbackPath)
        
        let localRing = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("/toy-mono.wav").absoluteString
        linphone_core_set_ring(theLinphone.lc, localRing)
    }
    
    fileprivate func bundleFile(_ file: NSString) -> NSString{
        return Bundle.main.path(forResource: file.deletingPathExtension, ofType: file.pathExtension)! as NSString
    }
    
    fileprivate func documentFile(_ file: NSString) -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        
        let documentsPath: NSString = paths[0] as NSString
        return documentsPath.appendingPathComponent(file as String) as NSString
    }
    
    // This is the start point to know how linphone library works.
    func demo() {
        makeCall()
        // autoPickImcomingCall()
        // idle()
    }
    
    func makeCall(){
        let calleeAccount = "123456789"
        
        guard let _ = setIdentify() else {
            print("no identity")
            return
        }
        linphone_core_invite(theLinphone.lc, calleeAccount)
        setTimer()
    }
    
    func receiveCall(){
        guard let proxyConfig = setIdentify() else {
            print("no identity")
            return
        }
        register(proxyConfig)
        setTimer()
    }
    
    func idle(){
        guard let proxyConfig = setIdentify() else {
            print("no identity")
            return
        }
        register(proxyConfig)
        setTimer()
    }
    
    func setIdentify() -> OpaquePointer? {
        let account = "....." //// Put your account name here
        let domain = "......" //// Put your domain here
        let password = "......" //// Put your account password here
        let identity = "sip:" + account + "@" + domain
        
        
        /*create proxy config*/
        let proxy_cfg = linphone_core_create_proxy_config(theLinphone.lc)
        
        /*parse identity*/
        let from = linphone_address_new(identity)
        
        if (from == nil){
            print("\(identity) not a valid sip uri, must be like sip:toto@sip.linphone.org")
            return nil
        }
        
        let info=linphone_auth_info_new(linphone_address_get_username(from), nil, password, nil, nil, nil) /*create authentication structure from identity*/
        linphone_core_add_auth_info(theLinphone.lc, info) /*add authentication info to LinphoneCore*/
        
        // configure proxy entries
        linphone_proxy_config_set_identity_address(proxy_cfg, from)
        /*set identity with user name and domain*/
        let server_addr = String(cString: linphone_address_get_domain(from)) /*extract domain address from identity*/
        
        linphone_address_unref(from)
        /*release resource*/
        
        linphone_proxy_config_set_server_addr(proxy_cfg, server_addr) /* we assume domain = proxy server address*/
        linphone_proxy_config_enable_register(proxy_cfg, 0) /* activate registration for this proxy config*/
        linphone_core_add_proxy_config(theLinphone.lc, proxy_cfg) /*add proxy config to linphone core*/
        linphone_core_set_default_proxy_config(theLinphone.lc, proxy_cfg) /*set to default proxy*/
        
        return proxy_cfg!
    }
    
    func register(_ proxy_cfg: OpaquePointer){
        linphone_proxy_config_enable_register(proxy_cfg, 1) /* activate registration for this proxy config*/
    }
    
    func shutdown(){
        print("Shutdown..")
        
        let proxy_cfg = linphone_core_get_default_proxy_config(theLinphone.lc) /* get default proxy config*/
        linphone_proxy_config_edit(proxy_cfg) /*start editing proxy configuration*/
        linphone_proxy_config_enable_register(proxy_cfg, 0) /*de-activate registration for this proxy config*/
        linphone_proxy_config_done(proxy_cfg) /*initiate REGISTER with expire = 0*/
        while(linphone_proxy_config_get_state(proxy_cfg) !=  LinphoneRegistrationCleared){
            linphone_core_iterate(theLinphone.lc) /*to make sure we receive call backs before shutting down*/
            ms_usleep(50000)
        }
        
        linphone_core_unref(theLinphone.lc)
    }
    
    @objc func iterate(){
        if let lc = theLinphone.lc{
            linphone_core_iterate(lc) /* first iterate initiates registration */
        }
    }
    
    fileprivate func setTimer(){
        LinphoneManager.iterateTimer = Timer.scheduledTimer(
            timeInterval: 0.02, target: self, selector: #selector(iterate), userInfo: nil, repeats: true)
    }
}

