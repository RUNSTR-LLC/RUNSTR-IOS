import Foundation
import StoreKit

// MARK: - Subscription Tiers
enum SubscriptionTier: String, Codable, CaseIterable {
    case none = "none"
    case member = "member"
    case captain = "captain"
    case organization = "organization"
    
    var displayName: String {
        switch self {
        case .none: return "Free"
        case .member: return "Member"
        case .captain: return "Captain"
        case .organization: return "Organization"
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .none: return 0.0
        case .member: return 3.99
        case .captain: return 19.99
        case .organization: return 49.99
        }
    }
    
    var bitcoinDiscountPrice: Double {
        return monthlyPrice * 0.9 // 10% discount for Bitcoin payments
    }
    
    var features: [String] {
        switch self {
        case .none:
            return [
                "Basic workout tracking",
                "Limited rewards (1-2 sats)",
                "View public events"
            ]
        case .member:
            return [
                "Full workout tracking",
                "Standard rewards (5-10 sats)",
                "Join teams",
                "Participate in events",
                "Team chat access"
            ]
        case .captain:
            return [
                "All Member features",
                "Create and manage teams",
                "Create team events",
                "Earn rewards per team member",
                "Advanced team analytics",
                "Priority support"
            ]
        case .organization:
            return [
                "All Captain features",
                "Create public challenges",
                "Organization branding",
                "Member reward pools",
                "Advanced analytics dashboard",
                "API access",
                "Dedicated support"
            ]
        }
    }
    
    var productID: String {
        switch self {
        case .none: return ""
        case .member: return "com.runstr.ios.member.monthly"
        case .captain: return "com.runstr.ios.captain.monthly"
        case .organization: return "com.runstr.ios.organization.monthly"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .none: return "person"
        case .member: return "person.circle"
        case .captain: return "person.badge.shield.checkmark"
        case .organization: return "building.2"
        }
    }
    
    var accentColor: String {
        switch self {
        case .none: return "gray"
        case .member: return "blue"
        case .captain: return "orange"
        case .organization: return "purple"
        }
    }
}

// MARK: - Subscription Status
struct SubscriptionStatus: Codable {
    let tier: SubscriptionTier
    let isActive: Bool
    let expirationDate: Date?
    let autoRenew: Bool
    let paymentMethod: PaymentMethod
    let purchaseDate: Date
}

extension SubscriptionStatus {
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return Date() > expiration
    }
    
    var daysUntilExpiration: Int? {
        guard let expiration = expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day
        return max(0, days ?? 0)
    }
}

enum PaymentMethod: String, Codable {
    case applePay = "apple_pay"
    case bitcoin = "bitcoin"
    case lightning = "lightning"
    
    var displayName: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .bitcoin: return "Bitcoin"
        case .lightning: return "Lightning"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .applePay: return "apple.logo"
        case .bitcoin: return "bitcoinsign.circle"
        case .lightning: return "bolt.circle"
        }
    }
}

// MARK: - Team Selection for Member Subscription
struct TeamSelection: Codable {
    let teamID: String
    let teamName: String
    let captainName: String
    let memberCount: Int
    let activityLevel: ActivityLevel
    
    enum ActivityLevel: String, Codable {
        case casual = "casual"
        case active = "active"
        case competitive = "competitive"
        
        var displayName: String {
            switch self {
            case .casual: return "Casual"
            case .active: return "Active" 
            case .competitive: return "Competitive"
            }
        }
    }
}

// MARK: - Organization Settings
struct OrganizationSettings: Codable {
    var organizationName: String = ""
    var branding: OrganizationBranding = OrganizationBranding()
    var rewardPool: OrganizationRewardPool = OrganizationRewardPool()
    var memberPerks: [String] = []
    
    struct OrganizationBranding: Codable {
        var logoURL: String? = nil
        var primaryColor: String = "#FF6B35" // Default orange
        var website: String? = nil
        var description: String = ""
    }
    
    struct OrganizationRewardPool: Codable {
        var totalSats: Int = 0
        var monthlyContribution: Int = 0 // From subscription fee
        var memberRewardRate: Int = 5 // Sats per member per month
        var eventBudget: Int = 0
        
        var estimatedMonthlyPayout: Int {
            return monthlyContribution + (memberRewardRate * 100) // Estimate for 100 members
        }
    }
}

// MARK: - Subscription Benefits Calculator
struct SubscriptionBenefits {
    static func calculateCaptainEarnings(memberCount: Int, tier: SubscriptionTier) -> Int {
        guard tier == .captain else { return 0 }
        return memberCount * 10 // 10 sats per member per month
    }
    
    static func calculateOrganizationRewards(memberCount: Int, subscriptionFee: Double) -> Int {
        let feeInSats = Int(subscriptionFee * 4000) // Rough conversion: $1 = 4000 sats
        let rewardPoolContribution = feeInSats / 4 // 25% of fee goes to rewards
        return rewardPoolContribution
    }
    
    static func getRewardMultiplier(for tier: SubscriptionTier) -> Double {
        switch tier {
        case .none: return 0.2
        case .member: return 1.0
        case .captain: return 1.5
        case .organization: return 2.0
        }
    }
}