//
//  DataAPI.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/03/23.
//  Copyright (c) 2015年 Six Apart, Ltd. All rights reserved.
//

import UIKit
import Foundation
import Alamofire
import SwiftyJSON

public class DataAPI: NSObject {

    //MARK: - Properties
    fileprivate(set) var token = ""
    fileprivate(set) var sessionID = ""

    public var endpointVersion = "v3"
    public var APIBaseURL = "http://localhost/cgi-bin/MT-6.1/mt-data-api.cgi"
    
    fileprivate(set) var apiVersion = ""
    
    public var clientID = "MTDataAPIClient"

    public struct BasicAuth {
        public var username = ""
        public var password = ""
    }
    public var basicAuth: BasicAuth = BasicAuth()

    public static var sharedInstance = DataAPI()

    //MARK: - Methods
    fileprivate func APIURL() -> String! {
        return APIBaseURL + "/\(endpointVersion)"
    }

    fileprivate func APIURL_V2() -> String! {
        return APIBaseURL + "/v2"
    }
    
    func urlencoding(_ src: String) -> String! {
        return src.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
    }

    func urldecoding(_ src: String) -> String! {
        return src.removingPercentEncoding
    }

    func parseParams(_ originalUrl: String) -> [String: String] {
        let url = originalUrl.components(separatedBy: "?")
        let core = url[1]
        let params = core.components(separatedBy: "&")
        var dict : [String: String] = [:]

        for param in params{
            let keyValue = param.components(separatedBy: "=")
            dict[keyValue[0]] = keyValue[1]
        }
        return dict
    }

    fileprivate func errorJSON()->JSON {
        return JSON(["code":"-1", "message":NSLocalizedString("The operation couldn’t be completed.", comment: "The operation couldn’t be completed.")])
    }

    func resetAuth() {
        token = ""
        sessionID = ""
    }

    fileprivate func makeRequest(_ method: HTTPMethod, url: URLConvertible, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, useSession: Bool = (false)) -> DataRequest {
        var headers: [String: String] = [:]
        
        if token != "" {
            headers["X-MT-Authorization"] = "MTAuth accessToken=" + token
        }
        if useSession {
            if sessionID != "" {
                headers["X-MT-Authorization"] = "MTAuth sessionId=" + sessionID
            }
        }

        var request = Alamofire.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
        
        if !self.basicAuth.username.isEmpty && !self.basicAuth.password.isEmpty {
            request = request.authenticate(user: self.basicAuth.username, password: self.basicAuth.password)
        }

        return request
    }

    public func fetchList(_ url: String, params: Parameters? = nil, success: @escaping ((_ items:[JSON]?, _ total:Int?) -> Void!), failure: ((JSON?) -> Void)!)->Void {
        let request = makeRequest(.get, url: url, parameters: params)
        request.responseJSON { response in
            switch response.result {
                case .success(let data):
                    let json = JSON(data)
                    if json["error"].dictionary != nil {
                        failure(json["error"])
                        return
                    }
                    let items = json["items"].array
                    let total = json["totalResults"].intValue
                    success(items, total)
                
                case .failure(_):
                    failure(self.errorJSON())
            }
        }
    }

