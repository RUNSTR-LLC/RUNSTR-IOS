import SwiftUI

struct TeamChatView: View {
    let team: Team
    
    @EnvironmentObject var teamService: TeamService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var messages: [TeamMessage] {
        teamService.teamMessages[team.id] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            messagesListView
            
            // Message Input
            messageInputView
        }
        .background(Color.runstrBackground)
        .onAppear {
            loadMessages()
        }
    }
    
    // MARK: - Messages List
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: RunstrSpacing.sm) {
                    if messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(messages) { message in
                            MessageRow(
                                message: message,
                                isCurrentUser: message.senderID == authService.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: RunstrSpacing.md) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.runstrGray)
            
            VStack(spacing: RunstrSpacing.sm) {
                Text("No messages yet")
                    .font(.runstrTitle3)
                    .foregroundColor(.runstrWhite)
                
                Text("Be the first to say something to your team!")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, RunstrSpacing.xl)
    }
    
    // MARK: - Message Input
    
    private var messageInputView: some View {
        HStack(spacing: RunstrSpacing.sm) {
            // Text Input
            HStack {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.runstrWhite)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .onSubmit {
                        if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                            sendMessage()
                        }
                    }
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.vertical, RunstrSpacing.sm)
            .background(Color.runstrDark)
            .cornerRadius(RunstrSpacing.lg)
            
            // Send Button
            Button {
                sendMessage()
            } label: {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .runstrBackground))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(canSendMessage ? .runstrBackground : .runstrGray)
                }
            }
            .frame(width: 44, height: 44)
            .background(canSendMessage ? Color.runstrWhite : Color.runstrDark)
            .cornerRadius(22)
            .disabled(!canSendMessage || isSending)
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.vertical, RunstrSpacing.sm)
        .background(Color.runstrBackground)
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Actions
    
    private func loadMessages() {
        Task {
            let _ = await teamService.fetchTeamMessages(teamID: team.id)
        }
    }
    
    private func sendMessage() {
        guard let user = authService.currentUser,
              !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let content = messageText.trimmingCharacters(in: .whitespaces)
        messageText = ""
        isSending = true
        
        Task {
            let senderName = user.profile.displayName.isEmpty ? "User" : user.profile.displayName
            let result = await teamService.sendMessage(
                teamID: team.id,
                senderID: user.id,
                senderName: senderName,
                content: content
            )
            
            await MainActor.run {
                isSending = false
            }
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: TeamMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                currentUserMessageView
            } else {
                otherUserMessageView
                Spacer()
            }
        }
    }
    
    private var currentUserMessageView: some View {
        VStack(alignment: .trailing, spacing: RunstrSpacing.xs) {
            messageContentView
                .background(Color.runstrWhite)
                .foregroundColor(.runstrBackground)
            
            Text(formatTime(message.timestamp))
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
    }
    
    private var otherUserMessageView: some View {
        HStack(alignment: .top, spacing: RunstrSpacing.sm) {
            // Avatar
            Circle()
                .fill(Color.runstrDark)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(message.senderName.prefix(1).uppercased())
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                )
            
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                // Sender name and timestamp
                HStack {
                    Text(message.senderName)
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    Text(formatTime(message.timestamp))
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                messageContentView
                    .background(Color.runstrDark)
                    .foregroundColor(.runstrWhite)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
    }
    
    private var messageContentView: some View {
        Group {
            switch message.messageType {
            case .text:
                Text(message.content)
                    .font(.runstrBody)
                    .padding(.horizontal, RunstrSpacing.md)
                    .padding(.vertical, RunstrSpacing.sm)
                    .cornerRadius(RunstrSpacing.md, corners: isCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                    
            case .system:
                HStack {
                    Image(systemName: "info.circle")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    Text(message.content)
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .italic()
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
                .background(Color.runstrDark.opacity(0.5))
                .cornerRadius(RunstrSpacing.md)
                
            case .workout:
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                    
                    Text(message.content)
                        .font(.runstrBody)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
                .cornerRadius(RunstrSpacing.md)
                
            case .challenge:
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                    
                    Text(message.content)
                        .font(.runstrBody)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
                .cornerRadius(RunstrSpacing.md)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "E h:mm a"
        } else {
            formatter.dateFormat = "M/d h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let sampleTeam = Team(
        name: "Morning Runners",
        description: "Early bird runners",
        captainID: "captain123",
        activityLevel: .intermediate
    )
    
    return TeamChatView(team: sampleTeam)
        .environmentObject(TeamService())
        .environmentObject(AuthenticationService())
}