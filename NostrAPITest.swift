#!/usr/bin/env swift
//
// WARNING: This file previously contained INCORRECT NostrSDK API patterns
// that caused the main project to fail. It has been updated with WORKING patterns.
//
// REFERENCE: See nostr-implementation-fixes-2025.md for all working API patterns
//
import Foundation
import NostrSDK

print("=== NostrSDK 0.3.0 API Discovery Tests (CORRECTED) ===\n")

// Test 1: Basic keypair generation and public key access
print("1. Testing Keypair generation and PublicKey methods:")
do {
    let keypair = Keypair()
    print("✓ Keypair created successfully")
    
    // Test npub/nsec access
    if let npub = keypair?.publicKey.npub {
        print("✓ PublicKey.npub: \(npub)")
    }
    if let nsec = keypair?.privateKey.nsec {
        print("✓ PrivateKey.nsec: \(nsec)")
    }
    if let hex = keypair?.publicKey.hex {
        print("✓ PublicKey.hex: \(hex)")
    }
} catch {
    print("✗ Keypair test failed: \(error)")
}

print()

// Test 2: Event creation patterns (CORRECTED - Using Builder Pattern)
print("2. Testing Event creation:")
do {
    if let keypair = Keypair() {
        // Create a text note event using Builder pattern (ACTUAL WORKING API)
        let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind.textNote)
            .content("Test event from NostrSDK test")
        
        let event = try builder.build(signedBy: keypair)
        print("✓ NostrEvent created and signed successfully using Builder pattern")
        print("  Event ID: \(event.id)")
        print("  Event kind: \(event.kind)")
    }
} catch {
    print("✗ Event creation test failed: \(error)")
}

print()

// Test 3: RelayPool functionality
print("3. Testing RelayPool:")
do {
    let relayPool = RelayPool()
    print("✓ RelayPool created successfully")
    
    // Test adding relay
    if let url = URL(string: "wss://relay.damus.io") {
        let relay = try Relay(url: url)
        relayPool.add(relay: relay)
        print("✓ Relay added successfully")
    }
    
    // Test subscription (CORRECTED - Handle optional Filter)
    guard let filter = Filter(kinds: [EventKind.textNote.rawValue], limit: 10) else {
        print("✗ Failed to create filter")
        return
    }
    let subscriptionId = relayPool.subscribe(with: filter)
    print("✓ Subscription created with ID: \(subscriptionId)")
    
} catch {
    print("✗ RelayPool test failed: \(error)")
}

print()

// Test 4: PublicKey/PrivateKey creation from strings
print("4. Testing Key creation from strings:")
do {
    // Test PublicKey from npub
    let testNpub = "npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s"
    if let pubkey = PublicKey(npub: testNpub) {
        print("✓ PublicKey(npub:) works")
        print("  hex: \(pubkey.hex)")
    }
    
    // Test PublicKey from hex
    let testHex = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"
    if let pubkey = PublicKey(hex: testHex) {
        print("✓ PublicKey(hex:) works") 
        print("  npub: \(pubkey.npub)")
    }
    
    // Test Keypair from nsec
    let testNsec = "nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5"
    if let keypair = Keypair(nsec: testNsec) {
        print("✓ Keypair(nsec:) works")
        print("  pubkey: \(keypair.publicKey.npub)")
    }
} catch {
    print("✗ Key creation test failed: \(error)")
}

print()

// Test 5: Legacy encrypted direct message
print("5. Testing Legacy Encrypted Direct Message (NIP-04):")
do {
    if let senderKeypair = Keypair(),
       let recipientKeypair = Keypair() {
        
        // Create EventCreating conforming struct
        struct TestEventCreator: EventCreating {}
        let creator = TestEventCreator()
        
        let message = try creator.legacyEncryptedDirectMessage(
            withContent: "Test encrypted message",
            toRecipient: recipientKeypair.publicKey,
            signedBy: senderKeypair
        )
        
        print("✓ Encrypted message created successfully")
        print("  Event kind: \(message.kind)")
        print("  Content length: \(message.content.count)")
        
        // Try to decrypt
        let decryptedContent = try message.decryptedContent(using: recipientKeypair.privateKey)
        print("✓ Message decrypted successfully: \(decryptedContent)")
    }
} catch {
    print("✗ Encrypted message test failed: \(error)")
}

print()

print("=== Test Complete ===")