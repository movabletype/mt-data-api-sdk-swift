# Movable Type Data API SDK for Swift

## Requirements

- iOS 8.0+
- Xcode 6.1

## Usage

```swift
let api = DataAPI.sharedInstance
api.APIBaseURL = "http://host/mt/mt-data-api.cgi"
api.authentication("username", password: "password", remember: true,
    success:{_ in
        api.listSites(options: nil,
            success: {(result: [JSON]!, total: Int!)-> Void in
                let items = result
            },
            failure: {(error: JSON!)-> Void in
            }
        )
    },
    failure: {(error: JSON!)-> Void in
    }
)
```
