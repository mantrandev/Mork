import MorkDomain
import SwiftUI

enum CommitGraphGeometry {
    static let laneSpacing = Metrics.Graph.laneSpacing
    static let lineWidth = Metrics.Graph.lineWidth
    static let dotRadius = Metrics.Graph.dotRadius
    static let ringRadius = Metrics.Graph.ringRadius
    static let ringLineWidth = Metrics.Graph.ringLineWidth
    private static let arcControl: CGFloat = 4 * (2.squareRoot() - 1) / 3

    struct Segment: Equatable {
        let start: CGPoint
        let end: CGPoint
        let lane: Int
        let half: GraphEdge.Half

        var changesLane: Bool { start.x != end.x }
    }

    enum NodeStyle: Equatable {
        case dot
        case ring
        case headDot
        case headRing

        init(isMerge: Bool, isHead: Bool) {
            switch (isMerge, isHead) {
            case (false, false): self = .dot
            case (true, false): self = .ring
            case (false, true): self = .headDot
            case (true, true): self = .headRing
            }
        }
    }

    static func x(_ lane: Int) -> CGFloat {
        (CGFloat(lane) + 0.5) * laneSpacing
    }

    static func width(of row: GraphRow) -> CGFloat {
        CGFloat(row.width) * laneSpacing
    }

    static func node(of row: GraphRow, height: CGFloat) -> CGPoint {
        CGPoint(x: x(row.column), y: height / 2)
    }

    static func segments(of row: GraphRow, height: CGFloat) -> [Segment] {
        let middle = height / 2
        return row.edges.map { edge in
            switch edge.half {
            case .top:
                Segment(start: CGPoint(x: x(edge.from), y: 0), end: CGPoint(x: x(edge.to), y: middle), lane: edge.from, half: .top)
            case .bottom:
                Segment(start: CGPoint(x: x(edge.from), y: middle), end: CGPoint(x: x(edge.to), y: height), lane: edge.to, half: .bottom)
            }
        }
    }

    static func cornerRadius(of segment: Segment) -> CGFloat {
        min(abs(segment.end.y - segment.start.y), abs(segment.end.x - segment.start.x))
    }

    static func path(of segment: Segment) -> Path {
        var path = Path()
        path.move(to: segment.start)
        guard segment.changesLane else {
            path.addLine(to: segment.end)
            return path
        }
        let radius = cornerRadius(of: segment)
        let direction: CGFloat = segment.end.x > segment.start.x ? 1 : -1
        let pull = radius * arcControl
        switch segment.half {
        case .top:
            let bend = CGPoint(x: segment.start.x, y: segment.end.y - radius)
            let corner = CGPoint(x: segment.start.x + direction * radius, y: segment.end.y)
            if bend != segment.start { path.addLine(to: bend) }
            path.addCurve(
                to: corner,
                control1: CGPoint(x: bend.x, y: bend.y + pull),
                control2: CGPoint(x: corner.x - direction * pull, y: corner.y)
            )
            if corner != segment.end { path.addLine(to: segment.end) }
        case .bottom:
            let corner = CGPoint(x: segment.end.x - direction * radius, y: segment.start.y)
            let bend = CGPoint(x: segment.end.x, y: segment.start.y + radius)
            if corner != segment.start { path.addLine(to: corner) }
            path.addCurve(
                to: bend,
                control1: CGPoint(x: corner.x + direction * pull, y: corner.y),
                control2: CGPoint(x: bend.x, y: bend.y - pull)
            )
            if bend != segment.end { path.addLine(to: segment.end) }
        }
        return path
    }

    static func chevron(at center: CGPoint) -> [CGPoint] {
        let half = Metrics.Graph.chevronWidth / 2
        let height = Metrics.Graph.chevronHalfHeight
        return [
            CGPoint(x: center.x - half, y: center.y - height),
            CGPoint(x: center.x + half, y: center.y),
            CGPoint(x: center.x - half, y: center.y + height)
        ]
    }

    static func circle(at center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func color(_ lane: Int) -> Color {
        CommitGraphPalette.color(lane)
    }
}

struct CommitGraphView: View, Equatable {
    let row: GraphRow
    let isHead: Bool

    private typealias Geometry = CommitGraphGeometry

    var body: some View {
        Canvas { context, size in
            let center = Geometry.node(of: row, height: size.height)
            let node = Geometry.NodeStyle(isMerge: row.commit.isMerge, isHead: isHead)
            var lines = context
            if node != .dot {
                var mask = Path(CGRect(origin: .zero, size: size))
                mask.addPath(Geometry.circle(at: center, radius: Geometry.ringRadius))
                lines.clip(to: mask, style: FillStyle(eoFill: true))
            }
            let style = StrokeStyle(lineWidth: Geometry.lineWidth, lineCap: .butt)
            for segment in Geometry.segments(of: row, height: size.height) {
                lines.stroke(Geometry.path(of: segment), with: .color(Geometry.color(segment.lane)), style: style)
            }
            let color = Geometry.color(row.column)
            let ring = Geometry.circle(at: center, radius: Geometry.ringRadius)
            let mark = StrokeStyle(lineWidth: Geometry.ringLineWidth, lineCap: .round, lineJoin: .round)
            switch node {
            case .dot:
                context.fill(Geometry.circle(at: center, radius: Geometry.dotRadius), with: .color(color))
            case .ring:
                context.stroke(ring, with: .color(color), style: mark)
                context.stroke(Path { $0.addLines(Geometry.chevron(at: center)) }, with: .color(color), style: mark)
            case .headDot:
                context.stroke(ring, with: .color(color), style: mark)
                context.fill(Geometry.circle(at: center, radius: Geometry.dotRadius - Geometry.ringLineWidth / 2), with: .color(color))
            case .headRing:
                context.fill(Geometry.circle(at: center, radius: Geometry.ringRadius + Geometry.ringLineWidth / 2), with: .color(color))
                context.stroke(Path { $0.addLines(Geometry.chevron(at: center)) }, with: .color(Palette.Surface.window.color), style: mark)
            }
        }
        .frame(width: Geometry.width(of: row))
        .accessibilityHidden(true)
    }
}
