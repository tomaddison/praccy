import SwiftUI

/// Celebratory particle burst. Caller owns the trigger; completion reported via `onFinish`.
struct ConfettiBurst: View {
    var particleCount: Int = 14
    var duration: Double = 1.1
    var accent: Color
    var onFinish: (() -> Void)? = nil

    @State private var progress: CGFloat = 0
    @State private var specs: [ParticleSpec] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                if !reduceMotion {
                    ForEach(specs.indices, id: \.self) { i in
                        let spec = specs[i]
                        particleShape(spec: spec)
                            .position(x: centre.x, y: centre.y)
                            .modifier(ConfettiParticleEffect(
                                progress: progress,
                                peakY: spec.peakY,
                                endX: spec.endX,
                                endY: spec.endY,
                                totalRotation: spec.rotation
                            ))
                    }
                }
            }
        }
        .onAppear {
            if specs.isEmpty {
                specs = Self.generateSpecs(count: particleCount, accent: accent)
            }
            if reduceMotion {
                DispatchQueue.main.async { onFinish?() }
                return
            }
            withAnimation(.linear(duration: duration)) {
                progress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                onFinish?()
            }
        }
    }

    @ViewBuilder
    private func particleShape(spec: ParticleSpec) -> some View {
        if spec.isCircle {
            Circle().fill(spec.color).frame(width: 7, height: 7)
        } else {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(spec.color)
                .frame(width: 5, height: 10)
        }
    }

    private static func generateSpecs(count: Int, accent: Color) -> [ParticleSpec] {
        let palette: [Color] = [
            accent,
            PraccyColor.cheek,
            Color(hex: 0xE8A44C), // warm amber
            Color(hex: 0x7FB069), // sage
            PraccyColor.ink
        ]
        return (0..<count).map { i in
            let fraction = Double(i) / Double(max(1, count - 1))
            let spread = (fraction - 0.5) * (Double.pi * 2.0 / 3.0)
            let jitter = Double.random(in: -0.2...0.2)
            let angle = -Double.pi / 2 + spread + jitter

            let launchDistance = Double.random(in: 55...90)
            let peakY = CGFloat(sin(angle) * launchDistance)
            let endX = CGFloat(cos(angle) * launchDistance) * 1.3
            let endY = abs(peakY) + CGFloat(Double.random(in: 50...110))

            return ParticleSpec(
                peakY: peakY,
                endX: endX,
                endY: endY,
                rotation: Double.random(in: 270...540),
                color: palette[i % palette.count],
                isCircle: i % 3 == 0
            )
        }
    }
}

private struct ParticleSpec {
    let peakY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let rotation: Double
    let color: Color
    let isCircle: Bool
}

/// Ballistic particle: linear X, quadratic Y through (0,0), (apex, peakY), (1, endY).
private struct ConfettiParticleEffect: ViewModifier, Animatable {
    var progress: CGFloat
    let peakY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let totalRotation: Double

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private static let apex: CGFloat = 0.3

    private var parabolaA: CGFloat {
        (peakY - endY * Self.apex) / (Self.apex * (Self.apex - 1))
    }

    private var currentX: CGFloat { endX * progress }

    private var currentY: CGFloat {
        let a = parabolaA
        let b = endY - a
        return a * progress * progress + b * progress
    }

    private var currentRotation: Double { totalRotation * Double(progress) }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(currentRotation))
            .offset(x: currentX, y: currentY)
    }
}

#Preview {
    struct Demo: View {
        @State private var playing = true
        var body: some View {
            ZStack {
                AccentPalette.violet.bg.ignoresSafeArea()
                VStack(spacing: 20) {
                    Button("Play") { playing = true }
                        .buttonStyle(.borderedProminent)
                    ZStack {
                        RoundedRectangle(cornerRadius: PraccyRadius.card)
                            .fill(AccentPalette.violet.accent)
                            .frame(width: 260, height: 160)
                        if playing {
                            ConfettiBurst(accent: AccentPalette.violet.accent) {
                                playing = false
                            }
                            .frame(width: 260, height: 160)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }
    return Demo()
}
