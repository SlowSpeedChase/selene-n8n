// ResurfaceTriggerService.swift
// SeleneChat
//
// Phase 7.2e: Bidirectional Things Flow
// Evaluates resurface triggers based on task completion status

import Foundation

// MARK: - Resurface Config

/// Configuration for resurface triggers
/// Defaults match config/resurface-triggers.yaml
struct ResurfaceConfig {
    let progressTrigger: ProgressTrigger
    let stuckTrigger: StuckTrigger
    let completionTrigger: CompletionTrigger

    struct ProgressTrigger {
        let enabled: Bool
        let thresholdPercent: Int
        let message: String
        let triggerOnce: Bool
    }

    struct StuckTrigger {
        let enabled: Bool
        let daysInactive: Int
        let message: String
        let cooldownDays: Int
    }

    struct CompletionTrigger {
        let enabled: Bool
        let message: String
        let celebration: Bool
    }

    /// Default config matching config/resurface-triggers.yaml
    static let `default` = ResurfaceConfig(
        progressTrigger: ProgressTrigger(
            enabled: true,
            thresholdPercent: 50,
            message: "Good progress! Ready to plan next steps?",
            triggerOnce: true
        ),
        stuckTrigger: StuckTrigger(
            enabled: true,
            daysInactive: 3,
            message: "This seems stuck. Want to rethink the approach?",
            cooldownDays: 7
        ),
        completionTrigger: CompletionTrigger(
            enabled: true,
            message: "All tasks done! Want to reflect or plan what's next?",
            celebration: true
        )
    )
}

// MARK: - Resurface Trigger

enum ResurfaceTrigger {
    case progress(percent: Int, message: String)
    case stuck(days: Int, message: String)
    case completion(message: String)

    var reasonCode: String {
        switch self {
        case .progress(let percent, _): return "progress_\(percent)"
        case .stuck(let days, _): return "stuck_\(days)d"
        case .completion: return "completion"
        }
    }

    var message: String {
        switch self {
        case .progress(_, let msg), .stuck(_, let msg), .completion(let msg):
            return msg
        }
    }
}

// MARK: - Resurface Trigger Service

class ResurfaceTriggerService: ObservableObject {
    static let shared = ResurfaceTriggerService()

    private let config: ResurfaceConfig

    init(config: ResurfaceConfig = .default) {
        self.config = config
    }

    /// Evaluate all triggers for a thread based on its tasks
    /// - Parameters:
    ///   - thread: The discussion thread to evaluate
    ///   - tasks: Current status of tasks linked to this thread
    /// - Returns: The highest priority trigger that fired, or nil
    func evaluateTriggers(
        thread: DiscussionThread,
        tasks: [ThingsTaskStatus]
    ) -> ResurfaceTrigger? {
        guard !tasks.isEmpty else { return nil }

        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count
        let percent = (completed * 100) / total

        #if DEBUG
        print("[ResurfaceTriggerService] Thread \(thread.id): \(completed)/\(total) tasks completed (\(percent)%)")
        #endif

        // Priority order: completion > progress > stuck

        // 1. Completion trigger (100%)
        if config.completionTrigger.enabled && percent == 100 {
            #if DEBUG
            print("[ResurfaceTriggerService] Completion trigger fired for thread \(thread.id)")
            #endif
            return .completion(message: config.completionTrigger.message)
        }

        // 2. Progress trigger (threshold %)
        if config.progressTrigger.enabled &&
           percent >= config.progressTrigger.thresholdPercent &&
           percent < 100 {
            // Check trigger_once - only fire if not already resurfaced for progress
            let alreadyFiredProgress = thread.resurfaceReasonCode?.starts(with: "progress_") ?? false
            if !config.progressTrigger.triggerOnce || !alreadyFiredProgress {
                #if DEBUG
                print("[ResurfaceTriggerService] Progress trigger fired for thread \(thread.id) at \(percent)%")
                #endif
                return .progress(percent: percent, message: config.progressTrigger.message)
            }
        }

        // 3. Stuck trigger (days inactive)
        if config.stuckTrigger.enabled {
            let lastActivity = mostRecentActivity(tasks)
            let daysSince = Calendar.current.dateComponents(
                [.day],
                from: lastActivity,
                to: Date()
            ).day ?? 0

            if daysSince >= config.stuckTrigger.daysInactive {
                // Check cooldown
                if let lastResurfaced = thread.lastResurfacedAt {
                    let daysSinceResurface = Calendar.current.dateComponents(
                        [.day],
                        from: lastResurfaced,
                        to: Date()
                    ).day ?? 0

                    if daysSinceResurface < config.stuckTrigger.cooldownDays {
                        #if DEBUG
                        print("[ResurfaceTriggerService] Stuck trigger cooldown active for thread \(thread.id)")
                        #endif
                        return nil
                    }
                }

                #if DEBUG
                print("[ResurfaceTriggerService] Stuck trigger fired for thread \(thread.id) (\(daysSince) days)")
                #endif
                return .stuck(days: daysSince, message: config.stuckTrigger.message)
            }
        }

        return nil
    }

    /// Find the most recent modification date among tasks
    private func mostRecentActivity(_ tasks: [ThingsTaskStatus]) -> Date {
        tasks.map { $0.modificationDate }.max() ?? Date.distantPast
    }
}
