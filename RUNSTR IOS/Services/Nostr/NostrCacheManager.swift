import Foundation

/// Manages local caching of Nostr profile data
@MainActor
class NostrCacheManager: ObservableObject, NostrCacheManagerProtocol {
    
    // MARK: - Private Properties
    private var profileCache: [String: CachedProfile] = [:]
    private let cacheExpirationHours: TimeInterval = 4 * 60 * 60 // 4 hours
    private var profileUpdateTimer: Timer?
    
    // Cache keys for UserDefaults
    private let cacheKeyPrefix = "cached_profile_"
    
    // MARK: - Initialization
    init() {
        print("💾 NostrCacheManager initialized")
        loadCacheFromPersistentStorage()
    }
    
    deinit {
        // Note: Cannot call @MainActor methods from deinit
        // Background updates will be stopped when timer is deinitialized
        profileUpdateTimer?.invalidate()
        profileUpdateTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Cache profile data locally
    func cacheProfile(pubkey: String, profile: NostrProfile) async {
        let cachedProfile = CachedProfile(profile: profile, timestamp: Date())
        
        profileCache[pubkey] = cachedProfile
        
        // Also save to persistent storage
        saveToPersistentStorage(pubkey: pubkey, cachedProfile: cachedProfile)
        
        print("💾 Cached profile for \(pubkey.prefix(16))...")
    }
    
    /// Get cached profile if not expired
    func getCachedProfile(pubkey: String) -> NostrProfile? {
        // Check in-memory cache first
        if let cached = profileCache[pubkey] {
            if !isCacheExpired(cached.timestamp) {
                print("✅ Using fresh in-memory cached profile for \(pubkey.prefix(16))...")
                return cached.profile
            } else {
                // Remove expired cache
                profileCache.removeValue(forKey: pubkey)
                print("🗑️ Removed expired in-memory cache for \(pubkey.prefix(16))...")
            }
        }
        
        // Check persistent storage
        return loadFromPersistentStorage(pubkey: pubkey)
    }
    
    /// Clear all cached profile data
    func clearAllCache() async {
        // Clear in-memory cache
        profileCache.removeAll()
        
        // Clear persistent cache from UserDefaults
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(cacheKeyPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        print("🗑️ Cleared all profile cache data")
    }
    
    /// Clear cache for specific pubkey
    func clearCache(for pubkey: String) async {
        // Clear from in-memory cache
        profileCache.removeValue(forKey: pubkey)
        
        // Clear from persistent storage
        UserDefaults.standard.removeObject(forKey: "\(cacheKeyPrefix)\(pubkey)")
        
        print("🗑️ Cleared profile cache for \(pubkey.prefix(16))...")
    }
    
    /// Start periodic background profile updates
    func startBackgroundUpdates(profileService: NostrProfileServiceProtocol) async {
        await stopBackgroundUpdates() // Stop any existing timer
        
        // Update every 4 hours
        profileUpdateTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCachedProfiles(using: profileService)
            }
        }
        
        print("🔄 Started background profile updates (every 4 hours)")
    }
    
