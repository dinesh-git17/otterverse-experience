---
name: swiftui-visual-fidelity
description: Enforce chapter-specific visual identity, animation curve precision, composition depth integrity, OLED-optimized rendering, material simulation fidelity, and anti-AI-slop safeguards for all SwiftUI views. Use when any SwiftUI view is implemented or modified, chapter transitions are styled, UI components are themed, visual review is requested, or fidelity validation is performed. Triggers on SwiftUI view creation, view styling, animation implementation, color usage, material application, composition layout, transition design, or visual audit requests.
---

# SwiftUI Visual Fidelity

Enforce production-grade visual identity, animation precision, and composition integrity across all SwiftUI chapter views. Prevent generic AI-generated aesthetic patterns. Every visual decision is deterministic and chapter-specific.

## Pre-Implementation Verification

Before writing or modifying any SwiftUI view code, verify:

1. The target chapter (1–6) and its visual identity are defined in `Design-Doc.md` §3 and §7.2.
2. The view file resides in the correct `Chapters/Chapter{N}_{Name}/` directory.
3. The chapter's color palette, material treatment, and animation curves are referenced from [references/visual-identity-rules.md](references/visual-identity-rules.md).

If any verification fails, **HALT** and cite the specific constraint.

## Color Fidelity Enforcement

### Mandatory Project Colors

Every color in a chapter view MUST use project-defined hex values from `GameConstants` or the Asset Catalog. Reference [references/visual-identity-rules.md](references/visual-identity-rules.md) for the complete per-chapter palette.

**Prohibited color patterns:**

```swift
// REJECTED — default system semantic colors as primary visual elements
Color.blue
Color.red
Color.green
Color.accentColor
Color.primary
Color.secondary
```

**Required color patterns:**

```swift
// APPROVED — project-defined colors via Asset Catalog or explicit hex
Color("ch1_glow_purple")                    // Asset Catalog named color
Color(red: 0.58, green: 0.0, blue: 1.0)    // Explicit channel values
```

System semantic colors (`Color.primary`, `Color.secondary`) are permitted only for accessibility text labels that must adapt to system appearance. They are prohibited for backgrounds, glyphs, glows, gradients, and chapter-specific visual elements.

### OLED Black Enforcement

Chapters 1 and 4 require true OLED black (`#000000`). The pixel-off state on OLED panels is achieved exclusively with absolute zero RGB.

```swift
// REJECTED — near-black approximations
Color(white: 0.05)
Color(.systemBackground)  // #1C1C1E in dark mode — NOT true black

// APPROVED — true OLED black
Color(red: 0, green: 0, blue: 0)
Color.black  // Only when confirmed #000000
```

### Gradient Constraints

Gradients MUST use chapter-defined color stops. Generic gradients are prohibited.

```swift
// REJECTED — default gradients with no chapter context
LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)

// APPROVED — chapter-specific gradient with defined stops
LinearGradient(
    stops: [
        .init(color: Color("ch2_grid_purple"), location: 0.0),
        .init(color: Color("ch2_grid_teal"), location: 0.7),
        .init(color: .black, location: 1.0)
    ],
    startPoint: .bottom,
    endPoint: .top
)
```

`MeshGradient` is permitted for atmospheric effects in Chapters 4 and 6. Control point positions and colors MUST be defined as named constants in `GameConstants`.

## Material Usage Constraints

### Prohibited Materials

The following SwiftUI material modifiers are prohibited unless a specific chapter's visual identity explicitly requires them:

```swift
// REJECTED — generic glass morphism
.background(.regularMaterial)
.background(.ultraThinMaterial)
.background(.thickMaterial)
.background(.thinMaterial)
```

### Required Material Simulation

Each chapter requiring non-flat surfaces MUST simulate its material through layered composition, not system materials.

| Chapter | Material               | Implementation Strategy                                              |
| ------- | ---------------------- | -------------------------------------------------------------------- |
| 1       | Emissive glow on black | `RadialGradient` with neon purple center fading to `#000000`         |
| 3       | Brushed metal / vault  | HEIC background (`img_bg_cipher`) with overlay shadow layers         |
| 4       | Translucent energy     | Layered circles with varying opacity, blur, and animated scale       |
| 5       | Chalk on blueprint     | Stroked paths with `StrokeStyle(lineWidth:dash:)` on HEIC background |
| 6       | Progressive color fill | Animated `trim(from:to:)` or opacity mask driven by slider progress  |

## Animation Curve Enforcement

### Default Curve Prohibition

`.easeInOut` as the sole animation curve for a chapter's primary motion is prohibited. Each chapter defines its own motion language.

**Prohibited for primary chapter animations:**

```swift
// REJECTED — generic timing for critical motion
withAnimation(.easeInOut) { ... }
withAnimation(.linear) { ... }
withAnimation(.default) { ... }
```

**Permitted usage:** `.easeInOut` is acceptable for minor UI state transitions (opacity toggles, non-focal element repositioning) that are not part of the chapter's signature motion.

### Chapter-Specific Curve Requirements

