# Visual Identity Rules

Chapter-specific visual language, color palettes, material definitions, animation curves, and composition constraints derived from `Design-Doc.md`.

## Chapter Color Palettes

### Chapter 1: Handshake

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Background           | `#000000`             | True OLED black. No near-black substitutes.       |
| Fingerprint glyph    | Neon purple glow      | Pulsing opacity cycle. Not a static tint.         |
| CRT power-on         | White bloom → content | Scanline simulation. Not a simple fade.           |

### Chapter 2: Packet Run

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Grid floor           | Neon purple + teal    | Synthwave 80s aesthetic. Parallax scroll.         |
| Starfield sky        | Deep purple base      | Multi-layer parallax. Not a static image.         |
| Obstacles            | Glitch red            | Pixelated edge treatment. Not solid geometry.     |
| Collectibles         | Glowing pink          | Pulse animation. Not static sprite.               |

### Chapter 3: Cipher

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Background           | Brushed steel/vault   | Macro photography aesthetic. Not flat gray.       |
| Tumbler numbers      | Glowing blue          | Cinematic dramatic lighting. Not system blue.     |
| Wheel segments       | SF Mono typeface      | Monospaced alignment. Not proportional font.      |
| Correct segment glow | Subtle warm glow      | Auto-Assist indicator. Not a highlight rectangle. |

### Chapter 4: Firewall

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Shield sphere        | Translucent energy    | Glowing, not opaque. Animated surface.            |
| Deep space           | True black `#000000`  | OLED black. Stars as point lights.                |
| Noise particles      | Aggressive red        | Spiky geometry. Not circular particles.           |

### Chapter 5: Blueprint

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Background           | Deep royal blue       | Architectural blueprint paper. Not system blue.   |
| Grid lines           | White chalk           | Faint, technical aesthetic. Not solid white.      |
| Nodes                | White with glow       | Cornerstone nodes have labels. Structural do not. |
| Connection lines     | White chalk stroke    | Path-drawn. Not solid rectangles.                 |

### Chapter 6: Event Horizon

| Element              | Value                 | Notes                                             |
| -------------------- | --------------------- | ------------------------------------------------- |
| Initial state        | White void            | Pure `#FFFFFF`. Slowly fills with color.          |
| Slider track         | Progressive reveal    | Logarithmic resistance visual feedback.           |
| Finale art           | Golden hour lighting  | Revealed after slider completion. Cross-fade in.  |
| Confetti             | Multi-color particles | Celebratory. Not uniform color.                   |

## Animation Curve Specifications

### Chapter 1: Capacitor Charge

- **Curve type:** Exponential intensity ramp
- **Implementation:** Custom `Animation` using `.timingCurve(0.0, 0.0, 0.2, 1.0)` for aggressive ease-in
- **Duration:** 3.0 seconds (matches long-press minimum)
- **Haptic sync:** Intensity increases from 0.1 to 1.0 along the same exponential curve
- **Reduce Motion fallback:** Linear opacity fade from 0.3 to 1.0

### Chapter 1: CRT Power-On

- **Curve type:** Snap-on with scanline simulation
- **Implementation:** Two-phase — horizontal line expansion (0.15s, `.spring(duration: 0.15, bounce: 0)`) then vertical fill (0.3s, `.easeOut`)
- **Reduce Motion fallback:** Simple cross-fade over 0.5s

### Chapter 3: Cipher Wheel Scroll

- **Curve type:** `.snappy(duration: 0.25)` for detent snap
- **Implementation:** Spring-based snap to discrete positions
- **Haptic sync:** Click haptic at each detent position

### Chapter 5: Node Connection

- **Curve type:** Path stroke animation via `trim(from:to:)`
- **Implementation:** `.easeOut` with 0.3s duration per segment
- **Error snap-back:** `.spring(duration: 0.4, bounce: 0.3)` for incorrect connections

### Chapter 6: Progressive Resistance Slider

- **Curve type:** Logarithmic decay — `position = fingerDistance ^ 0.8`
- **Implementation:** Computed in `DragGesture.onChanged`, not via animation curve
- **Visual feedback:** Slider handle gains glow intensity as progress increases
- **Reduce Motion fallback:** Remove glow pulse; retain position feedback

## Composition Constraints

### Depth Layering Requirements

| Chapter | Layer Count | Layer Composition                                          |
| ------- | ----------- | ---------------------------------------------------------- |
| 1       | 3           | OLED black → glow halo → fingerprint glyph                |
| 2       | 4+          | Starfield → mid-stars → grid floor → game entities        |
| 3       | 3           | Vault background → shadow overlay → cryptex interface     |
| 4       | 4+          | Deep space → distant particles → shield sphere → UI       |
| 5       | 3           | Blueprint background → grid lines → nodes + connections   |
| 6       | 4           | White void → color fill → finale art → confetti overlay   |

### Prohibited Composition Patterns

- `VStack { Image(_); Text(_); Button(_) }` — generic settings-screen layout
- Uniform `padding(16)` on all edges — indicates no spatial intent
- Centered single-column stacks without depth layers
- `ScrollView` wrapping chapter content — chapters are fixed-viewport
- `NavigationStack` or `NavigationView` — chapter navigation is coordinator-driven

## Material Simulation Rules

| Chapter | Required Material Effect            | Prohibited Shortcuts                     |
| ------- | ----------------------------------- | ---------------------------------------- |
| 1       | OLED-black with emissive glow layer | `.background(.black)` without glow layer |
| 3       | Brushed metal / glass texture       | `.regularMaterial`, `.ultraThinMaterial`  |
| 4       | Translucent energy sphere surface   | Solid circle with opacity                |
| 5       | Chalk line rendering on blueprint   | Solid `.white` strokes without texture   |
| 6       | Progressive color saturation fill   | Static gradient swap on completion       |

## SF Symbol Styling Rules

| Usage Context          | Symbol Name   | Required Treatment                                                   |
| ---------------------- | ------------- | -------------------------------------------------------------------- |
| Ch. 1 fingerprint      | `touchid`     | Custom size (120pt+), pulsing glow animation, neon purple tint       |
| Any decorative context | Any SF Symbol | Custom `.font(.system(size:weight:))`, chapter-appropriate color     |

Raw SF Symbols with default styling are prohibited for primary visual elements. Default `.font(.body)` sizing on glyphs used as focal elements is a visual fidelity violation.
