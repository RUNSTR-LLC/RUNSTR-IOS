import Foundation
import NostrSDK

// Simple test to verify NostrSDK can be imported and basic objects created
func testNostrSDKImport() {
    print("🧪 Testing NostrSDK import...")
    
    // Test 1: Create a keypair
    if let keypair = Keypair() {
        print("✅ Keypair creation successful")
        print("   Public key (npub): \(keypair.publicKey.npub)")
    } else {
        print("❌ Keypair creation failed")
        return
    }
    
    // Test 2: Create relay URLs
    let relayUrls = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social"
    ]
    
    let relays = Set(relayUrls.compactMap { URL(string: $0) }.compactMap { 
        try? Relay(url: $0) 
    })
    
    if relays.count > 0 {
        print("✅ Relay creation successful (\(relays.count) relays)")
    } else {
        print("❌ Relay creation failed")
        return
    }
    
    // Test 3: Create RelayPool
    let relayPool = RelayPool(relays: relays)
    print("✅ RelayPool creation successful")
    
    print("🎉 NostrSDK integration test passed!")
}

testNostrSDKImport()
