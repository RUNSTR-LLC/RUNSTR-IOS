import SwiftUI

struct SimpleWorkoutSummaryView: View {
    let workout: Workout
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Workout Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(workout.activityType.displayName)
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
                
                // Stats Grid
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        StatBox(
                            title: "Distance",
                            value: workout.distanceFormatted,
                            icon: "location.fill"
                        )
                        
                        StatBox(
                            title: "Duration",
                            value: workout.durationFormatted,
                            icon: "clock.fill"
                        )
                    }
                    
                    HStack(spacing: 20) {
                        StatBox(
                            title: "Pace",
                            value: workout.pace,
                            icon: "speedometer"
                        )
                        
                        if let calories = workout.calories {
                            StatBox(
                                title: "Calories",
                                value: "\(Int(calories))",
                                icon: "flame.fill"
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Done Button
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Save workout to local storage
            workoutStorage.saveWorkout(workout)
            print("✅ Workout saved in summary view")
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

#Preview {
    SimpleWorkoutSummaryView(
        workout: Workout(
            activityType: .running,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            distance: 5000,
            calories: 350
        )
    )
    .environmentObject(WorkoutStorage())
}