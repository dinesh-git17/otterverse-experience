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
    static let unlockIconSize: CGFloat = 64
    static let unlockSpacing: CGFloat = 6
    static let unlockTracking: CGFloat = 3
    static let unlockMinTouchHeight: CGFloat = 88
    static let cryptexToUnlockSpacing: CGFloat = 32
    static let victoryExitScale: CGFloat = 1.5

    // Intro card
    static let introCardMaxWidth: CGFloat = 320
    static let introCardCornerRadius: CGFloat = 24
    static let introCardPadding: CGFloat = 36
    static let introCardSpacing: CGFloat = 24
    static let introHeadlineTracking: CGFloat = 2.5
    static let introSubtextTracking: CGFloat = 0.8
    static let introSubtextTopPadding: CGFloat = 4
    static let introButtonHorizontalPadding: CGFloat = 40
    static let introButtonVerticalPadding: CGFloat = 14
    static let introButtonCornerRadius: CGFloat = 12
    static let introButtonTracking: CGFloat = 2
    static let introButtonTopPadding: CGFloat = 8
    static let introCardBlurRadius: CGFloat = 0.5
    static let introCardBorderWidth: CGFloat = 0.5
    static let introCardBorderOpacity: Double = 0.15
    static let introCardBackgroundOpacity: Double = 0.55
    static let introBackgroundBlur: CGFloat = 12
    static let puzzleBackgroundBlur: CGFloat = 6
}

// MARK: - Chapter 3 Animation Constants

enum Ch3Anim {
    static let shakeResponse: Double = 0.08
    static let shakeDamping: Double = 0.3
    static let victoryDuration: Double = 0.45
    static let victoryReducedDuration: Double = 0.3
    static let introFadeResponse: Double = 0.6
    static let introFadeDamping: Double = 0.8
    static let introReducedFadeDuration: Double = 0.35
}

// MARK: - Chapter 3 Timing Constants

enum Ch3Timing {
    static let shakeResetDelayMs: Int = 100
    static let flashResetDelayMs: Int = 200
    static let victoryTransitionMs: Int = 500
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
