import SwiftUI

private enum Constellation {
    static let artboard: CGFloat = 824
    static let center: CGFloat = 512
    static let line = [
        CGPoint(x: 262, y: 760),
        CGPoint(x: 322, y: 300),
        CGPoint(x: 512, y: 590),
        CGPoint(x: 702, y: 300),
        CGPoint(x: 762, y: 760)
    ]
    static let head = CGPoint(x: 702, y: 300)
    static let stars = line.filter { $0 != head }

    static func position(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        let scale = min(rect.width, rect.height) / artboard
        return CGPoint(x: rect.midX + (point.x - center) * scale, y: rect.midY + (point.y - center) * scale)
    }
}

private struct ConstellationLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(Constellation.line.map { Constellation.position($0, in: rect) })
        return path
    }
}

private struct ConstellationStars: Shape {
    let centers: [CGPoint]
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let scaled = radius * min(rect.width, rect.height) / Constellation.artboard
        var path = Path()
        for center in centers {
            let position = Constellation.position(center, in: rect)
            path.addEllipse(in: CGRect(x: position.x - scaled, y: position.y - scaled, width: scaled * 2, height: scaled * 2))
        }
        return path
    }
}

struct AppIconTile: View {
    var size: CGFloat = 96

    private static let night = [Color(red: 0.114, green: 0.153, blue: 0.251), Color(red: 0.027, green: 0.039, blue: 0.071)]
    private static let lineColor = Color(red: 0.561, green: 0.639, blue: 0.800)
    private static let starColor = Color(red: 0.894, green: 0.914, blue: 0.957)
    private static let headColor = Color(red: 0.239, green: 0.839, blue: 0.659)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: Self.night, startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.02)
            ConstellationLine()
                .stroke(Self.lineColor, style: StrokeStyle(lineWidth: size * 40 / Constellation.artboard, lineCap: .round, lineJoin: .round))
            ConstellationStars(centers: Constellation.stars, radius: 58)
                .fill(Self.starColor)
            ConstellationStars(centers: [Constellation.head], radius: 112)
                .fill(Self.headColor.opacity(0.22))
            ConstellationStars(centers: [Constellation.head], radius: 72)
                .fill(Self.headColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
