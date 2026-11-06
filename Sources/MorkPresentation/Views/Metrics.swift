import SwiftUI

enum Metrics {
    static let listRowInsets = EdgeInsets(top: 0, leading: Spacing.s, bottom: 0, trailing: Spacing.s)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum RepositoryTab {
        static let compactMinimumWidth: CGFloat = 120
        static let compactMaximumWidth: CGFloat = 200
        static let expandedMinimumWidth: CGFloat = 240
        static let expandedMaximumWidth: CGFloat = 360
        static let titleAccessoryWidth: CGFloat = 100
    }

    enum Opacity {
        static let dimmed: Double = 0.45
        static let hint: Double = 0.85
        static let pressed: Double = 0.8
    }

    enum Line {
        static let hairline: CGFloat = 1
        static let dash: [CGFloat] = [3, 2]
    }

    enum Radius {
        static let badge: CGFloat = 3
        static let small: CGFloat = 4
        static let control: CGFloat = 6
        static let card: CGFloat = 8
        static let popover: CGFloat = 10
        static let window: CGFloat = 20
    }

    enum Row {
        static let sidebar: CGFloat = 24
        static let list: CGFloat = 24
        static let history: CGFloat = 22
        static let console: CGFloat = 22
        static let tab: CGFloat = 24
        static let quickLaunch: CGFloat = 36
        static let twoLine: CGFloat = 36
    }

    enum Indent {
        static let level: CGFloat = 12
        static let disclosure: CGFloat = 12
    }

    enum ChangeRow {
        static let leading: CGFloat = Spacing.l
        static let gap: CGFloat = 6
        static let locationColumn: CGFloat = 72
        static let minimumColumn: CGFloat = 40
        static let tableHeader: CGFloat = 24
    }

    enum Control {
        static let small: CGFloat = 22
        static let regular: CGFloat = 24
        static let searchField: CGFloat = 22
        static let picker: CGFloat = 44
        static let pickerWidth: CGFloat = 297
        static let pickerMinimumWidth: CGFloat = 260
        static let pickerFloorWidth: CGFloat = 200
        static let pickerIconOnlyMaxWidth: CGFloat = 360
        static let pickerMaxWidth: CGFloat = 480
        static let switcher: CGFloat = 28
        static let badge: CGFloat = 16
        static let focusRing: CGFloat = 3
        static let fieldGlyph: CGFloat = 11
    }

    enum HitTarget {
        static let icon: CGFloat = 24
        static let inline: CGFloat = 22
        static let toolbarWidth: CGFloat = 56
        static let toolbarCompactWidth: CGFloat = 44
        static let toolbarHeight: CGFloat = 40
        static let resizeHandle: CGFloat = 8
    }

    enum Icon {
        static let syncDot: CGFloat = 5
        static let disclosure: CGFloat = 9
        static let menuIndicator: CGFloat = 8
        static let warningBadge: CGFloat = 9
        static let tabClose: CGFloat = 9
        static let small: CGFloat = 11
        static let regular: CGFloat = 13
        static let column: CGFloat = 16
        static let toolbar: CGFloat = 16
        static let avatar: CGFloat = 32
        static let rowAvatar: CGFloat = 16
    }

    enum FontSize {
        static let display: CGFloat = 17
        static let heading: CGFloat = 15
        static let title: CGFloat = 13
        static let body: CGFloat = 12
        static let caption: CGFloat = 11
        static let label: CGFloat = 10
        static let toolbarCaption: CGFloat = caption
        static let avatarInitials: CGFloat = 8
    }