Reference [references/visual-identity-rules.md](references/visual-identity-rules.md) for complete specifications.

**Chapter 1 — Capacitor Charge:**

```swift
// Exponential ramp — aggressive ease-in for power-up feel
.timingCurve(0.0, 0.0, 0.2, 1.0, duration: GameConstants.capacitorChargeDuration)
```

**Chapter 1 — CRT Snap-On:**

```swift
// Two-phase: horizontal line expansion then vertical fill
.spring(duration: 0.15, bounce: 0)  // Phase 1: line
.easeOut(duration: 0.3)             // Phase 2: fill
```

**Chapter 3 — Cipher Wheel Detent:**

```swift
// Snap to discrete position
.snappy(duration: GameConstants.cipherWheelSnapDuration)
```

**Chapter 5 — Node Connection:**

```swift
// Path drawing with ease-out
.easeOut(duration: GameConstants.nodeConnectionDuration)
// Error snap-back with bounce
.spring(duration: 0.4, bounce: 0.3)
```

**Chapter 6 — Slider Resistance:**

```swift
// Logarithmic decay computed in gesture, not animation curve
// position = pow(fingerDistance, 0.8)
// Visual glow intensification:
.spring(duration: 0.6, bounce: 0.1)
```

### Animation Duration Constants

All animation durations MUST be named constants in `GameConstants`. Magic number durations in `withAnimation` blocks are prohibited.

```swift
// REJECTED
withAnimation(.spring(duration: 0.35)) { ... }

// APPROVED
withAnimation(.spring(duration: GameConstants.cipherWheelSnapDuration)) { ... }
```

## Composition and Layout Rules

### Prohibited Layout Patterns

The following composition patterns indicate generic AI-generated UI and are prohibited in chapter views.

**Settings-screen stack:**

```swift
// REJECTED — flat, centered, generic
VStack(spacing: 16) {
    Image(systemName: "star")
    Text("Title")
    Button("Action") { }
}
.padding(16)
```

**Uniform padding:**

```swift
// REJECTED — no spatial intention
.padding(16)  // All four edges, same value
.padding()    // System default on all edges

// APPROVED — intentional, asymmetric spacing
.padding(.horizontal, 24)
.padding(.top, 60)
.padding(.bottom, 32)
```

### Required Composition Depth

Every chapter view MUST use layered composition with a minimum depth defined in [references/visual-identity-rules.md](references/visual-identity-rules.md).

```swift
// APPROVED — layered depth composition
ZStack {
    // Layer 0: Background (HEIC image or solid OLED black)
    backgroundLayer

    // Layer 1: Atmospheric effect (glow, particles, grid)
    atmosphericLayer

    // Layer 2: Interactive content
    contentLayer

    // Layer 3: HUD / overlay (if applicable)
    overlayLayer
}
.ignoresSafeArea()
```

Single-layer flat compositions (one `VStack` or `HStack` with no depth) are prohibited for chapter views.

### Negative Space

Chapter views MUST use intentional negative space rather than uniform content distribution. Full-bleed backgrounds with focal-point composition are preferred over centered content blocks.

## Atmospheric Depth Requirements

### Parallax Layering

Chapters specifying parallax in `Design-Doc.md` (Chapter 2 starfield, Chapter 4 deep space) MUST implement multi-speed layer movement. Parallax MUST NOT be faked with a single static background.

For SwiftUI-based parallax (non-SpriteKit chapters), use `GeometryReader` with offset modifiers or `Canvas` with `TimelineView` for per-frame control.

### Particle and Lighting Simulation

Chapters with atmospheric requirements (1, 4, 6) MUST use particle or lighting simulation:

- `Canvas` + `TimelineView` for SwiftUI-native particle rendering
- Layered `RadialGradient` or `AngularGradient` for static glow effects
- `MeshGradient` with animated control points for organic atmospheric motion

Flat single-color backgrounds without atmospheric treatment are prohibited where the design doc specifies glow, energy, or particle effects.

### Depth Cue Enforcement

Multi-plane depth MUST be communicated through at least two of:

- **Scale differentiation:** Background elements smaller than foreground
- **Blur differentiation:** Background layers with `.blur(radius:)` applied
- **Opacity differentiation:** Distant layers at reduced opacity
- **Motion differentiation:** Background layers moving slower than foreground (parallax)

## Iconography and Glyph Styling

### SF Symbol Restrictions

Raw SF Symbols with default styling are prohibited for primary visual elements. Any SF Symbol used as a chapter's focal glyph MUST have:

1. Custom size via `.font(.system(size:weight:))` — minimum 60pt for focal glyphs
2. Chapter-specific color — not `.primary` or `.accentColor`
3. Animation treatment if the glyph is interactive or state-driven

```swift
// REJECTED — default SF Symbol as focal element
Image(systemName: "touchid")

// APPROVED — styled focal glyph
Image(systemName: "touchid")
    .font(.system(size: 120, weight: .ultraLight))
    .foregroundStyle(
        RadialGradient(
            colors: [Color("ch1_glow_purple"), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 80
        )
    )
    .shadow(color: Color("ch1_glow_purple").opacity(0.6), radius: 20)
```

