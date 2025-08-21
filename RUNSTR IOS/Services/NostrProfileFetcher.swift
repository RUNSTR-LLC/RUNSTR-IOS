import Foundation

/// Direct Nostr profile fetcher using WebSocket
/// This bypasses NostrSDK limitations to fetch real profile data
@MainActor
class NostrProfileFetcher: NSObject {
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var profileCompletion: ((NostrProfile?) -> Void)?
    private var subscriptionId: String = ""
    
    override init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    /// Fetch profile from Nostr relay
    func fetchProfile(pubkeyHex: String) async -> NostrProfile? {
        // Try multiple relays for better reliability
        let relayUrls = [
            "wss://relay.damus.io",
            "wss://nos.lol",
            "wss://relay.primal.net"
        ]
        
        for relayUrl in relayUrls {
            if let profile = await fetchFromRelay(relayUrl: relayUrl, pubkeyHex: pubkeyHex) {
                return profile
            }
        }
        
        return nil
    }
    
    private func fetchFromRelay(relayUrl: String, pubkeyHex: String) async -> NostrProfile? {
        guard let url = URL(string: relayUrl) else { return nil }
        
        return await withCheckedContinuation { continuation in
            self.profileCompletion = { profile in
                continuation.resume(returning: profile)
            }
            
            // Create WebSocket connection
            webSocketTask = session.webSocketTask(with: url)
            webSocketTask?.resume()
            
            // Generate subscription ID
            subscriptionId = UUID().uuidString.prefix(8).lowercased()
            
            // Create subscription request for profile (kind 0) events
            let subscriptionRequest: [Any] = [
                "REQ",
                subscriptionId,
                [
                    "kinds": [0],
                    "authors": [pubkeyHex],
                    "limit": 1
                ]
            ]
            
            // Send subscription
            if let jsonData = try? JSONSerialization.data(withJSONObject: subscriptionRequest),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
                let message = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask?.send(message) { error in
                    Task { @MainActor in
                        if let error = error {
                            print("❌ Failed to send subscription: \(error)")
                            self.profileCompletion?(nil)
                        } else {
                            print("✅ Sent profile subscription to \(relayUrl)")
                            self.receiveMessage()
                        }
                    }
                }
            }
            
            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.profileCompletion != nil {
                    print("⏰ Profile fetch timeout for \(relayUrl)")
                    self.closeConnection()
                    self.profileCompletion?(nil)
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                Task { @MainActor in
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    
                    // Continue receiving if we haven't found the profile yet
                    if self.profileCompletion != nil {
                        self.receiveMessage()
                    }
                }
                
            case .failure(let error):
                Task { @MainActor in
                    print("❌ WebSocket receive error: \(error)")
                    self.profileCompletion?(nil)
                }
            }
        }
    }
    
    private func handleMessage(_ message: String) {
        // Parse Nostr message format: ["EVENT", subscription_id, event_object]
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 3,
              let messageType = json[0] as? String else {
            return
        }
        
        if messageType == "EVENT" {
            if let eventDict = json[2] as? [String: Any],
               let profile = parseProfileEvent(eventDict) {
                print("✅ Received profile event")
                self.closeConnection()
                self.profileCompletion?(profile)
                self.profileCompletion = nil
            }
        } else if messageType == "EOSE" {
            // End of stored events - no profile found
            print("📭 No profile found (EOSE)")
            self.closeConnection()
            self.profileCompletion?(nil)
            self.profileCompletion = nil
        }
    }
    
    private func parseProfileEvent(_ event: [String: Any]) -> NostrProfile? {
        // Verify this is a kind 0 (profile metadata) event
        guard let kind = event["kind"] as? Int, kind == 0,
              let content = event["content"] as? String else {
            return nil
        }
        
        // Parse the profile JSON content
        guard let contentData = content.data(using: .utf8),
              let profileDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            return nil
        }
        
        // Extract profile fields
        let displayName = profileDict["name"] as? String ?? 
                         profileDict["display_name"] as? String
        let about = profileDict["about"] as? String
        let picture = profileDict["picture"] as? String
        let banner = profileDict["banner"] as? String
        let nip05 = profileDict["nip05"] as? String
        
        return NostrProfile(
            displayName: displayName,
            about: about,
            picture: picture,
            banner: banner,
            nip05: nip05
        )
    }
    
    private func closeConnection() {
        // Send CLOSE message
        let closeMessage: [Any] = ["CLOSE", subscriptionId]
        if let jsonData = try? JSONSerialization.data(withJSONObject: closeMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(message) { _ in }
        }
        
        // Close WebSocket
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
}

// MARK: - URLSessionWebSocketDelegate
extension NostrProfileFetcher: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connected")
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("📱 WebSocket closed")
    }
}