    /// Stop background profile updates
    func stopBackgroundUpdates() async {
        profileUpdateTimer?.invalidate()
        profileUpdateTimer = nil
        print("⏹️ Stopped background profile updates")
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> (total: Int, fresh: Int, stale: Int) {
        let currentTime = Date()
        let updateThreshold: TimeInterval = 3 * 60 * 60 // 3 hours
        
        var fresh = 0
        var stale = 0
        
        for cached in profileCache.values {
            let age = currentTime.timeIntervalSince(cached.timestamp)
            if age < updateThreshold {
                fresh += 1
            } else {
                stale += 1
            }
        }
        
        return (total: profileCache.count, fresh: fresh, stale: stale)
    }
    
    /// Force refresh of specific profile
    func forceRefreshProfile(pubkey: String, using profileService: NostrProfileServiceProtocol) async -> Bool {
        print("🔄 Force refreshing profile for \(pubkey.prefix(16))...")
        
        // Clear existing cache
        await clearCache(for: pubkey)
        
        // Fetch fresh profile
        if let freshProfile = await profileService.fetchProfile(pubkey: pubkey) {
            await cacheProfile(pubkey: pubkey, profile: freshProfile)
            print("✅ Successfully force refreshed profile")
            return true
        } else {
            print("❌ Failed to force refresh profile")
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if cache entry has expired
    private func isCacheExpired(_ timestamp: Date) -> Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age >= cacheExpirationHours
    }
    
    /// Save cached profile to UserDefaults
    private func saveToPersistentStorage(pubkey: String, cachedProfile: CachedProfile) {
        if let encoded = try? JSONEncoder().encode(cachedProfile) {
            UserDefaults.standard.set(encoded, forKey: "\(cacheKeyPrefix)\(pubkey)")
            print("💾 Saved profile to persistent storage for \(pubkey.prefix(16))...")
        } else {
            print("❌ Failed to encode cached profile for storage")
        }
    }
    
    /// Load cached profile from UserDefaults
    private func loadFromPersistentStorage(pubkey: String) -> NostrProfile? {
        let key = "\(cacheKeyPrefix)\(pubkey)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedProfile.self, from: data) else {
            print("🔍 No cached profile found in persistent storage for \(pubkey.prefix(16))...")
            return nil
        }
        
        let age = Date().timeIntervalSince(cached.timestamp)
        let ageHours = age / 3600
        
        // Check if still valid (within expiration time)
        if !isCacheExpired(cached.timestamp) {
            // Update in-memory cache
            profileCache[pubkey] = cached
            print("✅ Loaded valid cached profile (age: \(String(format: "%.1f", ageHours))h) for \(pubkey.prefix(16))...")
            return cached.profile
        } else {
            // Remove expired cache
            UserDefaults.standard.removeObject(forKey: key)
            print("🗑️ Removed expired persistent cache (age: \(String(format: "%.1f", ageHours))h) for \(pubkey.prefix(16))...")
            return nil
        }
    }
    
    /// Load all cached profiles from persistent storage on initialization
    private func loadCacheFromPersistentStorage() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        
        var loadedCount = 0
        var expiredCount = 0
        
        for key in keys {
            if key.hasPrefix(cacheKeyPrefix) {
                let pubkey = String(key.dropFirst(cacheKeyPrefix.count))
                
                guard let data = userDefaults.data(forKey: key),
                      let cached = try? JSONDecoder().decode(CachedProfile.self, from: data) else {
                    continue
                }
                
                if !isCacheExpired(cached.timestamp) {
                    profileCache[pubkey] = cached
                    loadedCount += 1
                } else {
                    // Remove expired cache
                    userDefaults.removeObject(forKey: key)
                    expiredCount += 1
                }
            }
        }
        
        if loadedCount > 0 {
            print("✅ Loaded \(loadedCount) cached profiles from persistent storage")
        }
        
        if expiredCount > 0 {
            print("🗑️ Cleaned up \(expiredCount) expired cached profiles")
        }
    }
    
    /// Update all cached profiles that are approaching expiration
    private func updateCachedProfiles(using profileService: NostrProfileServiceProtocol) async {
        let currentTime = Date()
        let updateThreshold: TimeInterval = 3 * 60 * 60 // Update if older than 3 hours
        
        let profileCount = profileCache.count
        print("🔄 Checking \(profileCount) cached profiles for updates...")
        
        var updatedCount = 0
        for (pubkey, cached) in profileCache {
            let age = currentTime.timeIntervalSince(cached.timestamp)
            if age > updateThreshold {
                let ageHours = age / 3600
                print("🔄 Updating stale profile (age: \(String(format: "%.1f", ageHours))h) for \(pubkey.prefix(16))...")
                
                if let freshProfile = await profileService.fetchProfile(pubkey: pubkey) {
                    await cacheProfile(pubkey: pubkey, profile: freshProfile)
                    updatedCount += 1
                }
            }
        }
        
        if updatedCount > 0 {
            print("✅ Background update complete: refreshed \(updatedCount) profiles")
        } else {
            print("ℹ️ Background update complete: all profiles are fresh")
        }
    }
    
    /// Clean up expired cache entries
    func cleanupExpiredCache() {
        var expiredKeys: [String] = []
        
        // Find expired in-memory cache
        for (pubkey, cached) in profileCache {
            if isCacheExpired(cached.timestamp) {
                expiredKeys.append(pubkey)
            }
        }
        
        // Remove expired in-memory cache
        for key in expiredKeys {
            profileCache.removeValue(forKey: key)
        }
        
        // Clean up persistent storage
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        var cleanedCount = 0
        
        for key in keys {
            if key.hasPrefix(cacheKeyPrefix) {
                if let data = userDefaults.data(forKey: key),
                   let cached = try? JSONDecoder().decode(CachedProfile.self, from: data),
                   isCacheExpired(cached.timestamp) {
                    userDefaults.removeObject(forKey: key)
                    cleanedCount += 1
                }
            }
        }
        
        if !expiredKeys.isEmpty || cleanedCount > 0 {
            print("🧹 Cleaned up \(expiredKeys.count) in-memory and \(cleanedCount) persistent expired cache entries")
        }
    }
}