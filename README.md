# Movable Type Data API SDK for Swift

## Requirements

- iOS 8.0+
- Xcode 8.0+

## Installation

```ruby
pod "MTDataAPI-SDK"
```

## Usage

### list blogs
```swift
import MTDataAPI_SDK

let api = DataAPI.sharedInstance
api.APIBaseURL = "http://host/mt/mt-data-api.cgi"
api.authentication("username", password: "password", remember: true,
    success:{_ in
        api.listSites(
            success: { (result: [JSON]?, total: Int?) -> Void in
                if let items = result {
                    print(items)
                }
            },
            failure: { (error: JSON?) -> Void in
            })
    },
    failure: { (error: JSON?) -> Void in
    }
)

```

### create entry
```swift
import MTDataAPI_SDK

var entry: [String:String] = [:]
entry["title"] = "title"
entry["body"] = "text"
entry["status"] = "Publish"

let api = DataAPI.sharedInstance
api.APIBaseURL = "http://host/mt/mt-data-api.cgi"
api.authentication("username", password: "password", remember: true,
    success:{_ in
        api.createEntry(siteID: "1", entry: entry,
            success: {(result: JSON?)-> Void in
                print(result)
            },
            failure: {(error: JSON?)-> Void in
            }
        )
    },
    failure: {(error: JSON?)-> Void in
    }
)
```

### upload asset
```swift
import MTDataAPI_SDK

let api = DataAPI.sharedInstance
api.APIBaseURL = "http://host/mt/mt-data-api.cgi"
api.authentication("username", password: "password", remember: true,
    success: {_ in
        let image = UIImage(named:"photo")
        let data = UIImageJPEGRepresentation(image, 1.0)
        api.uploadAssetForSite(siteID: siteID, assetData: data, fileName: "photo.jpeg", options: ["path":"/images", "autoRenameIfExists":"true"],
            success: {(result: JSON?)-> Void  in
                print(result)
            },
            failure: {(error: JSON?)-> Void in
            }
        )
    },
    failure: {(error: JSON?)-> Void in
    }
)
```
