import SwiftUI

// MARK: - Chapter 3 Color Palette

enum Ch3Color {
    static let steelLight = Color(red: 0.73, green: 0.76, blue: 0.81)
    static let steelMid = Color(red: 0.50, green: 0.53, blue: 0.58)
    static let steelDark = Color(red: 0.28, green: 0.31, blue: 0.36)
    static let steelDeep = Color(red: 0.14, green: 0.16, blue: 0.20)
    static let divider = Color(red: 0.38, green: 0.41, blue: 0.46)
    static let innerShadow = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let specularHighlight = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let lockGold = Color(red: 0.82, green: 0.72, blue: 0.45)
    static let lockGoldDark = Color(red: 0.58, green: 0.50, blue: 0.30)
    static let ambientText = Color(red: 0.55, green: 0.58, blue: 0.64)
    static let errorFlash = Color(red: 0.88, green: 0.32, blue: 0.28)
    static let introCardFill = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let introHeadline = Color(red: 0.85, green: 0.87, blue: 0.91)
    static let introSubtext = Color(red: 0.58, green: 0.61, blue: 0.67)
    static let introButtonText = Color(red: 0.10, green: 0.11, blue: 0.14)

    // Loupe & Glass
    static let loupeBorder = Color(red: 0.85, green: 0.88, blue: 0.92).opacity(0.1) // Reduced from 0.15
    static let loupeShine = Color.white.opacity(0.05) // Reduced from 0.08
    static let loupeGlass = Color.clear
    static let cylinderShadow = Color.black.opacity(0.6) // Translucent shadow instead of solid block
    static let vignetteColor = Color.black.opacity(0.6)

    // Latch / Unlock
    static let latchFace = Color(red: 0.20, green: 0.22, blue: 0.26)
    static let latchHighlight = Color(red: 0.35, green: 0.38, blue: 0.44)
    static let latchActiveFill = Color(red: 0.82, green: 0.72, blue: 0.45) // Gold
    static let latchLockedText = Color(red: 0.55, green: 0.58, blue: 0.64)

    // Intro Card (FAANG Polish)
    static let cardGlassFill = Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.85)
    static let cardBorderTop = Color.white.opacity(0.12)
    static let cardBorderBottom = Color.black.opacity(0.4)
    static let cardShadow = Color.black.opacity(0.5)
    static let buttonGradientStart = Color(red: 0.25, green: 0.27, blue: 0.30)
    static let buttonGradientEnd = Color(red: 0.15, green: 0.17, blue: 0.20)
    static let buttonBorder = Color.white.opacity(0.1)
    static let buttonGlow = Color(red: 0.30, green: 0.68, blue: 1.0).opacity(0.3)
}

// MARK: - Chapter 3 Layout Constants

enum Ch3Layout {
    static let frameCornerRadius: CGFloat = 18
    static let frameWidth: CGFloat = 260
    static let metalEdgeHeight: CGFloat = 14
    static let dividerHeight: CGFloat = 2
    static let dividerHorizontalPadding: CGFloat = 20
    static let specularLineHeight: CGFloat = 1
    static let specularHorizontalPadding: CGFloat = 8
    static let specularTopPadding: CGFloat = 6
    static let specularOpacity: Double = 0.15
    static let innerShadowLineWidth: CGFloat = 2
    static let innerShadowRadius: CGFloat = 8
    static let innerShadowYOffset: CGFloat = 2
    static let innerShadowOpacity: Double = 0.6
    static let shakeDistance: CGFloat = 12
    static let cryptexToUnlockSpacing: CGFloat = 32
    static let victoryExitScale: CGFloat = 1.5

    // Latch
    static let latchWidth: CGFloat = 200
    static let latchHeight: CGFloat = 56
    static let latchCornerRadius: CGFloat = 12
    static let latchDepressOffset: CGFloat = 4
    static let latchStrokeWidth: CGFloat = 1

    // Loupe
    static let loupeHeight: CGFloat = 68 // Slightly larger than segment height (64)
    static let loupeBorderWidth: CGFloat = 1
    static let loupeCornerRadius: CGFloat = 8

    // Intro card
    static let introCardMaxWidth: CGFloat = 340
    static let introCardCornerRadius: CGFloat = 32
    static let introCardPadding: CGFloat = 40
    static let introCardSpacing: CGFloat = 28
    static let introHeadlineTracking: CGFloat = 0.5
    static let introSubtextTracking: CGFloat = 0.3
    static let introSubtextTopPadding: CGFloat = 8
    static let introButtonHorizontalPadding: CGFloat = 0
    static let introButtonVerticalPadding: CGFloat = 16
    static let introButtonCornerRadius: CGFloat = 16
    static let introButtonTracking: CGFloat = 3
    static let introButtonTopPadding: CGFloat = 12
    static let introCardBlurRadius: CGFloat = 0.5
    static let introCardBorderWidth: CGFloat = 1
    static let introShadowRadius: CGFloat = 30
    static let introShadowY: CGFloat = 10
    static let introBackgroundBlur: CGFloat = 20
    static let puzzleBackgroundBlur: CGFloat = 0 // Clear view for puzzle
}

// MARK: - Chapter 3 Animation Constants

enum Ch3Anim {
    static let shakeResponse: Double = 0.08
    static let shakeDamping: Double = 0.3
    static let victoryDuration: Double = 0.45
    static let victoryReducedDuration: Double = 0.3
    static let introExitDuration: Double = 0.4 // Significantly faster (was 0.8)
    static let introScaleTarget: CGFloat = 1.15
    static let puzzleEntryScaleStart: CGFloat = 0.95 // Closer to 1.0 for less travel
    static let puzzleEntryResponse: Double = 0.35 // Snappy spring (was 0.6)
    static let puzzleEntryDamping: Double = 0.8 // Tighter control
    static let puzzleEntryDelay: Double = 0.0 // Immediate start
}

// MARK: - Chapter 3 Timing Constants

enum Ch3Timing {
    static let shakeResetDelayMs: Int = 100
    static let flashResetDelayMs: Int = 200
    static let victoryTransitionMs: Int = 500
}

// MARK: - Chapter 3 Physics Constants

enum Ch3Physics {
    static let scrollInertiaFactor: CGFloat = 0.2 // Velocity multiplier for fling
    static let scrollDecayRate: CGFloat = 0.998 // Not used directly if we use predicted end
    static let latchHoldDuration: Double = 0.6 // Seconds to fill the latch
    static let latchHapticInterval: Double = 0.05 // Haptic tick interval during hold
}

// MARK: - Chapter 3 Haptic Constants

enum Ch3Haptic {
    static let errorIntensity: Float = 0.9
    static let errorSharpness: Float = 0.6
}

// MARK: - Puzzle Data

enum Ch3Puzzle {
    static let wheel1Segments = ["WE HAVE", "IT WILL", "THIS IS", "YOU ARE", "THEY DO"]
    static let wheel1Answer = 2
    static let wheel2Segments = ["ABSOLUTE", "TERRIBLE", "RECKLESS", "CRIMINAL", "ROMANTIC"]
    static let wheel2Answer = 3
    static let wheel3Segments = ["DEVOTION", "BEHAVIOUR", "DISORDER", "EVIDENCE", "NONSENSE"]
    static let wheel3Answer = 1
}
