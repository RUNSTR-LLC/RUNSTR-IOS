# App Store Connect Subscription Setup Guide

## Overview

This document provides comprehensive instructions for configuring RUNSTR subscription products in App Store Connect for production deployment. Follow these steps carefully to ensure proper subscription functionality.

## Prerequisites

- Apple Developer Account (enrolled and active)
- RUNSTR iOS app registered in App Store Connect
- Proper signing certificates and provisioning profiles
- Tax and banking information completed in App Store Connect

## Subscription Products Configuration

### 1. Create Subscription Group

1. Navigate to **App Store Connect > My Apps > RUNSTR IOS > Subscriptions**
2. Click **"+"** to create a new subscription group
3. Configure the group:
   - **Reference Name**: `RUNSTR Subscriptions`
   - **App Store Display Name**: `RUNSTR Fitness Subscriptions`
   - **Group ID**: Will be auto-generated (use in iOS code)

### 2. Configure Subscription Products

Create three subscription products with the following configurations:

#### Member Subscription ($3.99/month)

**Basic Information:**
- **Product ID**: `com.runstr.ios.member.monthly`
- **Reference Name**: `Member Monthly`
- **Duration**: 1 Month (Auto-renewable)

**Subscription Prices:**
- **Base Territory (USA)**: $3.99/month
- **Configure for all territories**: Yes (use price equivalents)

**App Store Information:**
- **Display Name**: `Member Subscription`
- **Description**: 
  ```
  Join teams, participate in events, and earn Bitcoin rewards for your workouts.
  
  • Full workout tracking and history
  • Join unlimited teams
  • Participate in events and competitions
  • Team chat access
  • Standard Bitcoin rewards (21-100 sats)
  • Export workout data
  • Lightning wallet access
  ```

**Introductory Offer:**
- **Type**: Free Trial
- **Duration**: 1 Week
- **Territories**: All
- **Eligibility**: New Subscribers Only

#### Captain Subscription ($19.99/month)

**Basic Information:**
- **Product ID**: `com.runstr.ios.captain.monthly`
- **Reference Name**: `Captain Monthly`
- **Duration**: 1 Month (Auto-renewable)

**Subscription Prices:**
- **Base Territory (USA)**: $19.99/month
- **Configure for all territories**: Yes

**App Store Information:**
- **Display Name**: `Captain Subscription`
- **Description**: 
  ```
  Create and manage teams while earning $1 per team member monthly.
  
  • All Member features included
  • Create and manage teams (up to 500 members)
  • Create team events and challenges
  • Earn $1 per team member monthly
  • Advanced team analytics dashboard
  • Custom team branding
  • Priority support
  ```

**Introductory Offer:**
- **Type**: Pay as You Go
- **Duration**: 1 Month
- **Discounted Price**: $9.99
- **Territories**: All
- **Eligibility**: New and Returning Subscribers

#### Organization Subscription ($49.99/month)

**Basic Information:**
- **Product ID**: `com.runstr.ios.organization.monthly`
- **Reference Name**: `Organization Monthly`
- **Duration**: 1 Month (Auto-renewable)

**Subscription Prices:**
- **Base Territory (USA)**: $49.99/month
- **Configure for all territories**: Yes

**App Store Information:**
- **Display Name**: `Organization Subscription`
- **Description**: 
  ```
  Full platform access for fitness organizations and businesses.
  
  • All Captain features included
  • Create public virtual events
  • Sell event tickets (keep 100% revenue)
  • Advanced analytics and reporting
  • API access for integrations
  • Multiple team management
  • Dedicated account manager
  • Corporate wellness programs
  ```

**No Introductory Offer** (Premium tier)

### 3. Subscription Group Settings

**Family Sharing:** Disabled (subscriptions are individual)

**Subscription Offers:** Configure promotional offers as needed for marketing campaigns

**Subscription Group Display Order:**
1. Member ($3.99)
2. Captain ($19.99) 
3. Organization ($49.99)

## App Store Review Preparation

### 1. App Metadata Updates

**App Description Updates:**
Add subscription information to your app description:

```
SUBSCRIPTION TIERS:

💪 Member ($3.99/month):
• Join fitness teams and earn Bitcoin rewards
• Participate in virtual events and competitions
• Full workout tracking and analytics

🏅 Captain ($19.99/month):
• Create and manage fitness teams
• Earn $1 per team member monthly
• Advanced team analytics

🏢 Organization ($49.99/month):
• Create public virtual events
• Sell event tickets with 100% revenue
• Enterprise features and API access

All subscriptions auto-renew unless cancelled. Manage subscriptions in App Store account settings.
```

**Keywords:** Add subscription-related keywords:
- `fitness subscription`
- `team workouts`
- `bitcoin rewards`
- `virtual events`

### 2. App Review Information

**Subscription Test Account:**
- Create a Sandbox test account in App Store Connect
- Provide login credentials in App Review Information
- Include instructions for testing subscription flows

