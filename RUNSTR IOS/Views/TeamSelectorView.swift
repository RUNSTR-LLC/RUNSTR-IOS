import SwiftUI

struct TeamSelectorView: View {
    @Binding var selectedTeam: TeamSelection?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nostrService: NostrService
    @State private var searchText = ""
    
    private var filteredTeams: [TeamSelection] {
        let teamSelections = nostrService.availableTeams.map { team in
            TeamSelection(
                teamID: team.id,
                teamName: team.name,
                captainName: "Captain", // We don't have captain names in the current Team model
                memberCount: team.memberCount,
                activityLevel: activityLevelToSelection(team.activityLevel)
            )
        }
        
        if searchText.isEmpty {
            return teamSelections
        } else {
            return teamSelections.filter { team in
                team.teamName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func activityLevelToSelection(_ level: ActivityLevel) -> TeamSelection.ActivityLevel {
        switch level {
        case .beginner: return .casual
        case .intermediate: return .active
        case .advanced: return .competitive
        case .competitive: return .competitive
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchSection
                
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredTeams, id: \.teamID) { team in
                            TeamRowView(
                                team: team,
                                isSelected: selectedTeam?.teamID == team.teamID
                            ) {
                                selectedTeam = team
                                dismiss()
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Choose Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await nostrService.fetchAvailableTeams()
            }
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search teams...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.top, 20)
        }
    }
}

struct TeamRowView: View {
    let team: TeamSelection
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(team.teamName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        ActivityLevelBadge(level: team.activityLevel)
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            
                            Text(team.captainName)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.3")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            
                            Text("\(team.memberCount) members")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(isSelected ? Color.white.opacity(0.05) : Color.clear)
            )
        }
    }
}

struct ActivityLevelBadge: View {
    let level: TeamSelection.ActivityLevel
    
    private var badgeColor: Color {
        switch level {
        case .casual: return .blue
        case .active: return .orange
        case .competitive: return .red
        }
    }
    
    var body: some View {
        Text(level.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(4)
    }
}

#Preview {
    TeamSelectorView(selectedTeam: .constant(nil))
}