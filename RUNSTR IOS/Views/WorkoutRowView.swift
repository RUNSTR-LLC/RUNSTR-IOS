import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout
    
    var body: some View {
        HStack(spacing: RunstrSpacing.md) {
            // Activity icon
            Image(systemName: workout.activityType.systemImageName)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())
            
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.activityType.displayName)
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    Spacer()
                    
                    Text(formatTimeAgo(workout.startTime))
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                HStack(spacing: RunstrSpacing.md) {
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text(workout.distanceFormatted)
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text(workout.durationFormatted)
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    // Pace
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text("\(String(format: "%.1f", workout.averagePace)) min/km")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    Spacer()
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
        }
        .padding(.vertical, RunstrSpacing.xs)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    VStack {
        WorkoutRowView(workout: Workout(
            activityType: .running,
            startTime: Date().addingTimeInterval(-3600), // 1 hour ago
            endTime: Date().addingTimeInterval(-1800), // 30 min ago
            distance: 5000, // 5km
            calories: 350,
            averageHeartRate: 145,
            locations: []
        ))
        
        WorkoutRowView(workout: Workout(
            activityType: .cycling,
            startTime: Date().addingTimeInterval(-86400), // 1 day ago
            endTime: Date().addingTimeInterval(-83400), // 50 min session
            distance: 15000, // 15km
            calories: 500,
            averageHeartRate: 135,
            locations: []
        ))
    }
    .padding()
    .background(Color.runstrBackground)
}