SF Symbols used for minor UI affordances (back arrows, system indicators) retain default styling.

## Accessibility Motion Compliance

### Reduce Motion Detection

Every view with animation MUST check `UIAccessibility.isReduceMotionEnabled` and provide a fallback.

```swift
if UIAccessibility.isReduceMotionEnabled {
    withAnimation(.easeInOut(duration: GameConstants.reducedMotionFadeDuration)) {
        opacity = 1.0
    }
} else {
    withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
        scale = 1.0
        opacity = 1.0
    }
}
```

### Reduce Motion Fallback Rules

| Full Motion Effect          | Required Fallback                         |
| --------------------------- | ----------------------------------------- |
| Particle systems            | Reduce `birthRate` by 80%, halve velocity |
| `matchedGeometryEffect`     | Cross-fade transition                     |
| CRT scanline effect (Ch. 1) | Simple fade-in over 0.5s                  |
| Parallax layer movement     | Static layered composition                |
| Spring bounce animations    | `.easeInOut` with equivalent duration     |
| Continuous glow pulse       | Static glow at 70% intensity              |

Views that use `withAnimation`, `.animation()`, `.transition()`, `PhaseAnimator`, `KeyframeAnimator`, or `TimelineView` for visual motion without a Reduce Motion branch are rejected.

## Cross-Chapter Visual Isolation

### Identity Boundary Enforcement

Each chapter's visual language is self-contained. Cross-chapter style leakage is prohibited.

**Prohibited patterns:**

- Reusing Chapter 1's neon purple glow palette in Chapter 5
- Applying Chapter 3's brushed metal treatment to Chapter 6
- Sharing gradient definitions across chapters without a `GameConstants` common palette
- Using the same animation curve as another chapter's signature motion

**Enforcement:**

- Colors are namespaced per chapter in the Asset Catalog or `GameConstants`: `ch1_*`, `ch2_*`, etc.
- Animation curves are chapter-specific constants, not shared utility functions
- Material simulations are defined per chapter, not abstracted into a shared factory

### Shared Components Exception

Components in `Components/` (used by 2+ chapters) MUST be visually neutral — they accept styling parameters from the calling chapter rather than encoding their own visual identity.

## Anti-Slop Detection

The following patterns indicate generic machine-generated UI. Their presence in chapter views triggers automatic rejection.

### Structural Slop

- Centered `VStack { Image; Text; Button }` as primary layout
- Uniform `padding(16)` or `padding()` on all edges
- `RoundedRectangle(cornerRadius: 12)` as a card container without chapter context
- `ScrollView` wrapping chapter content
- `NavigationStack` or `NavigationView` in chapter views
- `List` or `Form` in game chapter UI

### Color Slop

- `Color.blue`, `Color.red`, `Color.green` as primary visual elements
- `Color.accentColor` for chapter-specific elements
- Default `.tint()` modifier without explicit color
- `LinearGradient` with two system colors and no chapter context

### Animation Slop

- `.easeInOut` as the only animation curve in a chapter
- `.animation(.default, value:)` on chapter-critical state
- Missing Reduce Motion check on any animated element
- Magic number durations not defined in `GameConstants`

### Material Slop

- `.regularMaterial` or `.ultraThinMaterial` without explicit chapter requirement
- `.shadow(radius: 10)` as generic depth simulation
- Single-layer flat composition for a chapter requiring atmospheric depth

## Post-Implementation Checklist

Before declaring any SwiftUI view implementation complete, verify:

- [ ] All colors from chapter-specific palette — no default system colors for visual elements
- [ ] OLED black (`#000000`) used where specified — no near-black substitutes
- [ ] Gradients use chapter-defined stops — no generic two-color gradients
- [ ] No `.regularMaterial` or `.ultraThinMaterial` without explicit approval
- [ ] Material simulation matches chapter specification
- [ ] Primary animations use chapter-specific curves — not `.easeInOut` alone
- [ ] All animation durations are `GameConstants` named constants
- [ ] Composition uses layered `ZStack` with minimum required depth
- [ ] No uniform `padding(16)` — spacing is intentional and asymmetric
- [ ] No `VStack { Image; Text; Button }` settings-screen pattern
- [ ] Atmospheric depth implemented where design doc specifies glow/particles/parallax
- [ ] SF Symbols styled with custom size, color, and animation for focal use
- [ ] `UIAccessibility.isReduceMotionEnabled` checked for all animated views
- [ ] Reduce Motion fallbacks exist for every motion effect
- [ ] No cross-chapter color, material, or curve reuse
- [ ] Chapter colors namespaced (`ch{N}_*`) in Asset Catalog or `GameConstants`
- [ ] No anti-slop patterns detected

## Resources

- **Visual Identity Rules**: See [references/visual-identity-rules.md](references/visual-identity-rules.md) for complete per-chapter palettes, animation curve specifications, composition depth requirements, and material simulation rules
