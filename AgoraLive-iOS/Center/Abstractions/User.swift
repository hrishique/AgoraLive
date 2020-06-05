//
//  User.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/9.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

protocol UserInfoProtocol {
    var info: BasicUserInfo {get set}
}

struct BasicUserInfo {
    var userId: String
    var name: String
    var headURL: String
    var imageIndex: Int
    
    init(dic: StringAnyDic) throws {
        self.userId = try dic.getStringValue(of: "userId")
        self.name = try dic.getStringValue(of: "userName")
        self.headURL = (try? dic.getStringValue(of: "avatar")) ?? ""
        self.imageIndex = Int(Int64(self.userId)! % 12)
    }
    
    init(userId: String, name: String, headURL: String = "", imageIndex: Int = 0) {
        self.userId = userId
        self.name = name
        self.headURL = headURL
        self.imageIndex = 0
    }
}

class CurrentUser: NSObject, UserInfoProtocol {
    struct UpdateInfo: InfoDic {
        var userName: String?
        var headURL: String?
        
        func dic() -> [String : Any] {
            var dic = StringAnyDic()
            if let userName = userName {
                dic["userName"] = userName
            }
            
            if let headURL = headURL {
                dic["headURL"] = headURL
            }
            return dic
        }
    }
    
    var info: BasicUserInfo {
        didSet {
            publicInfo.accept(info)
        }
    }
    
    var publicInfo = BehaviorRelay(value: BasicUserInfo(userId: "", name: "", headURL: ""))
    
    static func local() -> CurrentUser? {
        guard let userId = UserDefaults.standard.string(forKey: "UserId") else {
            return nil
        }
        
        let userHelper = ALCenter.shared().centerProvideUserDataHelper()
        
        guard let userData = userHelper.fetch(userId) else {
            return nil
        }
        
        let info = BasicUserInfo(userId: userId, name: userData.name!, headURL: "")
        let current = CurrentUser(info: info)
        return current
    }
    
    init(info: BasicUserInfo) {
        self.info = info
        self.publicInfo.accept(info)
        super.init()
        self.localStorage()
    }
    
    func updateInfo(_ new: UpdateInfo, success: Completion, fail: Completion = nil) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        
        let url = URLGroup.userUpdateInfo(userId: self.info.userId)
        let event = RequestEvent(name: "user-updateInfo")
        let task = RequestTask(event: event,
                               type: .http(.post, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: new.dic())
        let successCallback: Completion = { [unowned self] in
            var newInfo = self.info
            
            if let newName = new.userName {
                newInfo.name = newName
            }
            
            if let newHeadURL = new.headURL {
                newInfo.headURL = newHeadURL
            }
            
            self.info = newInfo
            self.localStorage()
            if let success = success {
                success()
            }
        }
        let response = AGEResponse.blank(successCallback)
        
        let retry: ErrorRetryCompletion = { (error: AGEError) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
}

private extension CurrentUser {
    func localStorage() {
        UserDefaults.standard.setValue(self.info.userId, forKey: "UserId")
        let userHelper = ALCenter.shared().centerProvideUserDataHelper()
        
        if let _ = userHelper.fetch(self.info.userId) {
            userHelper.modify(self)
        } else {
            userHelper.insert(self)
        }
    }
}
