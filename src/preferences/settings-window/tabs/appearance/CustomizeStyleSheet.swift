import Cocoa

class CustomizeStyleSheet: SheetWindow {
    // Local labels (rows owned by this sheet). The Show/Hide rows below are sourced from
    // `ShowHideIllustratedView`'s static constants so each NSLocalizedString call lives in
    // exactly one place across the codebase.
    private static let labelShowTitles = NSLocalizedString("Show titles", comment: "")
    private static let labelTitleTruncation = NSLocalizedString("Title truncation", comment: "")

    private static let labelAppNameAlignment = NSLocalizedString("Right-align app names", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        labelShowTitles,
        labelTitleTruncation,
        labelAppNameAlignment,
        ShowHideIllustratedView.hideStatusIconsLabel,
        ShowHideIllustratedView.hideStatusIconsSubtitle,
        ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
        ShowHideIllustratedView.hideColoredCirclesLabel,
        IllustratedImageThemeView.placeholderLabelText,
    ] + ShowTitlesPreference.allCases.map { $0.localizedString }
      + TitleTruncationPreference.allCases.map { $0.localizedString }

    static let illustratedImageWidth = width

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!

    override func makeContentView() -> NSView {
        // The per-shortcut Customize sheet was trimmed to just style-tied global toggles. The
        // settings that used to live here either (a) moved to per-shortcut storage and now live
        // in `ControlsTab` (`showAppsOrWindows`, `showTabsAsWindows`) or (b) were dropped
        // entirely (`alignThumbnails`). The "Show & Hide" / "Advanced" tab control is gone too —
        // the remaining rows fit comfortably in one flat list.
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        showHideIllustratedView = ShowHideIllustratedView(style, illustratedImageView)
        let showHideView = showHideIllustratedView.makeView()
        let advancedTable = TableGroupView(width: CustomizeStyleSheet.width)
        let showTitles = TableGroupView.Row(leftTitle: Self.labelShowTitles,
            rightViews: [LabelAndControl.makeDropdown(
                "showTitles", ShowTitlesPreference.allCases, extraAction: { [weak self] _ in
                    self?.showTitlesIllustratedImage()
                })])
        advancedTable.addRow(showTitles, onMouseEntered: { [weak self] _, _ in
            self?.showTitlesIllustratedImage()
        })
        let titleTruncation = TableGroupView.Row(leftTitle: Self.labelTitleTruncation,
            rightViews: LabelAndControl.makeRadioButtons("titleTruncation", TitleTruncationPreference.allCases))
        advancedTable.addRow(titleTruncation)
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.identifier = NSUserInterfaceItemIdentifier("localAppNameTrailingAlignment")
        checkbox.state = UserDefaults.standard.bool(forKey: "localAppNameTrailingAlignment") ? .on : .off
        checkbox.toolTip = NSLocalizedString("Titles style: align app names toward their icons. Mirrored in right-to-left layouts. Applies the next time you open the switcher.", comment: "")
        checkbox.setAccessibilityLabel(Self.labelAppNameAlignment)
        checkbox.onAction = { control in
            UserDefaults.standard.set((control as! NSButton).state == .on, forKey: "localAppNameTrailingAlignment")
        }
        advancedTable.addRow(leftText: Self.labelAppNameAlignment, rightViews: [checkbox])
        advancedTable.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        let advancedView = TableGroupSetView(originalViews: [advancedTable], padding: 0)
        return TableGroupSetView(originalViews: [illustratedImageView, showHideView, advancedView], padding: 0)
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }
}
