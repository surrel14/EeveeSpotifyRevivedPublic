import Orion
import Foundation

private func showHavePremiumPopUp() {
PopUpHelper.showPopUp(
delayed: true,
message: “have_premium_popup”.localized,
buttonText: “OK”.uiKitLocalized
)
}

class SpotifySessionDelegateBootstrapHook: ClassHook<NSObject>, SpotifySessionDelegate {
static var targetName: String {
switch EeveeSpotify.hookTarget {
case .lastAvailableiOS14: return “SPTCoreURLSessionDataDelegate”
default: return “SPTDataLoaderService”
}
}

```
func URLSession(
    _ session: URLSession,
    dataTask task: URLSessionDataTask,
    didReceiveResponse response: HTTPURLResponse,
    completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void
) {
    orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
}

func URLSession(
    _ session: URLSession,
    dataTask task: URLSessionDataTask,
    didReceiveData data: Data
) {
    guard 
        let request = task.currentRequest,
        let url = request.url
    else {
        return
    }
    
    if url.isBootstrap {
        URLSessionHelper.shared.setOrAppend(data, for: url)
        return
    }

    orig.URLSession(session, dataTask: task, didReceiveData: data)
}

func URLSession(
    _ session: URLSession,
    task: URLSessionDataTask,
    didCompleteWithError error: Error?
) {
    guard
        let request = task.currentRequest,
        let url = request.url
    else {
        return
    }
    
    if error == nil && url.isBootstrap {
        guard let buffer = URLSessionHelper.shared.obtainData(for: url) else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }
        
        do {
            var bootstrapMessage = try BootstrapMessage(serializedBytes: buffer)
            
            if UserDefaults.patchType == .notSet {
                if bootstrapMessage.attributes["type"]?.stringValue == "premium" {
                    UserDefaults.patchType = .disabled
                    showHavePremiumPopUp()
                }
                else {
                    UserDefaults.patchType = .requests
                    // FIX: For v91, BasePremiumPatchingGroup is already activated at init
                    // (to cover the window before the first bootstrap response arrives).
                    // Calling activatePremiumPatchingGroup() again here would double-activate
                    // it and also try to activate NonIOS14PremiumPatchingGroup which is not
                    // needed for v91 at this stage. Only do the full activation for non-v91.
                    if EeveeSpotify.hookTarget != .v91 {
                        DispatchQueue.main.async { activatePremiumPatchingGroup() }
                    }
                }
            }
            
            if UserDefaults.patchType == .requests {
                modifyRemoteConfiguration(&bootstrapMessage.ucsResponse)
                
                orig.URLSession(
                    session,
                    dataTask: task,
                    didReceiveData: try bootstrapMessage.serializedBytes()
                )
            }
            else {
                orig.URLSession(session, dataTask: task, didReceiveData: buffer)
            }
            
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }
        catch {
        }
    }
    
    orig.URLSession(session, task: task, didCompleteWithError: error)
}
```

}
