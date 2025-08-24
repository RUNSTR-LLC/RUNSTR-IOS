import UIKit
import Foundation

class HapticFeedbackService: ObservableObject {
    private let impactFeedbackLight = UIImpactFeedbackGenerator(style: .light)
    private let impactFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactFeedbackHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "enableHapticFeedback") as? Bool ?? true
    }
    
    init() {
        // Prepare feedback generators for reduced latency
        impactFeedbackLight.prepare()
        impactFeedbackMedium.prepare()
        impactFeedbackHeavy.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Workout Events
    
    func workoutStarted() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        print("🔵 Haptic: Workout started")
    }
    
    func workoutPaused() {
        guard isEnabled else { return }
        impactFeedbackMedium.impactOccurred()
        print("🟡 Haptic: Workout paused")
    }
    
    func workoutResumed() {
        guard isEnabled else { return }
        impactFeedbackLight.impactOccurred()
        print("🟢 Haptic: Workout resumed")
    }
    
    func workoutEnded() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        // Add a second haptic for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactFeedbackHeavy.impactOccurred()
        }
        print("🔴 Haptic: Workout ended")
    }
    
    // MARK: - Distance Milestones
    
    func distanceMilestone() {
        guard isEnabled else { return }
        impactFeedbackMedium.impactOccurred()
        print("📏 Haptic: Distance milestone")
    }
    
    func splitCompleted() {
        guard isEnabled else { return }
        impactFeedbackLight.impactOccurred()
        print("⏱️ Haptic: Split completed")
    }
    
    // MARK: - UI Interactions
    
    func buttonTap() {
        guard isEnabled else { return }
        impactFeedbackLight.impactOccurred()
    }
    
    func selectionChanged() {
        guard isEnabled else { return }
        impactFeedbackLight.impactOccurred()
    }
    
    // MARK: - Error/Warning States
    
    func error() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
        print("❌ Haptic: Error")
    }
    
    func warning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
        print("⚠️ Haptic: Warning")
    }
    
    // MARK: - Custom Patterns
    
    func countdownTick() {
        guard isEnabled else { return }
        impactFeedbackLight.impactOccurred()
    }
    
    func countdownFinal() {
        guard isEnabled else { return }
        impactFeedbackHeavy.impactOccurred()
    }
    
    // MARK: - Utility
    
    func prepareFeedback() {
        // Re-prepare generators to ensure responsiveness
        impactFeedbackLight.prepare()
        impactFeedbackMedium.prepare()
        impactFeedbackHeavy.prepare()
        notificationFeedback.prepare()
    }
}