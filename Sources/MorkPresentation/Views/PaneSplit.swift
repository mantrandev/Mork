import AppKit
import SwiftUI

enum PaneSplitKey {
    static let sidebarWidth = "sidebar.width"
    static let changesFilesWidth = "commitDetails.filesWidth"
    static let changesFilesHeight = "commitDetails.filesHeight"
    static let inspectorListWidth = "inspector.listWidth"
    static let changesListWidth = "changes.listWidth"
    static let rebaseStepsHeight = "rebase.stepsHeight"
    static let rebaseChangesFilesWidth = "rebase.changesFilesWidth"
}

enum PaneSplitAxis {
    case horizontal
    case vertical
}

struct PaneSplit<Side: View, Main: View>: View {
    let axis: PaneSplitAxis
    @AppStorage private var size: Double
    @State private var dragSize: Double?
    let range: ClosedRange<CGFloat>
    let mainMinimum: CGFloat
    let identifier: String
    let isSideVisible: Bool
    let side: Side
    let main: Main

    init(
        _ axis: PaneSplitAxis,
        key: String,
        defaultSize: CGFloat,
        range: ClosedRange<CGFloat>,
        mainMinimum: CGFloat,
        identifier: String,
        isSideVisible: Bool = true,
        @ViewBuilder side: () -> Side,
        @ViewBuilder main: () -> Main
    ) {
        self.axis = axis
        _size = AppStorage(wrappedValue: Double(defaultSize), key)
        self.range = range
        self.mainMinimum = mainMinimum
        self.identifier = identifier
        self.isSideVisible = isSideVisible
        self.side = side()
        self.main = main()
    }

    var body: some View {
        GeometryReader { proxy in
            let total = axis == .horizontal ? proxy.size.width : proxy.size.height
            let maximum = total - mainMinimum
            let length = PaneSplitLength.clamped(CGFloat(dragSize ?? size), range: range, available: maximum)
            let handle = PaneSplitHandle(axis: axis, size: size, dragSize: $dragSize, range: range, maximum: maximum, identifier: identifier) { size = $0 }
            switch axis {
            case .horizontal:
                HStack(spacing: 0) {
                    side.frame(width: length).frame(maxHeight: .infinity)
                        .offset(x: isSideVisible ? 0 : -length)
                        .frame(width: isSideVisible ? length : 0, alignment: .leading)
                        .allowsHitTesting(isSideVisible)
                        .accessibilityHidden(!isSideVisible)
                    handle
                        .frame(width: isSideVisible ? nil : 0)
                        .clipped()
                        .allowsHitTesting(isSideVisible)
                        .accessibilityHidden(!isSideVisible)
                    main.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .vertical:
                VStack(spacing: 0) {
                    if isSideVisible {
                        side.frame(height: length).frame(maxWidth: .infinity)
                        handle
                    }
                    main.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

enum PaneSplitLength {
    static func clamped(_ size: CGFloat, range: ClosedRange<CGFloat>, available: CGFloat) -> CGFloat {
        let upper = max(range.lowerBound, min(range.upperBound, available))
        return min(max(size, range.lowerBound), upper)
    }
}

private struct PaneSplitHandle: View {
    let axis: PaneSplitAxis
    let size: Double
    @Binding var dragSize: Double?
    let range: ClosedRange<CGFloat>
    let maximum: CGFloat
    let identifier: String
    let commit: (Double) -> Void
    @State private var start: CGFloat?

    var body: some View {
        Hairline(isVertical: axis == .horizontal)
            .overlay {
                Color.clear
                    .frame(
                        width: axis == .horizontal ? Metrics.HitTarget.resizeHandle : nil,
                        height: axis == .vertical ? Metrics.HitTarget.resizeHandle : nil
                    )
                    .contentShape(Rectangle())
                    .onHover { inside in
                        let cursor: NSCursor = axis == .horizontal ? .resizeLeftRight : .resizeUpDown
                        if inside { cursor.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let origin = start ?? CGFloat(size)
                                start = origin
                                let delta = axis == .horizontal ? value.translation.width : value.translation.height
                                dragSize = Double(PaneSplitLength.clamped(origin + delta, range: range, available: maximum))
                            }
                            .onEnded { _ in
                                if let dragSize { commit(dragSize) }
                                dragSize = nil
                                start = nil
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Resize")
                    .accessibilityIdentifier(identifier)
            }
    }
}
