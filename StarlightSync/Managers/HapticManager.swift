import CoreHaptics
import os

@Observable
@MainActor
final class HapticManager {
    // MARK: - Pattern Identifiers

    private let patternHeartbeat = "heartbeat"
    private let patternCapacitorCharge = "capacitor_charge"
    private let patternThud = "thud"
    private let ahapFileExtension = "ahap"

    // MARK: - Singleton

    static let shared = HapticManager()

    // MARK: - Observable State

    private(set) var engineAvailable = false

    // MARK: - Engine

    private var engine: CHHapticEngine?

    // MARK: - Pattern Cache

    private var cachedPatterns: [String: CHHapticPattern] = [:]

    // MARK: - Dependencies

    private let bundleResolver: @Sendable (String, String?) -> URL?

    // MARK: - Diagnostics

    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.otterverse.starlightsync",
            category: "HapticManager"
        )
    #endif

    // MARK: - Initialization

    private init(
        bundleResolver: @escaping @Sendable (String, String?) -> URL? = { name, ext in
            Bundle.main.url(forResource: name, withExtension: ext)
        }
    ) {
        self.bundleResolver = bundleResolver
        setupEngine()
    }

    // MARK: - Engine Setup (S2)

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            engineAvailable = false
            return
        }

        do {
            let newEngine = try CHHapticEngine()
            engine = newEngine
            registerStoppedHandler(on: newEngine)
            registerResetHandler(on: newEngine)
            try newEngine.start()
            engineAvailable = true
        } catch {
            #if DEBUG
                Self.logger.error("Engine creation failed: \(error.localizedDescription)")
            #endif
            engine = nil
            engineAvailable = false
        }
    }

    // MARK: - Stopped Handler (S3)

    private func registerStoppedHandler(on target: CHHapticEngine) {
        target.stoppedHandler = { [weak self] reason in
            #if DEBUG
                Task { @MainActor in
                    Self.logger.error("Engine stopped: \(reason.rawValue)")
                }
            #endif

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let currentEngine = self.engine else {
                    self.engineAvailable = false
                    return
                }
                do {
                    try currentEngine.start()
                } catch {
                    #if DEBUG
                        Self.logger.error("Engine restart failed: \(error.localizedDescription)")
                    #endif
                    self.engineAvailable = false
                }
            }
        }
    }

    // MARK: - Reset Handler (S4)

    private func registerResetHandler(on target: CHHapticEngine) {
        target.resetHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildEngine()
            }
        }
    }

    private func rebuildEngine() {
        do {
            let newEngine = try CHHapticEngine()
            registerStoppedHandler(on: newEngine)
            registerResetHandler(on: newEngine)
            try newEngine.start()
            engine = newEngine
            cachedPatterns.removeAll()
            loadAllPatterns()
            engineAvailable = true
        } catch {
            #if DEBUG
                Self.logger.error("Engine rebuild failed: \(error.localizedDescription)")
            #endif
            engine = nil
            engineAvailable = false
        }
    }

    // MARK: - Pattern Loading (S5)

    func preloadPatterns() {
        guard engineAvailable else { return }
        loadAllPatterns()
    }

    private func loadAllPatterns() {
        let identifiers = [patternHeartbeat, patternCapacitorCharge, patternThud]
        for identifier in identifiers {
            guard cachedPatterns[identifier] == nil else { continue }
            guard let url = bundleResolver(identifier, ahapFileExtension) else {
                #if DEBUG
                    Self.logger.warning("AHAP file not found: \(identifier)")
                #endif
                continue
            }
            do {
                let pattern = try CHHapticPattern(contentsOf: url)
                cachedPatterns[identifier] = pattern
            } catch {
                #if DEBUG
                    Self.logger.warning("AHAP parse failed for \(identifier): \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - AHAP Playback (S6)

    func play(_ patternName: String) {
        guard engineAvailable, let hapticEngine = engine else { return }
        guard let pattern = cachedPatterns[patternName] else { return }

        do {
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
                Self.logger.error("Pattern playback failed for \(patternName): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Transient Event Playback (S7)

    func playTransientEvent(intensity: Float, sharpness: Float) {
        guard engineAvailable, let hapticEngine = engine else { return }

        let clampedIntensity = min(max(intensity, 0.0), 1.0)
        let clampedSharpness = min(max(sharpness, 0.0), 1.0)

        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: clampedSharpness)
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
                Self.logger.error("Transient event playback failed: \(error.localizedDescription)")
            #endif
        }
    }
}