    enum LineHeight {
        static let display: CGFloat = 22
        static let heading: CGFloat = 20
        static let title: CGFloat = 17
        static let body: CGFloat = 16
        static let caption: CGFloat = 14
        static let label: CGFloat = 13
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: FontSize.display, weight: .semibold)
        static let heading = SwiftUI.Font.system(size: FontSize.heading, weight: .semibold)
        static let title = SwiftUI.Font.system(size: FontSize.title)
        static let body = SwiftUI.Font.system(size: FontSize.body)
        static let caption = SwiftUI.Font.system(size: FontSize.caption)
        static let label = SwiftUI.Font.system(size: FontSize.label, weight: .semibold)
        static let labelTracking: CGFloat = FontSize.label * 0.06
        static let monoBody = SwiftUI.Font.system(size: FontSize.body, design: .monospaced)
        static let monoCaption = SwiftUI.Font.system(size: FontSize.caption, design: .monospaced).monospacedDigit()
        static let monoBadge = SwiftUI.Font.system(size: FontSize.label, weight: .bold, design: .monospaced)
    }

    enum Sheet {
        static let padding: CGFloat = 20
        static let alertWidth: CGFloat = 420
        static let dialogWidth: CGFloat = 500
        static let dialogIconSize: CGFloat = 44
        static let dialogGlyphSize: CGFloat = 20
        static let dialogLabelWidth: CGFloat = 76
        static let commandStripHeight: CGFloat = 28
        static let commandStripInset: CGFloat = 10
        static let headerGap: CGFloat = 14
        static let labelGap = Spacing.l
        static let progressHeight: CGFloat = 6
        static let outputMaximumHeight: CGFloat = 200
        static let cloneRepositoriesHeight: CGFloat = 160
        static let cloneLogHeight: CGFloat = 110
        static let patchFilesHeight: CGFloat = 160
        static let patchErrorHeight: CGFloat = 100
        static let batchNamesHeight: CGFloat = 180
        static let ignoreEditorHeight: CGFloat = 180
        static let rowSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 16
        static let width: CGFloat = 460
        static let wideWidth: CGFloat = 560
        static let largeWidth: CGFloat = 960
        static let largeHeight: CGFloat = 680
        static let settingsWidth: CGFloat = 640
        static let commandListWidth: CGFloat = 180
        static let commandEditorHeight: CGFloat = 60
        static let scrollMinimumHeight: CGFloat = 320
        static let errorMessageHeight: CGFloat = 280
        static let logHeight: CGFloat = 140
        static let workspacesListHeight: CGFloat = 200
        static let scrollIdealHeight: CGFloat = 620
    }

    enum Settings {
        static let generalHeight: CGFloat = 560
        static let gitHeight: CGFloat = 600
        static let diffHeight: CGFloat = 320
        static let learningHeight: CGFloat = 648
        static let accountsHeight: CGFloat = 720
        static let sshHeight: CGFloat = 672
        static let integrationHeight: CGFloat = 640
        static let customCommandsHeight: CGFloat = 664
        static let windowChrome: CGFloat = 80
    }

    enum BranchName {
        static let fieldHeight: CGFloat = 20
        static let suggestionRow = Dropdown.row
        static let suggestionsMaximumHeight = Dropdown.row * 5
    }

    enum QuickLaunch {
        static let topInset = Spacing.xxl * 2
        static let bottomInset = Spacing.xxl
        static let fieldHeight = Control.searchField
        static let dividerHeight: CGFloat = 1
        static let rowHeight = Row.quickLaunch - Spacing.xxs

        static func listHeight(windowHeight: CGFloat, resultCount: Int) -> CGFloat {
            let available = max(0, windowHeight - topInset - bottomInset - fieldHeight - Spacing.m * 2 - dividerHeight)
            let visibleRows = min(CGFloat(resultCount), floor(available / rowHeight))
            return visibleRows * rowHeight
        }
    }

    enum Panel {
        static let header: CGFloat = 28
        static let tabBar: CGFloat = 28
        static let minimumHeight: CGFloat = 160
        static let maximumHeight: CGFloat = 700
        static let maximumShare: CGFloat = 0.6
        static let defaultShare: CGFloat = 0.25
        static let minimumContentHeight: CGFloat = 360
        static let consoleTabRow: CGFloat = 34
        static let consoleTab: CGFloat = 28
        static let consoleInputRow: CGFloat = 36
    }

    enum Dropdown {
        static let minimumWidth: CGFloat = 320
        static let menuMinimumWidth: CGFloat = 240
        static let gap: CGFloat = 6
        static let radius = Radius.popover
        static let row: CGFloat = 28
        static let compactRow: CGFloat = 24
        static let header: CGFloat = 24
        static let searchRow: CGFloat = 40
        static let footer: CGFloat = 36
        static let maximumShare: CGFloat = 0.6
        static let fade: TimeInterval = 0.15
        static let reopenDelay: TimeInterval = 0.25
        static let checkColumn: CGFloat = 16
        static let titleColumn: CGFloat = 48
        static let dot: CGFloat = 10
    }

    enum Inspector {
        static let minimumWidth: CGFloat = 900
        static let idealWidth: CGFloat = 1100
        static let minimumHeight: CGFloat = 560
        static let idealHeight: CGFloat = 720
        static let listMinimumWidth: CGFloat = 260
        static let listIdealWidth: CGFloat = 340
        static let listMaximumWidth: CGFloat = 560
        static let contentMinimumWidth: CGFloat = 400
    }

    enum HistoryPane {
        static let listIdealHeight: CGFloat = 300
        static let listShare: CGFloat = 0.5
        static let listMinimumHeight: CGFloat = 120
        static let listMaximumHeight: CGFloat = 900
        static let detailsFrameMinimumHeight: CGFloat = 160
        static let browserMinimumHeight: CGFloat = 300
    }

    enum Shadow {
        static let keyRadius: CGFloat = 12
        static let keyY: CGFloat = 8
        static let keyOpacity: Double = 0.14
        static let ambientRadius: CGFloat = 1
        static let ambientY: CGFloat = 1
        static let ambientOpacity: Double = 0.08
    }

    enum Changes {
        static let minimumHeight: CGFloat = 260
        static let listMinimumWidth: CGFloat = 280
        static let listIdealWidth: CGFloat = 420
        static let listMaximumWidth: CGFloat = 640
        static let detailMinimumWidth: CGFloat = 360
    }

    enum Graph {
        static let laneSpacing: CGFloat = 14
        static let lineWidth: CGFloat = 2
        static let dotRadius: CGFloat = 3
        static let ringRadius: CGFloat = 5.25
        static let ringLineWidth: CGFloat = 1.5
        static let chevronHalfHeight: CGFloat = 2.25
        static let chevronWidth: CGFloat = 2.5
    }

    enum Badge {
        static let iconFont: CGFloat = 8.5
        static let iconCellWidth: CGFloat = 16
        static let borderWidth: CGFloat = 1
        static let padding: CGFloat = 5
        static let height: CGFloat = 18
    }

    enum EmptyState {
        static let glyph: CGFloat = 20
        static let messageWidth: CGFloat = 280
    }

    enum Composer {
        static let descriptionHeight: CGFloat = 72
    }

    enum Blame {
        static let gutterWidth: CGFloat = 260
        static let rowHeight: CGFloat = 18
        static let numberWidth: CGFloat = 44
    }

    enum Bisect {
        static let logMinimumHeight: CGFloat = 200
    }

    enum Manager {
        static let appIcon: CGFloat = 96
        static let readmeWidth: CGFloat = 760
        static let quoteBar: CGFloat = 3
        static let statusDot: CGFloat = 6
    }

    enum Lesson {
        static let listWidth: CGFloat = 200
        static let flagColumnWidth: CGFloat = 140
        static let browserHeight: CGFloat = 360
        static let sheetBrowserHeight: CGFloat = 480
        static let cardWidth: CGFloat = 150
        static let cardHeight: CGFloat = 124
    }

    enum Reflog {
        static let selectorWidth: CGFloat = 70
    }

    enum TextLayout {
        static let fallbackWidth: CGFloat = 600
    }

    enum Treemap {
        static let labelMinimumWidth: CGFloat = 56
        static let labelMinimumHeight: CGFloat = 16
        static let labelLimit = 400
        static let highlightWidth: CGFloat = 2
        static let folderFillOpacity: Double = 0.12
        static let folderStrokeOpacity: Double = 0.25
        static let fileFillOpacity: Double = 0.45
        static let depthOpacityStep: Double = 0.1
        static let maximumShadedDepth = 3
        static let fileInset: CGFloat = 0.5
        static let hoverOpacity: Double = 0.8
        static let labelFontSize: CGFloat = FontSize.caption - 1
    }

    enum Statistics {
        static let width: CGFloat = 760
        static let height: CGFloat = 620
        static let commitsColumn: CGFloat = 100
        static let mergesColumn: CGFloat = 80
        static let datesColumn: CGFloat = 190
        static let chartHeight: CGFloat = 170
        static let heatmapCellWidth: CGFloat = 20
        static let heatmapCellHeight: CGFloat = 16
        static let heatmapHourStep = 3
        static let heatmapAxisFont: CGFloat = 9
        static let heatmapMinimumOpacity: Double = 0.2
        static let fileBarWidth: CGFloat = 120
        static let fileBarHeight: CGFloat = 6
        static let fileBarOpacity: Double = 0.6
        static let fileCountColumn: CGFloat = 90
    }

    enum Benchmark {
        static let numberColumn: CGFloat = 84
    }

    enum Rebase {
        static let stepsMinimumHeight: CGFloat = 160
        static let stepsIdealHeight: CGFloat = 300
        static let detailsMinimumHeight: CGFloat = 160
        static let dot: CGFloat = 8
        static let actionColumn: CGFloat = 110
        static let menuWidth: CGFloat = 490
        static let rowHeight: CGFloat = 24
        static let meldColumn: CGFloat = 28
        static let meldLine: CGFloat = 1.5
        static let meldDot: CGFloat = 5
        static let meldCurve: CGFloat = 6
        static let meldArrowHead: CGFloat = 4
        static let authorColumn: CGFloat = 150
        static let hashColumn: CGFloat = 64
        static let dateColumn: CGFloat = 150
        static let minimumWidth: CGFloat = 860
        static let minimumHeight: CGFloat = 600
        static let idealHeight: CGFloat = 720
        static let meldLineFraction: CGFloat = 0.3
        static let meldArrowLength: CGFloat = 1.5
        static let descriptionHeight: CGFloat = 160
    }

    enum CommitDetails {
        static let filesAboveMinimumHeight: CGFloat = 80
        static let filesAboveIdealHeight: CGFloat = 160
        static let filesAboveMaximumHeight: CGFloat = 600
        static let diffBelowMinimumHeight: CGFloat = 120
        static let tabBarHeight: CGFloat = 32
        static let tabHeight: CGFloat = 24
        static let labelColumnWidth: CGFloat = 76
        static let columnGap: CGFloat = 16
        static let rowInset: CGFloat = 20
        static let authorAvatar: CGFloat = 44
        static let authorRowHeight: CGFloat = 76
        static let fieldRowHeight: CGFloat = 20
        static let refsRowHeight: CGFloat = 24
        static let filesHeaderHeight: CGFloat = 22
        static let fileFont: CGFloat = FontSize.title
        static let messageSpacing: CGFloat = 14
        static let inlineLineHeight: CGFloat = 18
        static let inlineNumberWidth: CGFloat = 36
        static let summaryBarHeight: CGFloat = 28
        static let filterRowHeight: CGFloat = 28
        static let diffHeaderHeight: CGFloat = 28
        static let filesPaneMinimumWidth: CGFloat = 200
        static let filesPaneIdealWidth: CGFloat = 340
        static let filesPaneMaximumWidth: CGFloat = 640
        static let diffMinimumWidth: CGFloat = 320
    }

    enum TagSheet {
        static let messageHeight: CGFloat = 72
    }

    enum FilePreview {
        static let windowShare: CGFloat = 0.6
        static let minimumWidth: CGFloat = 640
        static let minimumHeight: CGFloat = 400
        static let numberPadding: CGFloat = 10
        static let hatchSpacing: CGFloat = 6
        static let sidePadding: CGFloat = 24
    }

    enum Diff {
        static let hoverOutline: CGFloat = 2
        static let hoverInset: CGFloat = 6
        static let rowHeight: CGFloat = 20
        static let hunkRow: CGFloat = 28
        static let numberPadding: CGFloat = 10
        static let numberGap: CGFloat = 4
        static let textInset: CGFloat = 8
        static let textPadding: CGFloat = 2
        static let columnSlack: CGFloat = 40
        static let selectionBar: CGFloat = 3
        static let selectionOpacity: Double = 0.2
        static let minimumCardWidth: CGFloat = 320
    }

    enum Conflict {
        static let lineHeight: CGFloat = 16
        static let lineSpacing: CGFloat = 2
        static let border: CGFloat = 1
        static let sideMaximumHeight: CGFloat = 220
        static let sideMinimumWidth: CGFloat = 220
        static let lessonWidth: CGFloat = 440
        static let blocksHeight: CGFloat = 260
        static let blocksShare: CGFloat = 0.55
        static let blocksMinimumHeight: CGFloat = 120
        static let blocksMaximumHeight: CGFloat = 900
        static let resultMinimumLines: CGFloat = 6
        static let resultMinimumHeight: CGFloat = lineHeight * resultMinimumLines + Spacing.xs * 2
        static let footerHeight: CGFloat = Panel.header + Spacing.s
        static let commitStripHeight: CGFloat = Panel.header
        static let legendSwatch: CGFloat = 10
        static let gutterMinimumDigits = 3
        static let accentBar: CGFloat = 3
        static let windowShare: CGFloat = 0.85
        static let windowMinimumWidth: CGFloat = 900
        static let windowMinimumHeight: CGFloat = 600
    }

    enum DropTarget {
        static let inset = Spacing.s
        static let border: CGFloat = 2
        static let dash: [CGFloat] = [8, 4]
        static let fillOpacity: Double = 0.9
    }

    enum ImageDiff {
        static let checker: CGFloat = 8
        static let handle: CGFloat = 2
        static let sliderWidth: CGFloat = 240
    }

    enum Window {
        static let parkedOffset: CGFloat = 100_000
        static let minimumWidth: CGFloat = 900
        static let minimumDetailWidth: CGFloat = 680
        static let sidebarAutoHideWidth: CGFloat = 1150
    }

    enum Sidebar {
        static let windowInset: CGFloat = 8
        static let windowRadius = Radius.window
        static let windowBorder: CGFloat = 1
        static let windowControlsLeading: CGFloat = 20
        static let listInset: CGFloat = 16
        static let selectionInset: CGFloat = 10
        static let contentInset: CGFloat = 12
        static let iconColumn: CGFloat = 22
        static let destinationRow: CGFloat = 30
        static let destinationIcon: CGFloat = 16
        static let repositoryTile: CGFloat = 32
        static let repositoryTileGap: CGFloat = 10
        static let segmentWidth: CGFloat = 28
        static let segmentHeight: CGFloat = 24
        static let switcherSpacing: CGFloat = 12
        static let switcherHeight: CGFloat = 32
        static let filterHeight: CGFloat = 22
        static let minimumWidth: CGFloat = 200
        static let idealWidth: CGFloat = 260
        static let maximumWidth: CGFloat = 400
        static let dropTargetBorder: CGFloat = 2
    }

    enum Toolbar {
        static let margin: CGFloat = 8
        static let spacing: CGFloat = 4
        static let separatorHeight: CGFloat = 14
        static let itemHeight: CGFloat = 40
        static let bandHeight: CGFloat = 52
        static let badgeOverlap: CGFloat = 2
        static let badgeRise: CGFloat = 4
        static let iconOnlyWidth: CGFloat = 32
        static let iconOnlyIcon: CGFloat = 17
        static let groupSpacing: CGFloat = 12
        static let iconOnlySeparatorHeight: CGFloat = 18
        static let iconOnlySeparatorPadding: CGFloat = 6
        static let trafficLightsWidth: CGFloat = 81
        static let captionMaxWidth: CGFloat = 96
        static let captionIcon: CGFloat = 15
        static let glyphHeight: CGFloat = Icon.toolbar + Spacing.xs
        static let splitMainWidth: CGFloat = iconOnlyWidth - Spacing.xs
        static let splitMenuWidth: CGFloat = Spacing.l
        static let splitDividerHeight: CGFloat = glyphHeight - Spacing.xs
    }
}
