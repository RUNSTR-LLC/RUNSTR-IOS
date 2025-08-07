import SwiftUI

struct TeamCreationView: View {
    @EnvironmentObject var teamService: TeamService
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var teamName = ""
    @State private var teamDescription = ""
    @State private var selectedActivityLevel: ActivityLevel = .intermediate
    @State private var selectedActivityTypes: Set<ActivityType> = [.running]
    @State private var location = ""
    @State private var maxMembers = 50
    @State private var teamType = "running_club"
    
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Validation computed properties
    private var canCreateTeam: Bool {
        guard let user = authService.currentUser else { return false }
        return teamService.canCreateTeam(user: user) && isFormValid
    }
    
    private var isFormValid: Bool {
        !teamName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !teamDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedActivityTypes.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header
                    headerSection
                    
                    // Form
                    formSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    Spacer(minLength: RunstrSpacing.xl)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: RunstrSpacing.sm) {
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.runstrWhite)
                
                Spacer()
                
                Text("Create Team")
                    .font(.runstrTitle2)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                Button("Create") {
                    createTeam()
                }
                .foregroundColor(canCreateTeam ? .runstrWhite : .runstrGray)
                .disabled(!canCreateTeam)
            }
        }
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: RunstrSpacing.lg) {
            // Team Name
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Team Name")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                TextField("Enter team name", text: $teamName)
                    .textFieldStyle(RunstrTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Team Description
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Description")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                TextField("Describe your team's goals and culture", text: $teamDescription, axis: .vertical)
                    .textFieldStyle(RunstrTextAreaStyle())
                    .lineLimit(4...8)
            }
            
            // Activity Types
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Supported Activities")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                ActivityTypeSelector(selectedTypes: $selectedActivityTypes)
            }
            
            // Activity Level
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Activity Level")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                ActivityLevelSelector(selectedLevel: $selectedActivityLevel)
            }
            
            // Location (Optional)
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Location (Optional)")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                TextField("City, region", text: $location)
                    .textFieldStyle(RunstrTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Max Members
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                Text("Maximum Members")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                HStack {
                    Slider(value: Binding(
                        get: { Double(maxMembers) },
                        set: { maxMembers = Int($0) }
                    ), in: 10...500, step: 10)
                    .accentColor(.runstrWhite)
                    
                    Text("\(maxMembers)")
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                        .frame(width: 50)
                }
                .runstrCard()
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            if isCreating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .runstrWhite))
                    
                    Text("Creating team...")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                }
            }
            
            if let user = authService.currentUser, !teamService.canCreateTeam(user: user) {
                VStack(spacing: RunstrSpacing.sm) {
                    Text("Upgrade to Captain tier to create teams")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                    
                    Button("Upgrade Now") {
                        // Navigate to subscription upgrade
                    }
                    .buttonStyle(RunstrSecondaryButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createTeam() {
        guard let user = authService.currentUser else { return }
        
        isCreating = true
        
        Task {
            let result = await teamService.createTeam(
                name: teamName.trimmingCharacters(in: .whitespaces),
                description: teamDescription.trimmingCharacters(in: .whitespaces),
                captainID: user.id,
                activityLevel: selectedActivityLevel,
                maxMembers: maxMembers,
                teamType: teamType,
                location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespaces),
                supportedActivityTypes: Array(selectedActivityTypes)
            )
            
            await MainActor.run {
                isCreating = false
                
                switch result {
                case .success(_):
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Activity Type Selector

struct ActivityTypeSelector: View {
    @Binding var selectedTypes: Set<ActivityType>
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: RunstrSpacing.sm) {
            ForEach(ActivityType.allCases, id: \.self) { activityType in
                ActivityTypeCard(
                    activityType: activityType,
                    isSelected: selectedTypes.contains(activityType)
                ) {
                    if selectedTypes.contains(activityType) {
                        selectedTypes.remove(activityType)
                    } else {
                        selectedTypes.insert(activityType)
                    }
                }
            }
        }
    }
}

struct ActivityTypeCard: View {
    let activityType: ActivityType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: RunstrSpacing.xs) {
                Image(systemName: activityType.systemImageName)
                    .font(.title3)
                    .foregroundColor(isSelected ? .runstrBackground : .runstrWhite)
                
                Text(activityType.displayName)
                    .font(.runstrCaption)
                    .foregroundColor(isSelected ? .runstrBackground : .runstrWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, RunstrSpacing.sm)
            .padding(.horizontal, RunstrSpacing.xs)
            .frame(height: 60)
            .background(isSelected ? Color.runstrWhite : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: RunstrSpacing.sm)
                    .stroke(isSelected ? Color.runstrWhite : Color.runstrGray, lineWidth: 1)
            )
            .cornerRadius(RunstrSpacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Activity Level Selector

struct ActivityLevelSelector: View {
    @Binding var selectedLevel: ActivityLevel
    
    var body: some View {
        VStack(spacing: RunstrSpacing.sm) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                Button {
                    selectedLevel = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text(level.displayName)
                                .font(.runstrBody)
                                .foregroundColor(selectedLevel == level ? .runstrBackground : .runstrWhite)
                                .fontWeight(.medium)
                            
                            Text(level.description)
                                .font(.runstrCaption)
                                .foregroundColor(selectedLevel == level ? .runstrBackground.opacity(0.8) : .runstrGray)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        if selectedLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.runstrBackground)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.runstrGray)
                        }
                    }
                    .padding(RunstrSpacing.md)
                    .background(selectedLevel == level ? Color.runstrWhite : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: RunstrSpacing.sm)
                            .stroke(selectedLevel == level ? Color.runstrWhite : Color.runstrGray, lineWidth: 1)
                    )
                    .cornerRadius(RunstrSpacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Custom Text Field Styles

struct RunstrTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(RunstrSpacing.md)
            .background(Color.runstrDark)
            .foregroundColor(.runstrWhite)
            .cornerRadius(RunstrSpacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: RunstrSpacing.sm)
                    .stroke(Color.runstrGray.opacity(0.5), lineWidth: 1)
            )
    }
}

struct RunstrTextAreaStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(RunstrSpacing.md)
            .background(Color.runstrDark)
            .foregroundColor(.runstrWhite)
            .cornerRadius(RunstrSpacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: RunstrSpacing.sm)
                    .stroke(Color.runstrGray.opacity(0.5), lineWidth: 1)
            )
    }
}

#Preview {
    TeamCreationView()
        .environmentObject(TeamService())
        .environmentObject(AuthenticationService())
}