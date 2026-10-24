import SwiftUI

/// Shield outline shape.
struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + w, y: r.minY + h * 0.12))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.minX + w * 0.98, y: r.minY + h * 0.75))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.12), control: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.75))
        p.closeSubpath()
        return p
    }
}

/// Scales of justice drawn with Canvas.
struct ScalesView: View {
    var color: Color = Theme.gold
    var tilt: Double = 0
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2
            var pole = Path()
            pole.addRoundedRect(in: CGRect(x: cx - w * 0.025, y: h * 0.12, width: w * 0.05, height: h * 0.72), cornerSize: CGSize(width: 3, height: 3))
            pole.addRoundedRect(in: CGRect(x: cx - w * 0.22, y: h * 0.82, width: w * 0.44, height: h * 0.06), cornerSize: CGSize(width: 4, height: 4))
            pole.addEllipse(in: CGRect(x: cx - w * 0.045, y: h * 0.06, width: w * 0.09, height: w * 0.09))
            ctx.fill(pole, with: .color(color))
            let dy = h * 0.04 * tilt
            let leftY = h * 0.2 + dy, rightY = h * 0.2 - dy
            var beam = Path()
            beam.move(to: CGPoint(x: w * 0.15, y: leftY))
            beam.addLine(to: CGPoint(x: w * 0.85, y: rightY))
            ctx.stroke(beam, with: .color(color), style: StrokeStyle(lineWidth: w * 0.035, lineCap: .round))
            for (x, y) in [(w * 0.18, leftY), (w * 0.82, rightY)] {
                var str = Path()
                str.move(to: CGPoint(x: x, y: y))
                str.addLine(to: CGPoint(x: x - w * 0.12, y: y + h * 0.3))
                str.move(to: CGPoint(x: x, y: y))
                str.addLine(to: CGPoint(x: x + w * 0.12, y: y + h * 0.3))
                ctx.stroke(str, with: .color(color), lineWidth: 2)
                var pan = Path()
                pan.addArc(center: CGPoint(x: x, y: y + h * 0.3), radius: w * 0.14, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                pan.closeSubpath()
                ctx.fill(pan, with: .color(color))
            }
        }
    }
}

/// Brand emblem: shield + scales.
struct EmblemView: View {
    var size: CGFloat = 140
    var body: some View {
        ZStack {
            ShieldShape().fill(Color.white).frame(width: size, height: size * 1.15)
            ShieldShape().fill(Theme.heroGradient).frame(width: size * 0.86, height: size * 1.0)
            ScalesView().frame(width: size * 0.62, height: size * 0.62).offset(y: -size * 0.04)
        }
        .accessibilityHidden(true)
    }
}

/// Generic illustration: a soft blob background with an SF Symbol and floating accents.
struct SpotIllustration: View {
    var symbol: String
    var tint: Color = Theme.navy
    var size: CGFloat = 180
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.12)).frame(width: size, height: size)
            Circle().fill(tint.opacity(0.18)).frame(width: size * 0.7, height: size * 0.7)
            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(tint)
                .offset(y: float ? -4 : 4)
            Image(systemName: "sparkle").foregroundStyle(Theme.gold)
                .font(.system(size: size * 0.1)).offset(x: size * 0.36, y: -size * 0.32)
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green)
                .font(.system(size: size * 0.14)).offset(x: -size * 0.38, y: size * 0.28)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { float = true }
        }
    }
}

/// Animated countdown ring.
struct CountdownRing: View {
    var daysLeft: Int
    var total: Int
    var size: CGFloat = 150
    @State private var progress: Double = 0

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(daysLeft) / Double(total)))
    }
    var color: Color {
        if daysLeft < 0 { return Theme.red }
        if fraction < 0.3 { return Theme.orange }
        return Theme.green
    }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(daysLeft < 0 ? "انتهت" : "\(daysLeft)")
                    .font(.plex(daysLeft < 0 ? 26 : 40, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(color)
                Text(daysLeft < 0 ? "المهلة" : "يوم باقي")
                    .font(.hCaption).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { progress = fraction } }
    }
}
