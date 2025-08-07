import Foundation
import CloudKit
import Combine

class TeamService: ObservableObject {
    // MARK: - Published Properties
    @Published var teams: [Team] = []
    @Published var myTeams: [Team] = []
    @Published var teamMessages: [String: [TeamMessage]] = [:] // teamID -> messages
    @Published var teamStats: [String: TeamStatsCloudKit] = [:] // teamID -> stats
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Internal Properties (accessible to extensions)
    let container: CKContainer
    let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    private var subscriptions: [CKSubscription] = []
    init() {
        container = CKContainer(identifier: "iCloud.com.runstr.ios")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        
        Task {
            await setupCloudKitSubscriptions()
            await loadInitialData()
        }
    }
    
    // MARK: - Team CRUD Operations
    
    /// Create a new team
    func createTeam(name: String, description: String, captainID: String, activityLevel: ActivityLevel, maxMembers: Int = 500, teamType: String = "running_club", location: String? = nil, supportedActivityTypes: [ActivityType] = [.running, .walking]) async -> Result<Team, Error> {
        
        isLoading = true
        errorMessage = nil
        
        do {
            let team = Team(
                name: name,
                description: description,
                captainID: captainID,
                activityLevel: activityLevel,
                maxMembers: maxMembers,
                teamType: teamType,
                location: location,
                supportedActivityTypes: supportedActivityTypes
            )
            
            let record = team.toCKRecord(container: container)
            let savedRecord = try await publicDatabase.save(record)
            
            if let savedTeam = Team(record: savedRecord) {
                // Create initial team stats
                let initialStats = TeamStatsCloudKit(teamID: savedTeam.id)
                let statsRecord = initialStats.toCKRecord(container: container)
                try await publicDatabase.save(statsRecord)
                
                // Create captain as first team member
                let captainMember = TeamMember(
                    id: captainID,
                    joinedAt: Date(),
                    role: .captain,
                    stats: MemberStats()
                )
                let memberRecord = captainMember.toCKRecord(teamID: savedTeam.id, container: container)
                try await publicDatabase.save(memberRecord)
                
                await MainActor.run {
                    teams.append(savedTeam)
                    myTeams.append(savedTeam)
                    teamStats[savedTeam.id] = initialStats
                    isLoading = false
                }
                
                print("✅ Team created successfully: \(savedTeam.name)")
                return .success(savedTeam)
            } else {
                throw TeamServiceError.invalidTeamData
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create team: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to create team: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch all public teams
    func fetchPublicTeams() async -> Result<[Team], Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            let predicate = NSPredicate(format: "isPublic == 1")
            let query = CKQuery(recordType: Team.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let fetchedTeams = records.compactMap { Team(record: $0) }
            
            await MainActor.run {
                teams = fetchedTeams
                isLoading = false
            }
            
            print("✅ Fetched \(fetchedTeams.count) public teams")
            return .success(fetchedTeams)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch teams: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to fetch public teams: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch teams where user is a member
    func fetchMyTeams(userID: String) async -> Result<[Team], Error> {
        do {
            // First, get team memberships for this user
            let memberPredicate = NSPredicate(format: "memberID == %@", userID)
            let memberQuery = CKQuery(recordType: TeamMember.recordType, predicate: memberPredicate)
            
            let (memberResults, _) = try await publicDatabase.records(matching: memberQuery)
            let memberRecords = memberResults.compactMap { try? $0.1.get() }
            let teamIDs = memberRecords.compactMap { $0["teamID"] as? String }
            
            guard !teamIDs.isEmpty else {
                await MainActor.run { myTeams = [] }
                return .success([])
            }
            
            // Then, fetch the actual teams
            let teamRecordIDs = teamIDs.map { CKRecord.ID(recordName: $0) }
            let teamResults = try await publicDatabase.records(for: teamRecordIDs)
            let teamRecords = teamResults.compactMap { try? $0.1.get() }
            let userTeams = teamRecords.compactMap { Team(record: $0) }
            
            await MainActor.run {
                myTeams = userTeams
            }
            
            print("✅ Fetched \(userTeams.count) teams for user")
            return .success(userTeams)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch my teams: \(error.localizedDescription)"
            }
            print("❌ Failed to fetch my teams: \(error)")
            return .failure(error)
        }
    }
    
    /// Join a team
    func joinTeam(teamID: String, userID: String) async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, check if team exists and has space
            let teamRecordID = CKRecord.ID(recordName: teamID)
            let teamRecord = try await publicDatabase.record(for: teamRecordID)
            
            guard let team = Team(record: teamRecord) else {
                throw TeamServiceError.teamNotFound
            }
            
            guard team.memberIDs.count < team.maxMembers else {
                throw TeamServiceError.teamFull
            }
            
            guard !team.memberIDs.contains(userID) else {
                throw TeamServiceError.alreadyMember
            }
            
            // Create team member record
            let newMember = TeamMember(
                id: userID,
                joinedAt: Date(),
                role: .member,
                stats: MemberStats()
            )
            
            let memberRecord = newMember.toCKRecord(teamID: teamID, container: container)
            try await publicDatabase.save(memberRecord)
            
            // Update team's member list
            var updatedTeam = team
            updatedTeam.memberIDs.append(userID)
            let updatedTeamRecord = updatedTeam.toCKRecord(container: container)
            try await publicDatabase.save(updatedTeamRecord)
            
            await MainActor.run {
                // Update local teams array
                if let index = teams.firstIndex(where: { $0.id == teamID }) {
                    teams[index] = updatedTeam
                }
                myTeams.append(updatedTeam)
                isLoading = false
            }
            
            print("✅ Successfully joined team: \(team.name)")
            return .success(true)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to join team: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to join team: \(error)")
            return .failure(error)
        }
    }
    
    /// Leave a team
    func leaveTeam(teamID: String, userID: String) async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get team and check if user is captain
            let teamRecordID = CKRecord.ID(recordName: teamID)
            let teamRecord = try await publicDatabase.record(for: teamRecordID)
            
            guard let team = Team(record: teamRecord) else {
                throw TeamServiceError.teamNotFound
            }
            
            guard team.captainID != userID else {
                throw TeamServiceError.captainCannotLeave
            }
            
            // Delete team member record
            let memberRecordID = CKRecord.ID(recordName: "\(teamID)_\(userID)")
            try await publicDatabase.deleteRecord(withID: memberRecordID)
            
            // Update team's member list
            var updatedTeam = team
            updatedTeam.memberIDs.removeAll { $0 == userID }
            let updatedTeamRecord = updatedTeam.toCKRecord(container: container)
            try await publicDatabase.save(updatedTeamRecord)
            
            await MainActor.run {
                // Update local arrays
                if let index = teams.firstIndex(where: { $0.id == teamID }) {
                    teams[index] = updatedTeam
                }
                myTeams.removeAll { $0.id == teamID }
                isLoading = false
            }
            
            print("✅ Successfully left team: \(team.name)")
            return .success(true)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to leave team: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to leave team: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Team Messaging
    
    /// Send a message to team chat
    func sendMessage(teamID: String, senderID: String, senderName: String, content: String, messageType: TeamMessage.MessageType = .text) async -> Result<TeamMessage, Error> {
        
        do {
            let message = TeamMessage(
                teamID: teamID,
                senderID: senderID,
                senderName: senderName,
                content: content,
                messageType: messageType
            )
            
            let record = message.toCKRecord(container: container)
            let savedRecord = try await publicDatabase.save(record)
            
            if let savedMessage = TeamMessage(record: savedRecord) {
                await MainActor.run {
                    if teamMessages[teamID] == nil {
                        teamMessages[teamID] = []
                    }
                    teamMessages[teamID]?.append(savedMessage)
                    // Sort messages by timestamp
                    teamMessages[teamID]?.sort { $0.timestamp < $1.timestamp }
                }
                
                print("✅ Message sent to team \(teamID)")
                return .success(savedMessage)
            } else {
                throw TeamServiceError.invalidMessageData
            }
        } catch {
            print("❌ Failed to send message: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch messages for a team
    func fetchTeamMessages(teamID: String, limit: Int = 50) async -> Result<[TeamMessage], Error> {
        do {
            let predicate = NSPredicate(format: "teamID == %@", teamID)
            let query = CKQuery(recordType: TeamMessage.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let messages = records.compactMap { TeamMessage(record: $0) }.reversed() // Show oldest first
            let messagesArray = Array(messages)
            
            await MainActor.run {
                teamMessages[teamID] = messagesArray
            }
            
            print("✅ Fetched \(messages.count) messages for team \(teamID)")
            return .success(Array(messages))
        } catch {
            print("❌ Failed to fetch team messages: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Team Statistics
    
    /// Fetch team statistics
    func fetchTeamStats(teamID: String) async -> Result<TeamStatsCloudKit, Error> {
        do {
            let recordID = CKRecord.ID(recordName: teamID)
            let record = try await publicDatabase.record(for: recordID)
            
            if let stats = TeamStatsCloudKit(record: record) {
                await MainActor.run {
                    teamStats[teamID] = stats
                }
                return .success(stats)
            } else {
                throw TeamServiceError.invalidStatsData
            }
        } catch {
            print("❌ Failed to fetch team stats: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupCloudKitSubscriptions() async {
        do {
            // Subscribe to team changes
            let teamPredicate = NSPredicate(value: true)
            let teamSubscription = CKQuerySubscription(
                recordType: Team.recordType,
                predicate: teamPredicate,
                subscriptionID: "team-changes-subscription",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let teamNotificationInfo = CKSubscription.NotificationInfo()
            teamNotificationInfo.shouldSendContentAvailable = true
            teamSubscription.notificationInfo = teamNotificationInfo
            
            let savedTeamSub = try await publicDatabase.save(teamSubscription)
            subscriptions.append(savedTeamSub)
            
            // Subscribe to message changes (for real-time chat)
            let messageSubscription = CKQuerySubscription(
                recordType: TeamMessage.recordType,
                predicate: teamPredicate,
                subscriptionID: "team-messages-subscription",
                options: [.firesOnRecordCreation]
            )
            
            let messageNotificationInfo = CKSubscription.NotificationInfo()
            messageNotificationInfo.shouldSendContentAvailable = true
            messageSubscription.notificationInfo = messageNotificationInfo
            
            let savedMessageSub = try await publicDatabase.save(messageSubscription)
            subscriptions.append(savedMessageSub)
            
            print("✅ CloudKit subscriptions set up successfully")
        } catch {
            print("❌ Failed to set up CloudKit subscriptions: \(error)")
        }
    }
    
    private func loadInitialData() async {
        // Load public teams from CloudKit
        let _ = await fetchPublicTeams()
    }
    
    // MARK: - Validation Methods
    
    func canCreateTeam(user: User) -> Bool {
        return user.subscriptionTier == .captain || user.subscriptionTier == .organization
    }
    
    func canJoinTeam(user: User) -> Bool {
        return user.subscriptionTier != .none // All paid tiers can join teams
    }
    
    func getMaxTeamsForUser(user: User) -> Int {
        switch user.subscriptionTier {
        case .none: return 0
        case .member: return Int.max // Can join unlimited teams
        case .captain: return 5 // Can create up to 5 teams
        case .organization: return Int.max // Unlimited
        }
    }
}

// MARK: - Error Types

enum TeamServiceError: LocalizedError {
    case teamNotFound
    case teamFull
    case alreadyMember
    case captainCannotLeave
    case invalidTeamData
    case invalidMessageData
    case invalidStatsData
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .teamNotFound:
            return "Team not found"
        case .teamFull:
            return "Team is at maximum capacity"
        case .alreadyMember:
            return "Already a member of this team"
        case .captainCannotLeave:
            return "Team captain cannot leave the team"
        case .invalidTeamData:
            return "Invalid team data"
        case .invalidMessageData:
            return "Invalid message data"
        case .invalidStatsData:
            return "Invalid statistics data"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}