    fileprivate func actionCommon(_ action: HTTPMethod, url: String, params: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let request = makeRequest(action, url: url, parameters: params)
        request.responseJSON { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["error"].dictionary != nil {
                    failure(json["error"])
                    return
                }
                success(json)
                
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    func action(_ name: String, action: HTTPMethod, url: String, object: Parameters? = nil, options: Parameters?, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        if let object = object {
            let json = JSON(object).rawString()
            params[name] = json as AnyObject?
        }
        actionCommon(action, url: url, params: params, success: success, failure: failure)
    }

    fileprivate func get(_ url: String, params: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        actionCommon(.get, url: url, params: params, success: success, failure: failure)
    }

    fileprivate func post(_ url: String, params: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        actionCommon(.post, url: url, params: params, success: success, failure: failure)
    }

    fileprivate func put(_ url: String, params: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        actionCommon(.put, url: url, params: params, success: success, failure: failure)
    }

    fileprivate func delete(_ url: String, params: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        actionCommon(.delete, url: url, params: params, success: success, failure: failure)
    }

    fileprivate func repeatAction(_ action: HTTPMethod, url: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let request = makeRequest(action, url: url, parameters: options)
        request.responseJSON { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["error"].dictionary != nil {
                    failure(json["error"])
                    return
                }
                if json["status"].string == "Complete" || json["restIds"].string == "" {
                    success(json)
                } else {
                    let headers: NSDictionary = response.response!.allHeaderFields as NSDictionary
                    if let nextURL = headers["X-MT-Next-Phase-URL"] as? String {
                        let url = self.APIURL() + "/" + nextURL
                        self.repeatAction(action, url: url, options: options, success: success, failure: failure)
                    } else {
                        failure(self.errorJSON())
                    }
                }
                
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }
    
    
    func upload(_ data: Data, fileName: String, url: String, parameters: Parameters? = nil, progress: ((Double) -> Void)? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var headers = Dictionary<String, String>()
        
        if token != "" {
            headers["X-MT-Authorization"] = "MTAuth accessToken=" + token
        }
        
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(data, withName: "file", fileName: fileName, mimeType: "application/octet-stream")
                if let params = parameters {
                    for (key, value) in params {
                        multipartFormData.append((value as AnyObject).data(using: String.Encoding.utf8.rawValue)!, withName: key)
                    }
                }
            },
            to: url,
            method: .post,
            headers: headers,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    if !self.basicAuth.username.isEmpty && !self.basicAuth.password.isEmpty {
                        upload.authenticate(user: self.basicAuth.username, password: self.basicAuth.password)
                    }
                    upload.uploadProgress(queue: DispatchQueue.global(qos: .utility)) { uploadProgress in
                        progress?(uploadProgress.fractionCompleted)
                    }.responseJSON { response in
                        switch response.result {
                        case .success(let data):
                            let json = JSON(data)
                            if json["error"].dictionary != nil {
                                failure(json["error"])
                                return
                            }
                            success(json)
                            
                        case .failure(_):
                            failure(self.errorJSON())
                        }
                    }
                case .failure(_):
                    failure(self.errorJSON())
                }
            }
        )
    }

    //MARK: - APIs

    //MARK: - # V2
    //MARK: - System
    public func endpoints(_ success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/endpoints"

        self.fetchList(url, params: nil, success: success, failure: failure)
    }

    //MARK: - Authentication
    func authenticationCommon(_ url: String, username: String, password: String, remember: Bool, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        resetAuth()

        let params = ["username":username,
                      "password":password,
                      "remember":remember ? "1":"0",
                      "clientId":self.clientID]
        let request = makeRequest(.post, url: url, parameters: params)
        request.responseJSON { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["error"].dictionary != nil {
                    failure(json["error"])
                    return
                }
                if let accessToken = json["accessToken"].string {
                    self.token = accessToken
                }
                if let session = json["sessionId"].string {
                    self.sessionID = session
                }
                success(json)
                
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    public func authentication(_ username: String, password: String, remember: Bool, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/authentication"
        self.authenticationCommon(url, username: username, password: password, remember: remember, success: success, failure: failure)
    }

    public func authenticationV2(_ username: String, password: String, remember: Bool, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL_V2() + "/authentication"
        self.authenticationCommon(url, username: username, password: password, remember: remember, success: success, failure: failure)
    }
    
    public func getToken(_ success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/token"

        let request = makeRequest(.post, url: url, useSession: true)

        if sessionID == "" {
            failure(self.errorJSON())
            return
        }
        request.responseJSON { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["error"].dictionary != nil {
                    failure(json["error"])
                    return
                }
                if let accessToken = json["accessToken"].string {
                    self.token = accessToken
                }
                success(json)
                
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    public func revokeAuthentication(_ success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/authentication"

        let request = makeRequest(.delete, url: url)

        if sessionID == "" {
            failure(self.errorJSON())
            return
        }
        request.responseJSON { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["error"].dictionary != nil {
                    failure(json["error"])
                    return
                }
                self.sessionID = ""
                success(json)
                
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    public func revokeToken(_ success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/token"

        self.delete(url, success: {
            (result: JSON?)-> Void in
                self.token = ""
                success(result)
            },
            failure: failure)
    }

    //MARK: - Search
    public func search(_ query: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/search"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        params["search"] = query as AnyObject?

        self.fetchList(url, params: params, success: success, failure: failure)
    }

    //MARK: - Site
    public func listSites(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listSitesByParent(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/children"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func siteAction(_ action: HTTPMethod, siteID: String?, site: Parameters?, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites"
        if action != .post {
            if let id = siteID {
                url += "/" + id
            }
        }

        self.action("website", action: action, url: url, object: site, options: options, success: success, failure: failure)
    }

    public func createSite(_ site: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.siteAction(.post, siteID: nil, site: site, options: options, success: success, failure: failure)
    }

    public func getSite(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.siteAction(.get, siteID: siteID, site: nil, options: options, success: success, failure: failure)
    }

    public func updateSite(siteID: String, site: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.siteAction(.put, siteID: siteID, site: site, options: options, success: success, failure: failure)
    }

    public func deleteSite(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.siteAction(.delete, siteID: siteID, site: nil, options: options, success: success, failure: failure)
    }

    public func backupSite(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/backup"

        self.get(url, params: options, success: success, failure: failure)
    }

    //MARK: - Blog
    public func listBlogsForUser(_ userID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/sites"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func blogAction(_ action: HTTPMethod, blogID: String?, blog: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites"
        if let id = blogID {
            url += "/" + id
        }

        self.action("blog", action: action, url: url, object: blog, options: options, success: success, failure: failure)
    }

    public func createBlog(_ blog: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.blogAction(.post, blogID: nil, blog: blog, options: options, success: success, failure: failure)
    }

    public func getBlog(_ blogID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.blogAction(.get, blogID: blogID, blog: nil, options: options, success: success, failure: failure)
    }

    public func updateBlog(_ blogID: String, blog: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.blogAction(.put, blogID: blogID, blog: blog, options: options, success: success, failure: failure)
    }

    public func deleteBlog(_ blogID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.blogAction(.delete, blogID: blogID, blog: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Entry
    public func listEntries(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func entryAction(_ action: HTTPMethod, siteID: String, entryID: String? = nil, entry: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/entries"
        if action != .post {
            if let id = entryID {
                url += "/" + id
            }
        }

        self.action("entry", action: action, url: url, object: entry, options: options, success: success, failure: failure)
    }

    public func createEntry(siteID: String, entry: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.entryAction(.post, siteID: siteID, entryID: nil, entry: entry, options: options, success: success, failure: failure)
    }

    public func getEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.entryAction(.get, siteID: siteID, entryID: entryID, entry: nil, options: options, success: success, failure: failure)
    }

    public func updateEntry(siteID: String, entryID: String, entry: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.entryAction(.put, siteID: siteID, entryID: entryID, entry: entry, options: options, success: success, failure: failure)
    }

    public func deleteEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.entryAction(.delete, siteID: siteID, entryID: entryID, entry: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listEntriesForObject(_ objectName: String, siteID: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:categories,assets,tags
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/entries"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listEntriesForCategory(siteID: String, categoryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listEntriesForObject("categories", siteID: siteID, objectID: categoryID, options: options, success: success, failure: failure)
    }

    public func listEntriesForAsset(siteID: String, assetID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listEntriesForObject("assets", siteID: siteID, objectID: assetID, options: options, success: success, failure: failure)
    }

    public func listEntriesForSiteAndTag(siteID: String, tagID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listEntriesForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    public func exportEntries(siteID: String, options: Parameters? = nil, success: ((String?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/export"

        let request = makeRequest(.get, url: url, parameters: options)
        request.responseData{(response) -> Void in
            switch response.result {
            case .success(let data):
                let result: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
                if (result.hasPrefix("{\"error\":")) {
                    let json = JSON(data:data)
                    failure(json["error"])
                    return
                }
                success(result)
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    public func publishEntries(_ entryIDs: [String], options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/publish/entries"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        params["ids"] = entryIDs.joined(separator: ",") as AnyObject?

        self.repeatAction(.get, url: url, options: params, success: success, failure: failure)
    }


    fileprivate func importEntriesWithFile(siteID: String, importData: Data, options: Parameters? = nil, progress: ((Double) -> Void)? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/import"

        self.upload(importData, fileName: "import.dat", url: url, parameters: options, progress: progress, success: success, failure: failure)
    }

    public func importEntries(siteID: String, importData: Data? = nil, options: Parameters? = nil, progress: ((Double) -> Void)? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        if importData != nil {
            self.importEntriesWithFile(siteID: siteID, importData: importData!, options: options, progress: progress, success: success, failure: failure)
            return
        }

        let url = APIURL() + "/sites/\(siteID)/entries/import"

        self.post(url, params: options as [String : AnyObject]?, success: success, failure: failure)
    }
    
    public func previewEntry(siteID: String, entryID: String? = nil, entry: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/entries"
        if let id = entryID {
            url += "/\(id)/preview"
        } else {
            url += "/preview"
        }
        
        self.action("entry", action: .post, url: url, object: entry, options: options, success: success, failure: failure)
    }

    //MARK: - Page
    public func listPages(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/pages"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func pageAction(_ action: HTTPMethod, siteID: String, pageID: String? = nil, page: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/pages"
        if action != .post {
            if let id = pageID {
                url += "/" + id
            }
        }

        self.action("page", action: action, url: url, object: page, options: options, success: success, failure: failure)
    }

    public func createPage(siteID: String, page: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.pageAction(.post, siteID: siteID, pageID: nil, page: page, options: options, success: success, failure: failure)
    }

    public func getPage(siteID: String, pageID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.pageAction(.get, siteID: siteID, pageID: pageID, page: nil, options: options, success: success, failure: failure)
    }

    public func updatePage(siteID: String, pageID: String, page: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.pageAction(.put, siteID: siteID, pageID: pageID, page: page, options: options, success: success, failure: failure)
    }

    public func deletePage(siteID: String, pageID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.pageAction(.delete, siteID: siteID, pageID: pageID, page: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listPagesForObject(_ objectName: String, siteID: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:assets,tags,folders
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/pages"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listPagesForFolder(siteID: String, folderID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listPagesForObject("folders", siteID: siteID, objectID: folderID, options: options, success: success, failure: failure)
    }

    public func listPagesForAsset(siteID: String, assetID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listPagesForObject("assets", siteID: siteID, objectID: assetID, options: options, success: success, failure: failure)
    }

    public func listPagesForSiteAndTag(siteID: String, tagID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listPagesForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    public func previewPage(siteID: String, pageID: String? = nil, entry: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/pages"
        if let id = pageID {
            url += "/\(id)/preview"
        } else {
            url += "/preview"
        }
        
        self.action("page", action: .post, url: url, object: entry, options: options, success: success, failure: failure)
    }

    //MARK: - Category
    public func listCategories(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/categories"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func categoryAction(_ action: HTTPMethod, siteID: String, categoryID: String? = nil, category: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/categories"
        if action != .post {
            if let id = categoryID {
                url += "/" + id
            }
        }

        self.action("category", action: action, url: url, object: category, options: options, success: success, failure: failure)
    }

    public func createCategory(siteID: String, category: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.categoryAction(.post, siteID: siteID, categoryID: nil, category: category, options: options, success: success, failure: failure)
    }

    public func getCategory(siteID: String, categoryID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.categoryAction(.get, siteID: siteID, categoryID: categoryID, category: nil, options: options, success: success, failure: failure)
    }

    public func updateCategory(siteID: String, categoryID: String, category: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.categoryAction(.put, siteID: siteID, categoryID: categoryID, category: category, options: options, success: success, failure: failure)
    }

    public func deleteCategory(siteID: String, categoryID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.categoryAction(.delete, siteID: siteID, categoryID: categoryID, category: nil, options: options, success: success, failure: failure)
    }

    public func listCategoriesForEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/entries/\(entryID)/categories"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func listCategoriesForRelation(_ relation: String, siteID: String, categoryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //relation:parents,siblings,children
        let url = APIURL() + "/sites/\(siteID)/categories/\(categoryID)/\(relation)"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listParentCategories(siteID: String, categoryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listCategoriesForRelation("parents", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    public func listSiblingCategories(siteID: String, categoryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listCategoriesForRelation("siblings", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    public func listChildCategories(siteID: String, categoryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listCategoriesForRelation("children", siteID: siteID, categoryID: categoryID, options: options, success: success, failure: failure)
    }

    public func permutateCategories(siteID: String, categories: [Parameters]? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/categories/permutate"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        if let categories = categories {
            let json = JSON(categories).rawString()
            params["categories"] = json as AnyObject?
        }

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Folder
    public func listFolders(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/folders"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func folderAction(_ action: HTTPMethod, siteID: String, folderID: String? = nil, folder: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/folders"
        if let id = folderID {
            url += "/" + id
        }

        self.action("folder", action: action, url: url, object: folder, options: options, success: success, failure: failure)
    }

    public func createFolder(siteID: String, folder: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.folderAction(.post, siteID: siteID, folderID: nil, folder: folder, options: options, success: success, failure: failure)
    }

    public func getFolder(siteID: String, folderID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.folderAction(.get, siteID: siteID, folderID: folderID, folder: nil, options: options, success: success, failure: failure)
    }

    public func updateFolder(siteID: String, folderID: String, folder: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.folderAction(.put, siteID: siteID, folderID: folderID, folder: folder, options: options, success: success, failure: failure)
    }

    public func deleteFolder(siteID: String, folderID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.folderAction(.delete, siteID: siteID, folderID: folderID, folder: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listFoldersForRelation(_ relation: String, siteID: String, folderID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //relation:parents,siblings,children
        let url = APIURL() + "/sites/\(siteID)/folders/\(folderID)/\(relation)"

        self.fetchList(url, params: options, success: success, failure: failure)
    }
    
    public func listParentFolders(siteID: String, folderID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listFoldersForRelation("parents", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    public func listSiblingFolders(siteID: String, folderID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listFoldersForRelation("siblings", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    public func listChildFolders(siteID: String, folderID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listFoldersForRelation("children", siteID: siteID, folderID: folderID, options: options, success: success, failure: failure)
    }

    public func permutateFolders(siteID: String, folders: [Parameters]? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/folders/permutate"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        if let folders = folders {
            let json = JSON(folders).rawString()
            params["folders"] = json as AnyObject?
        }

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Tag
    public func listTags(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/tags"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func tagAction(_ action: HTTPMethod, siteID: String, tagID: String, tag: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        if action == .post {
            failure(self.errorJSON())
            return
        }
        let url = APIURL() + "/sites/\(siteID)/tags/\(tagID)"

        self.action("tag", action: action, url: url, object: tag, options: options, success: success, failure: failure)
    }

    public func getTag(siteID: String, tagID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.tagAction(.get, siteID: siteID, tagID: tagID, tag: nil, options: options, success: success, failure: failure)
    }

    public func updateTag(siteID: String, tagID: String, tag: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.tagAction(.put, siteID: siteID, tagID: tagID, tag: tag, options: options, success: success, failure: failure)
    }

    public func deleteTag(siteID: String, tagID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.tagAction(.delete, siteID: siteID, tagID: tagID, tag: nil, options: options, success: success, failure: failure)
    }

    //MARK: - User
    public func listUsers(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/users"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func userAction(_ action: HTTPMethod, userID: String? = nil, user: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/users"
        if action != .post {
            if let id = userID {
                url += "/" + id
            }
        }

        self.action("user", action: action, url: url, object: user, options: options, success: success, failure: failure)
    }

    public func createUser(_ user: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.userAction(.post, userID: nil, user: user, options: options, success: success, failure: failure)
    }

    public func getUser(_ userID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.userAction(.get, userID: userID, user: nil, options: options, success: success, failure: failure)
    }

    public func updateUser(_ userID: String, user: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.userAction(.put, userID: userID, user: user, options: options, success: success, failure: failure)
    }

    public func deleteUser(_ userID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.userAction(.delete, userID: userID, user: nil, options: options, success: success, failure: failure)
    }

    public func unlockUser(_ userID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/unlock"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func recoverPasswordForUser(_ userID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/recover_password"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func recoverPassword(_ name: String, email: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/recover_password"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }

        params["name"] = name as AnyObject?
        params["email"] = email as AnyObject?

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Asset
    public func listAssets(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/assets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }
    
    public func uploadAsset(_ assetData: Data, fileName: String, options: Parameters? = nil, progress: ((Double) -> Void)? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.uploadAssetForSite(nil, assetData: assetData, fileName: fileName, options: options, progress: progress, success: success, failure: failure)
    }

    public func uploadAssetForSite(_ siteID: String? = nil, assetData: Data, fileName: String, options: Parameters? = nil, progress: ((Double) -> Void)? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/"
        if let siteID = siteID {
            url += "sites/\(siteID)/assets/upload"
        } else {
            url += "assets/upload"
        }

        self.upload(assetData, fileName: fileName, url: url, parameters: options, progress: progress, success: success, failure: failure)
    }

    fileprivate func assetAction(_ action: HTTPMethod, siteID: String, assetID: String, asset: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/assets"
        if action != .post {
            url += "/" + assetID
        } else {
            failure(self.errorJSON())
            return
        }

        self.action("asset", action: action, url: url, object: asset, options: options, success: success, failure: failure)
    }

    public func getAsset(siteID: String, assetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.assetAction(.get, siteID: siteID, assetID: assetID, asset: nil, options: options, success: success, failure: failure)
    }

    public func updateAsset(siteID: String, assetID: String, asset: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.assetAction(.put, siteID: siteID, assetID: assetID, asset: asset, options: options, success: success, failure: failure)
    }

    public func deleteAsset(siteID: String, assetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.assetAction(.delete, siteID: siteID, assetID: assetID, asset: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listAssetsForObject(_ objectName: String, siteID: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:entries,pages,tags
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/assets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listAssetsForEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listAssetsForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    public func listAssetsForPage(siteID: String, pageID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listAssetsForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    public func listAssetsForSiteAndTag(siteID: String, tagID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.listAssetsForObject("tags", siteID: siteID, objectID: tagID, options: options, success: success, failure: failure)
    }

    public func getThumbnail(siteID: String, assetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/assets/\(assetID)/thumbnail"

        self.get(url, params: options, success: success, failure: failure)
    }

    //MARK: - Comment
    public func listComments(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/comments"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func commentAction(_ action: HTTPMethod, siteID: String, commentID: String, comment: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/comments"
        if action != .post {
            url += "/" + commentID
        } else {
            //use createCommentForEntry or createCommentForPage
            failure(self.errorJSON())
            return
        }

        self.action("comment", action: action, url: url, object: comment, options: options, success: success, failure: failure)
    }

    public func getComment(siteID: String, commentID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.commentAction(.get, siteID: siteID, commentID: commentID, comment: nil, options: options, success: success, failure: failure)
    }

    public func updateComment(siteID: String, commentID: String, comment: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.commentAction(.put, siteID: siteID, commentID: commentID, comment: comment, options: options, success: success, failure: failure)
    }

    public func deleteComment(siteID: String, commentID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.commentAction(.delete, siteID: siteID, commentID: commentID, comment: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listCommentsForObject(_ objectName: String, siteID: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listCommentsForEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listCommentsForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    public func listCommentsForPage(siteID: String, pageID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listCommentsForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    fileprivate func createCommentForObject(_ objectName: String, siteID: String, objectID: String, comment: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments"

        self.action("comment", action: .post, url: url, object: comment, options: options, success: success, failure: failure)
    }

    public func createCommentForEntry(siteID: String, entryID: String, comment: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.createCommentForObject("entries", siteID: siteID, objectID: entryID, comment: comment, options: options, success: success, failure: failure)
    }

    public func createCommentForPage(siteID: String, pageID: String, comment: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.createCommentForObject("pages", siteID: siteID, objectID: pageID, comment: comment, options: options, success: success, failure: failure)
    }

    fileprivate func createReplyCommentForObject(_ objectName: String, siteID: String, objectID: String, commentID: String, reply: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/comments/\(commentID)/replies"

        self.action("comment", action: .post, url: url, object: reply, options: options, success: success, failure: failure)
    }

    public func createReplyCommentForEntry(siteID: String, entryID: String, commentID: String, reply: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.createReplyCommentForObject("entries", siteID: siteID, objectID: entryID, commentID: commentID, reply: reply, options: options, success: success, failure: failure)
    }

    public func createReplyCommentForPage(siteID: String, pageID: String, commentID: String, reply: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.createReplyCommentForObject("pages", siteID: siteID, objectID: pageID, commentID: commentID, reply: reply, options: options, success: success, failure: failure)
    }

    //MARK: - Trackback
    public func listTrackbacks(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/trackbacks"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func trackbackAction(_ action: HTTPMethod, siteID: String, trackbackID: String, trackback: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/trackbacks"
        if action != .post {
            url += "/" + trackbackID
        } else {
            failure(self.errorJSON())
            return
        }

        self.action("comment", action: action, url: url, object: trackback, options: options, success: success, failure: failure)
    }

    public func getTrackback(siteID: String, trackbackID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.trackbackAction(.get, siteID: siteID, trackbackID: trackbackID, trackback: nil, options: options, success: success, failure: failure)
    }

    public func updateTrackback(siteID: String, trackbackID: String, trackback: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.trackbackAction(.put, siteID: siteID, trackbackID: trackbackID, trackback: trackback, options: options, success: success, failure: failure)
    }

    public func deleteTrackback(siteID: String, trackbackID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.trackbackAction(.delete, siteID: siteID, trackbackID: trackbackID, trackback: nil, options: options, success: success, failure: failure)
    }

    fileprivate func listTrackbackForObject(_ objectName: String, siteID: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:entries,pages
        let url = APIURL() + "/sites/\(siteID)/\(objectName)/\(objectID)/trackbacks"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listTrackbackForEntry(siteID: String, entryID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listTrackbackForObject("entries", siteID: siteID, objectID: entryID, options: options, success: success, failure: failure)
    }

    public func listTrackbackForPage(siteID: String, pageID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listTrackbackForObject("pages", siteID: siteID, objectID: pageID, options: options, success: success, failure: failure)
    }

    //MARK: - Field
    public func listFields(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/fields"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func fieldAction(_ action: HTTPMethod, siteID: String, fieldID: String? = nil, field: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/fields"
        if action != .post {
            if let fieldID = fieldID {
                url += "/" + fieldID
            }
        }

        self.action("field", action: action, url: url, object: field, options: options, success: success, failure: failure)
    }

    public func createField(siteID: String, field: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.fieldAction(.post, siteID: siteID, fieldID: nil, field: field, options: options, success: success, failure: failure)
    }

    public func getField(siteID: String, fieldID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.fieldAction(.get, siteID: siteID, fieldID: fieldID, field: nil, options: options, success: success, failure: failure)
    }

    public func updateField(siteID: String, fieldID: String, field: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.fieldAction(.put, siteID: siteID, fieldID: fieldID, field: field, options: options, success: success, failure: failure)
    }

    public func deleteField(siteID: String, fieldID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.fieldAction(.delete, siteID: siteID, fieldID: fieldID, field: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Template
    public func listTemplates(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func templateAction(_ action: HTTPMethod, siteID: String, templateID: String? = nil, template: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/templates"
        if action != .post {
            if let id = templateID {
                url += "/" + id
            }
        }

        self.action("template", action: action, url: url, object: template, options: options, success: success, failure: failure)
    }

    public func createTemplate(siteID: String, template: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.templateAction(.post, siteID: siteID, templateID: nil, template: template, options: options, success: success, failure: failure)
    }

    public func getTemplate(siteID: String, templateID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.templateAction(.get, siteID: siteID, templateID: templateID, template: nil, options: options, success: success, failure: failure)
    }

    public func updateTemplate(siteID: String, templateID: String, template: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.templateAction(.put, siteID: siteID, templateID: templateID, template: template, options: options, success: success, failure: failure)
    }

    public func deleteTemplate(siteID: String, templateID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.templateAction(.delete, siteID: siteID, templateID: templateID, template: nil, options: options, success: success, failure: failure)
    }

    public func publishTemplate(siteID: String, templateID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/publish"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func refreshTemplate(siteID: String, templateID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/refresh"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func refreshTemplateForSite(_ siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/refresh_templates"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func cloneTemplate(siteID: String, templateID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/clone"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - TemplateMap
    public func listTemplateMaps(siteID: String, templateID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/templatemaps"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func templateMapAction(_ action: HTTPMethod, siteID: String, templateID: String, templateMapID: String? = nil, templateMap: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/templates/\(templateID)/templatemaps"
        if action != .post {
            if let id = templateMapID {
                url += "/" + id
            }
        }

        self.action("templatemap", action: action, url: url, object: templateMap, options: options, success: success, failure: failure)
    }

    public func createTemplateMap(siteID: String, templateID: String, templateMap: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.templateMapAction(.post, siteID: siteID, templateID: templateID, templateMapID: nil, templateMap: templateMap, options: options, success: success, failure: failure)
    }

    public func getTemplateMap(siteID: String, templateID: String, templateMapID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.templateMapAction(.get, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: nil, options: options, success: success, failure: failure)
    }

    public func updateTemplateMap(siteID: String, templateID: String, templateMapID: String, templateMap: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.templateMapAction(.put, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: templateMap, options: options, success: success, failure: failure)
    }

    public func deleteTemplateMap(siteID: String, templateID: String, templateMapID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.templateMapAction(.delete, siteID: siteID, templateID: templateID, templateMapID: templateMapID, templateMap: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Widget
    public func listWidgets(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listWidgetsForWidgetset(siteID: String, widgetsetID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets/\(widgetsetID)/widgets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func getWidgetForWidgetset(siteID: String, widgetSetID: String, widgetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets/\(widgetSetID)/widgets/\(widgetID)"

        self.action("widget", action: .get, url: url, options: options, success: success, failure: failure)
    }

    fileprivate func widgetAction(_ action: HTTPMethod, siteID: String, widgetID: String? = nil, widget: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/widgets"
        if action != .post {
            if let id = widgetID {
                url += "/" + id
            }
        }

        self.action("widget", action: action, url: url, object: widget, options: options, success: success, failure: failure)
    }

    public func createWidget(siteID: String, widget: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetAction(.post, siteID: siteID, widgetID: nil, widget: widget, options: options, success: success, failure: failure)
    }

    public func getWidget(siteID: String, widgetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetAction(.get, siteID: siteID, widgetID: widgetID, widget: nil, options: options, success: success, failure: failure)
    }

    public func updateWidget(siteID: String, widgetID: String, widget: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetAction(.put, siteID: siteID, widgetID: widgetID, widget: widget, options: options, success: success, failure: failure)
    }

    public func deleteWidget(siteID: String, widgetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetAction(.delete, siteID: siteID, widgetID: widgetID, widget: nil, options: options, success: success, failure: failure)
    }

    public func refreshWidget(siteID: String, widgetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets/\(widgetID)/refresh"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func cloneWidget(siteID: String, widgetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgets/\(widgetID)/clone"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - WidgetSet
    public func listWidgetSets(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/widgetsets"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func widgetSetAction(_ action: HTTPMethod, siteID: String, widgetSetID: String? = nil, widgetSet: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/widgetsets"
        if action != .post {
            if let id = widgetSetID {
                url += "/" + id
            }
        }

        self.action("widgetset", action: action, url: url, object: widgetSet, options: options, success: success, failure: failure)
    }

    public func createWidgetSet(siteID: String, widgetSet: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetSetAction(.post, siteID: siteID, widgetSetID: nil, widgetSet: widgetSet, options: options, success: success, failure: failure)
    }

    public func getWidgetSet(siteID: String, widgetSetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetSetAction(.get, siteID: siteID, widgetSetID: widgetSetID, widgetSet: nil, options: options, success: success, failure: failure)
    }

    public func updateWidgetSet(siteID: String, widgetSetID: String, widgetSet: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetSetAction(.put, siteID: siteID, widgetSetID: widgetSetID, widgetSet: widgetSet, options: options, success: success, failure: failure)
    }

    public func deleteWidgetSet(siteID: String, widgetSetID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.widgetSetAction(.delete, siteID: siteID, widgetSetID: widgetSetID, widgetSet: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Theme
    public func listThemes(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/themes"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func getTheme(_ themeID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/themes/\(themeID)"

        self.get(url, params: options, success: success, failure: failure)
    }

    public func applyThemeToSite(siteID: String, themeID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/themes/\(themeID)/apply"

        self.post(url, params: options, success: success, failure: failure)
    }

    public func uninstallTheme(_ themeID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/themes/\(themeID)"

        self.delete(url, params: options, success: success, failure: failure)
    }

    public func exportSiteTheme(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/export_theme"

        self.post(url, params: options, success: success, failure: failure)
    }

    //MARK: - Role
    public func listRoles(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/roles"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func roleAction(_ action: HTTPMethod, roleID: String? = nil, role: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/roles"
        if action != .post {
            if let id = roleID {
                url += "/" + id
            }
        }

        self.action("role", action: action, url: url, object: role, options: options, success: success, failure: failure)
    }

    public func createRole(_ role: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.roleAction(.post, roleID: nil, role: role, options: options, success: success, failure: failure)
    }

    public func getRole(_ roleID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.roleAction(.get, roleID: roleID, role: nil, options: options, success: success, failure: failure)
    }

    public func updateRole(_ roleID: String, role: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.roleAction(.put, roleID: roleID, role: role, options: options, success: success, failure: failure)
    }

    public func deleteRole(_ roleID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.roleAction(.delete, roleID: roleID, role: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Permission
    public func listPermissions(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/permissions"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func listPermissionsForObject(_ objectName: String, objectID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        //objectName:users,sites,roles
        let url = APIURL() + "/\(objectName)/\(objectID)/permissions"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func listPermissionsForUser(_ userID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listPermissionsForObject("users", objectID: userID, options: options, success: success, failure: failure)
    }

    public func listPermissionsForSite(_ siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listPermissionsForObject("sites", objectID: siteID, options: options, success: success, failure: failure)
    }

    public func listPermissionsForRole(_ roleID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listPermissionsForObject("roles", objectID: roleID, options: options, success: success, failure: failure)
    }

    public func grantPermissionToSite(_ siteID: String, userID: String, roleID: String, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/permissions/grant"

        var params: Parameters = [:]
        params["user_id"] = userID
        params["role_id"] = roleID

        self.post(url, params: params as [String : AnyObject]?, success: success, failure: failure)
    }

    public func grantPermissionToUser(_ userID: String, siteID: String, roleID: String, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "//users/\(userID)/permissions/grant"

        var params: Parameters = [:]
        params["site_id"] = siteID
        params["role_id"] = roleID

        self.post(url, params: params as [String : AnyObject]?, success: success, failure: failure)
    }

    public func revokePermissionToSite(_ siteID: String, userID: String, roleID: String, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/permissions/revoke"

        var params: Parameters = [:]
        params["user_id"] = userID
        params["role_id"] = roleID

        self.post(url, params: params as [String : AnyObject]?, success: success, failure: failure)
    }

    public func revokePermissionToUser(_ userID: String, siteID: String, roleID: String, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/users/\(userID)/permissions/revoke"

        var params: Parameters = [:]
        params["site_id"] = siteID
        params["role_id"] = roleID

        self.post(url, params: params, success: success, failure: failure)
    }

    //MARK: - Log
    public func listLogs(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func logAction(_ action: HTTPMethod, siteID: String, logID: String? = nil, log: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/logs"
        if action != .post {
            if let id = logID {
                url += "/" + id
            }
        }

        self.action("log", action: action, url: url, object: log, options: options, success: success, failure: failure)
    }

    public func createLog(siteID: String, log: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.logAction(.post, siteID: siteID, logID: nil, log: log, options: options, success: success, failure: failure)
    }

    public func getLog(siteID: String, logID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.logAction(.get, siteID: siteID, logID: logID, log: nil, options: options, success: success, failure: failure)
    }

    public func updateLog(siteID: String, logID: String, log: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.logAction(.put, siteID: siteID, logID: logID, log: log, options: options, success: success, failure: failure)
    }

    public func deleteLog(siteID: String, logID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.logAction(.delete, siteID: siteID, logID: logID, log: nil, options: options, success: success, failure: failure)
    }

    public func resetLogs(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs"

        self.delete(url, params: options, success: success, failure: failure)
    }

    public func exportLogs(siteID: String, options: Parameters? = nil, success: ((String?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/logs/export"

        let request = makeRequest(.get, url: url, parameters: options)
        request.responseData{(response) -> Void in
            switch response.result {
            case .success(let data):
                //FIXME:ShiftJIS以外の場合もある？
                let result: String = NSString(data: data, encoding: String.Encoding.shiftJIS.rawValue)! as String
                if (result.hasPrefix("{\"error\":")) {
                    let json = JSON(data:data)
                    failure(json["error"])
                    return
                }
                success(result)
            case .failure(_):
                failure(self.errorJSON())
            }
        }
    }

    //MARK: - FormattedText
    public func listFormattedTexts(siteID: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/formatted_texts"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    fileprivate func formattedTextAction(_ action: HTTPMethod, siteID: String, formattedTextID: String? = nil, formattedText: Parameters? = nil, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/sites/\(siteID)/formatted_texts"
        if action != .post {
            if let id = formattedTextID {
                url += "/" + id
            }
        }

        self.action("formatted_text", action: action, url: url, object: formattedText, options: options, success: success, failure: failure)
    }

    public func createFormattedText(siteID: String, formattedText: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.formattedTextAction(.post, siteID: siteID, formattedTextID: nil, formattedText: formattedText, options: options, success: success, failure: failure)
    }

    public func getFormattedText(siteID: String, formattedTextID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.formattedTextAction(.get, siteID: siteID, formattedTextID: formattedTextID, formattedText: nil, options: options, success: success, failure: failure)
    }

    public func updateFormattedText(siteID: String, formattedTextID: String, formattedText: Parameters, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.formattedTextAction(.put, siteID: siteID, formattedTextID: formattedTextID, formattedText: formattedText, options: options, success: success, failure: failure)
    }

    public func deleteFormattedText(siteID: String, formattedTextID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.formattedTextAction(.delete, siteID: siteID, formattedTextID: formattedTextID, formattedText: nil, options: options, success: success, failure: failure)
    }

    //MARK: - Stats
    public func getStatsProvider(siteID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/stats/provider"

        self.get(url, params: options, success: success, failure: failure)
    }

    fileprivate func listStatsForTarget(siteID: String, targetName: String, objectName: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/sites/\(siteID)/stats/\(targetName)/\(objectName)"

        var params: Parameters = [:]
        if let options = options {
            params = options
        }
        params["startDate"] = startDate as AnyObject?
        params["endDate"] = endDate as AnyObject?

        self.fetchList(url, params: params, success: success, failure: failure)
    }

    fileprivate func listStatsForPath(siteID: String, objectName: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        //objectName:pageviews, visits
        self.listStatsForTarget(siteID: siteID, targetName: "path", objectName: objectName, startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    public func pageviewsForPath(siteID: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listStatsForPath(siteID: siteID, objectName: "pageviews", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    public func visitsForPath(siteID: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listStatsForPath(siteID: siteID, objectName: "visits", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    fileprivate func listStatsForDate(siteID: String, objectName: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        //objectName:pageviews, visits
        self.listStatsForTarget(siteID: siteID, targetName: "date", objectName: objectName, startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    public func pageviewsForDate(siteID: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listStatsForDate(siteID: siteID, objectName: "pageviews", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    public func visitsForDate(siteID: String, startDate: String, endDate: String, options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {

        self.listStatsForDate(siteID: siteID, objectName: "visits", startDate: startDate, endDate: endDate, options: options, success: success, failure: failure)
    }

    //MARK: - Plugin
    public func listPlugins(_ options: Parameters? = nil, success: ((_ items:[JSON]?, _ total:Int?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/plugins"

        self.fetchList(url, params: options, success: success, failure: failure)
    }

    public func getPlugin(_ pluginID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIURL() + "/plugins/\(pluginID)"

        self.get(url, params: options, success: success, failure: failure)
    }

    fileprivate func togglePlugin(_ pluginID: String, enable: Bool, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        var url = APIURL() + "/plugins"

        if pluginID != "*" {
            url += "/" + pluginID
        }

        if enable {
            url += "/enable"
        } else {
            url += "/disable"
        }

        self.post(url, params: options, success: success, failure: failure)
    }

    public func enablePlugin(_ pluginID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.togglePlugin(pluginID, enable: true, options: options, success: success, failure: failure)
    }

    public func disablePlugin(_ pluginID: String, options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.togglePlugin(pluginID, enable: false, options: options, success: success, failure: failure)
    }

    public func enableAllPlugin(_ options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.togglePlugin("*", enable: true, options: options, success: success, failure: failure)
    }

    public func disableAllPlugin(_ options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        self.togglePlugin("*", enable: false, options: options, success: success, failure: failure)
    }

    //MARK: - # V3
    //MARK: - Version
    public func version(_ options: Parameters? = nil, success: ((JSON?) -> Void)!, failure: ((JSON?) -> Void)!)->Void {
        let url = APIBaseURL + "/version"
        
        self.get(url,
            success: {(result: JSON?)-> Void in
                if let result = result {
                    self.endpointVersion = result["endpointVersion"].stringValue
                    self.apiVersion = result["apiVersion"].stringValue
                }

                success(result)
            },
            failure: failure
        )
    }

}