**Review Notes:**
```
RUNSTR is a fitness subscription platform where users can:

1. Subscribe to join fitness teams and earn Bitcoin rewards
2. Create teams as Captains and earn revenue from members
3. Create virtual events as Organizations

TESTING SUBSCRIPTIONS:
- Use provided sandbox account
- Test subscription purchase, restore, and cancellation flows
- Bitcoin features are educational/gamification (small amounts)
- All payment processing handled by Apple's StoreKit

BITCOIN COMPLIANCE:
- Bitcoin rewards are small amounts for engagement (21-100 satoshis)
- No Bitcoin trading, exchange, or large financial transactions
- Focus is on fitness motivation, not cryptocurrency
```

### 3. Privacy and Legal

**Privacy Policy Updates:**
Ensure your privacy policy covers:
- Subscription billing and renewal
- Data collection for team features
- Bitcoin reward distribution
- Payment processing (handled by Apple)

**Terms of Service:**
Update terms to include:
- Subscription billing and cancellation policies
- Team membership rules and revenue sharing
- Event participation terms
- Bitcoin reward program terms

## Testing Configuration

### 1. Sandbox Testing

**Sandbox Test Accounts:**
1. Create multiple test accounts in App Store Connect
2. Test different regions and currencies
3. Verify subscription flows work correctly

**Test Scenarios:**
- ✅ Purchase each subscription tier
- ✅ Restore purchases after app reinstall
- ✅ Subscription expiration and renewal
- ✅ Family sharing (should be disabled)
- ✅ Introductory offers
- ✅ Subscription upgrades/downgrades
- ✅ Cancellation and grace period

### 2. StoreKit Testing

**Using Local .storekit File:**
- Test subscription flows in simulator
- Verify product loading and purchase flows
- Test edge cases and error handling

## Production Launch Checklist

### Pre-Launch
- [ ] All subscription products configured in App Store Connect
- [ ] Sandbox testing completed successfully
- [ ] App privacy policy updated
- [ ] Terms of service updated
- [ ] App Store screenshots include subscription features
- [ ] App Store description mentions subscriptions
- [ ] Banking and tax info completed

### App Review Submission
- [ ] Subscription test account provided
- [ ] Review notes explain Bitcoin features (fitness motivation, not trading)
- [ ] Subscription functionality clearly explained
- [ ] Demo video showing subscription flows (optional but recommended)

### Post-Approval
- [ ] Monitor subscription analytics in App Store Connect
- [ ] Set up App Store server notifications for subscription events
- [ ] Configure subscription analytics in your backend
- [ ] Plan subscription marketing campaigns
- [ ] Monitor customer reviews for subscription feedback

## Revenue and Analytics

### App Store Connect Metrics to Monitor

**Subscription Performance:**
- Conversion rates by tier
- Retention rates (monthly, annual)
- Churn analysis
- Trial-to-paid conversion

**Financial Metrics:**
- Monthly Recurring Revenue (MRR)
- Average Revenue Per User (ARPU)
- Customer Lifetime Value (LTV)
- Revenue by geography

### Key Performance Indicators (KPIs)

**Target Metrics (Month 3):**
- Member tier conversion: 20%+ from free users
- Captain tier retention: 80%+ at 3 months
- Organization tier: 50+ active organizations
- Average revenue per user: $15/month

## Compliance and Legal

### App Store Guidelines Compliance

**Guideline 3.1.1 - In-App Purchase:**
- All subscription features properly gate-kept
- Restore purchases functionality implemented
- Clear subscription terms in app

**Guideline 1.1.4 - Safety:**
- Bitcoin features clearly explained as fitness rewards
- No promotion of cryptocurrency investment
- Educational content about Bitcoin's use in fitness motivation

### International Compliance

**GDPR (EU users):**
- Clear consent for subscription billing
- Data portability for subscription data
- Right to deletion while maintaining billing records

**Regional Pricing:**
- Configure appropriate pricing for all territories
- Consider local purchasing power
- Use App Store's automatic price tiers

## Support and Troubleshooting

### Common Issues

**"Subscription not active" after purchase:**
- Check StoreKit transaction verification
- Verify product IDs match App Store Connect
- Test restore purchases functionality

**"Cannot connect to App Store":**
- Verify internet connectivity
- Check App Store Connect service status
- Test with different Apple IDs

### Customer Support Preparation

**FAQ Topics:**
- How to cancel subscriptions
- How to restore purchases
- Subscription billing questions
- Bitcoin rewards explanation
- Team management questions

**Support Escalation:**
- Technical issues: Development team
- Billing disputes: Apple Support
- Account issues: Customer success team

## Next Steps

1. **Complete App Store Connect setup** following this guide
2. **Submit for App Review** with proper documentation
3. **Plan launch marketing** around subscription value proposition
4. **Monitor metrics closely** in first weeks after launch
5. **Iterate based on user feedback** and conversion data

---

*This document should be updated as Apple's policies and App Store Connect interface evolve.*