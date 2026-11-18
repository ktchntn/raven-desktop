#!/usr/bin/env python3
"""Writes extension/themes/raven-color-theme.json from the RAVEN palette."""
import json
import os

P = {
    "void": "#000000", "surface": "#0E0E0E", "raised": "#1A1A1A", "line": "#2A2A2A",
    "off": "#333333", "faint": "#5E5E5E", "muted": "#7A7A7A", "dim": "#A3A3A3",
    "soft": "#CFCFCF", "text": "#E6E6E6", "ink": "#F2F2F2", "white": "#FFFFFF",
    "accent": "#C6FF00",
}
a = P["accent"]

def alpha(hex_, aa):
    return hex_ + aa

colors = {
    # Base
    "foreground": P["text"], "descriptionForeground": P["muted"], "errorForeground": a,
    "focusBorder": a, "contrastBorder": "#00000000", "widget.border": P["line"],
    "selection.background": alpha(a, "55"), "icon.foreground": P["dim"],
    "textLink.foreground": a, "textLink.activeForeground": "#D8FF4D",
    "textPreformat.foreground": P["soft"], "textBlockQuote.background": P["surface"],
    "textBlockQuote.border": P["line"], "textCodeBlock.background": P["surface"],
    "sash.hoverBorder": a, "progressBar.background": a,
    "scrollbar.shadow": "#00000000", "widget.shadow": "#00000000",
    "scrollbarSlider.background": alpha(P["line"], "99"),
    "scrollbarSlider.hoverBackground": P["off"], "scrollbarSlider.activeBackground": P["muted"],

    # Window chrome: flat black, 1px lines
    "titleBar.activeBackground": P["void"], "titleBar.activeForeground": P["dim"],
    "titleBar.inactiveBackground": P["void"], "titleBar.inactiveForeground": P["muted"],
    "titleBar.border": P["line"],
    "menu.background": P["surface"], "menu.foreground": P["ink"], "menu.border": P["line"],
    "menu.selectionBackground": P["raised"], "menu.selectionForeground": P["ink"],
    "menu.separatorBackground": P["line"], "menubar.selectionBackground": P["raised"],
    "commandCenter.background": P["surface"], "commandCenter.border": P["line"],
    "commandCenter.foreground": P["dim"], "commandCenter.activeBackground": P["raised"],

    "activityBar.background": P["void"], "activityBar.foreground": P["ink"],
    "activityBar.inactiveForeground": P["muted"], "activityBar.border": P["line"],
    "activityBar.activeBorder": a, "activityBar.activeBackground": "#00000000",
    "activityBarBadge.background": a, "activityBarBadge.foreground": "#000000",

    "sideBar.background": P["void"], "sideBar.foreground": P["dim"], "sideBar.border": P["line"],
    "sideBarTitle.foreground": P["ink"], "sideBarSectionHeader.background": P["void"],
    "sideBarSectionHeader.foreground": P["ink"], "sideBarSectionHeader.border": P["line"],

    "list.activeSelectionBackground": P["raised"], "list.activeSelectionForeground": P["white"],
    "list.inactiveSelectionBackground": P["surface"], "list.inactiveSelectionForeground": P["ink"],
    "list.hoverBackground": P["surface"], "list.hoverForeground": P["ink"],
    "list.focusOutline": a, "list.focusBackground": P["raised"], "list.highlightForeground": a,
    "list.errorForeground": a, "list.warningForeground": P["ink"],
    "list.inactiveFocusOutline": P["line"], "tree.indentGuidesStroke": P["line"],

    # Editor groups and tabs: active tab raised with a lime underline
    "editorGroup.border": P["line"], "editorGroupHeader.tabsBackground": P["void"],
    "editorGroupHeader.tabsBorder": P["line"], "editorGroupHeader.noTabsBackground": P["void"],
    "tab.activeBackground": P["raised"], "tab.activeForeground": P["white"],
    "tab.activeBorder": a, "tab.unfocusedActiveBorder": P["muted"],
    "tab.inactiveBackground": P["void"], "tab.inactiveForeground": P["muted"],
    "tab.unfocusedActiveBackground": P["surface"], "tab.unfocusedActiveForeground": P["dim"],
    "tab.unfocusedInactiveForeground": P["faint"], "tab.border": P["line"],
    "tab.hoverBackground": P["surface"], "tab.lastPinnedBorder": P["line"],
    "breadcrumb.foreground": P["muted"], "breadcrumb.focusForeground": P["ink"],
    "breadcrumb.activeSelectionForeground": a, "breadcrumbPicker.background": P["surface"],

    # Editor
    "editor.background": P["void"], "editor.foreground": P["text"],
    "editorCursor.foreground": a, "editorCursor.background": "#000000",
    "editor.lineHighlightBackground": P["surface"], "editor.lineHighlightBorder": "#00000000",
    "editorLineNumber.foreground": P["off"], "editorLineNumber.activeForeground": P["dim"],
    "editor.selectionBackground": alpha(a, "40"), "editor.inactiveSelectionBackground": alpha(a, "1F"),
    "editor.selectionHighlightBackground": alpha(a, "1A"), "editor.selectionHighlightBorder": alpha(a, "55"),
    "editor.wordHighlightBackground": alpha(P["white"], "14"), "editor.wordHighlightStrongBackground": alpha(a, "26"),
    "editor.findMatchBackground": alpha(a, "66"), "editor.findMatchBorder": a,
    "editor.findMatchHighlightBackground": alpha(a, "26"), "editor.rangeHighlightBackground": alpha(P["white"], "0D"),
    "editorWhitespace.foreground": P["line"], "editorIndentGuide.background1": P["raised"],
    "editorIndentGuide.activeBackground1": P["off"], "editorRuler.foreground": P["raised"],
    "editorBracketMatch.background": alpha(a, "26"), "editorBracketMatch.border": alpha(a, "88"),
    "editorBracketHighlight.foreground1": P["dim"], "editorBracketHighlight.foreground2": P["muted"],
    "editorBracketHighlight.foreground3": P["soft"], "editorBracketHighlight.unexpectedBracket.foreground": a,
    "editorLink.activeForeground": a, "editorCodeLens.foreground": P["faint"],
    "editorError.foreground": a, "editorWarning.foreground": P["ink"], "editorInfo.foreground": P["dim"],
    "editorHint.foreground": P["muted"], "problemsErrorIcon.foreground": a,
    "problemsWarningIcon.foreground": P["ink"], "problemsInfoIcon.foreground": P["dim"],
    "editorGutter.background": P["void"], "editorGutter.addedBackground": a,
    "editorGutter.modifiedBackground": P["dim"], "editorGutter.deletedBackground": P["muted"],
    "editorOverviewRuler.border": "#00000000", "editorOverviewRuler.errorForeground": a,
    "editorOverviewRuler.findMatchForeground": a, "editorOverviewRuler.modifiedForeground": P["dim"],
    "editorOverviewRuler.addedForeground": a,
    "minimap.background": P["void"], "minimap.selectionHighlight": alpha(a, "88"),
    "minimap.findMatchHighlight": a,
    "editorWidget.background": P["surface"], "editorWidget.border": P["line"],
    "editorWidget.foreground": P["ink"], "editorSuggestWidget.background": P["surface"],
    "editorSuggestWidget.border": P["line"], "editorSuggestWidget.selectedBackground": P["raised"],
    "editorSuggestWidget.highlightForeground": a, "editorSuggestWidget.focusHighlightForeground": a,
    "editorHoverWidget.background": P["surface"], "editorHoverWidget.border": P["line"],
    "peekView.border": a, "peekViewEditor.background": P["surface"], "peekViewResult.background": P["void"],
    "peekViewTitle.background": P["raised"], "peekViewEditor.matchHighlightBackground": alpha(a, "40"),
    "peekViewResult.matchHighlightBackground": alpha(a, "40"),
    "editorStickyScroll.background": P["void"], "editorStickyScrollHover.background": P["surface"],

    # Diffs and git
    "diffEditor.insertedTextBackground": alpha(a, "1F"), "diffEditor.removedTextBackground": alpha(P["white"], "14"),
    "diffEditor.insertedLineBackground": alpha(a, "10"), "diffEditor.removedLineBackground": alpha(P["white"], "0A"),
    "diffEditor.border": P["line"],
    "gitDecoration.addedResourceForeground": a, "gitDecoration.untrackedResourceForeground": a,
    "gitDecoration.modifiedResourceForeground": P["ink"], "gitDecoration.deletedResourceForeground": P["muted"],
    "gitDecoration.ignoredResourceForeground": P["faint"], "gitDecoration.conflictingResourceForeground": a,

    # Inputs, buttons, badges
    "input.background": P["surface"], "input.foreground": P["ink"], "input.border": P["line"],
    "input.placeholderForeground": P["faint"], "inputOption.activeBorder": a,
    "inputOption.activeBackground": alpha(a, "26"), "inputValidation.errorBorder": a,
    "inputValidation.errorBackground": P["surface"],
    "dropdown.background": P["surface"], "dropdown.border": P["line"], "dropdown.foreground": P["ink"],
    "dropdown.listBackground": P["surface"],
    "button.background": a, "button.foreground": "#000000", "button.hoverBackground": "#D8FF4D",
    "button.secondaryBackground": P["raised"], "button.secondaryForeground": P["ink"],
    "button.secondaryHoverBackground": P["line"], "button.border": "#00000000",
    "checkbox.background": P["surface"], "checkbox.border": P["line"], "checkbox.foreground": a,
    "badge.background": a, "badge.foreground": "#000000",
    "keybindingLabel.background": P["raised"], "keybindingLabel.foreground": P["ink"],
    "keybindingLabel.border": P["line"], "keybindingLabel.bottomBorder": P["line"],
    "quickInput.background": P["surface"], "quickInput.foreground": P["ink"],
    "quickInputList.focusBackground": P["raised"], "quickInputList.focusForeground": P["white"],
    "pickerGroup.border": P["line"], "pickerGroup.foreground": a,
    "notifications.background": P["surface"], "notifications.foreground": P["ink"],
    "notifications.border": P["line"], "notificationCenterHeader.background": P["raised"],
    "notificationsErrorIcon.foreground": a, "notificationsWarningIcon.foreground": P["ink"],
    "notificationsInfoIcon.foreground": P["dim"], "notificationLink.foreground": a,

    # Panel, terminal, status bar
    "panel.background": P["void"], "panel.border": P["line"],
    "panelTitle.activeForeground": P["ink"], "panelTitle.inactiveForeground": P["muted"],
    "panelTitle.activeBorder": a, "panelSection.border": P["line"],
    "terminal.background": P["void"], "terminal.foreground": P["text"],
    "terminalCursor.foreground": a, "terminal.selectionBackground": alpha(a, "55"),
    "terminal.border": P["line"],
    "terminal.ansiBlack": P["void"], "terminal.ansiBrightBlack": P["faint"],
    "terminal.ansiRed": a, "terminal.ansiBrightRed": a,
    "terminal.ansiGreen": "#9E9E9E", "terminal.ansiBrightGreen": "#9E9E9E",
    "terminal.ansiYellow": P["white"], "terminal.ansiBrightYellow": P["white"],
    "terminal.ansiBlue": P["ink"], "terminal.ansiBrightBlue": P["ink"],
    "terminal.ansiMagenta": "#B5B5B5", "terminal.ansiBrightMagenta": "#B5B5B5",
    "terminal.ansiCyan": "#8A8A8A", "terminal.ansiBrightCyan": "#8A8A8A",
    "terminal.ansiWhite": P["text"], "terminal.ansiBrightWhite": P["white"],
    "statusBar.background": P["void"], "statusBar.foreground": P["muted"], "statusBar.border": P["line"],
    "statusBar.noFolderBackground": P["void"], "statusBar.noFolderForeground": P["muted"],
    "statusBar.debuggingBackground": a, "statusBar.debuggingForeground": "#000000",
    "statusBarItem.hoverBackground": P["raised"], "statusBarItem.remoteBackground": a,
    "statusBarItem.remoteForeground": "#000000", "statusBarItem.errorBackground": a,
    "statusBarItem.errorForeground": "#000000", "statusBarItem.prominentBackground": P["raised"],
    "debugToolBar.background": P["surface"], "debugToolBar.border": P["line"],
    "welcomePage.tileBackground": P["surface"], "welcomePage.tileHoverBackground": P["raised"],
    "welcomePage.tileBorder": P["line"], "walkThrough.embeddedEditorBackground": P["surface"],
    "settings.headerForeground": P["ink"], "settings.modifiedItemIndicator": a,
    "settings.focusedRowBackground": P["surface"], "settings.rowHoverBackground": P["surface"],
}

def tok(scope, fg=None, style=None):
    s = {}
    if fg: s["foreground"] = fg
    if style is not None: s["fontStyle"] = style
    return {"scope": scope, "settings": s}

# Syntax: hierarchy in greys, lime only for keywords (the "interrupt" of the code).
tokenColors = [
    tok(["comment", "punctuation.definition.comment"], P["faint"], "italic"),
    tok(["keyword", "storage", "storage.type", "storage.modifier", "keyword.control",
         "keyword.operator.new", "keyword.operator.expression", "keyword.other.using",
         "keyword.other.import", "variable.language.this", "variable.language.self"], a, ""),
    tok(["keyword.operator", "punctuation", "meta.brace", "punctuation.separator",
         "punctuation.terminator"], P["muted"]),
    tok(["string", "string.quoted", "string.template", "punctuation.definition.string"], P["dim"]),
    tok(["constant.character.escape", "string.regexp"], P["soft"]),
    tok(["constant.numeric", "constant.language", "constant.other", "support.constant",
         "variable.other.constant"], P["soft"]),
    tok(["entity.name.function", "support.function", "meta.function-call",
         "entity.name.method", "variable.function"], P["white"], ""),
    tok(["entity.name.type", "entity.name.class", "support.type", "support.class",
         "entity.other.inherited-class", "entity.name.namespace"], P["ink"], "italic"),
    tok(["variable", "variable.other", "variable.parameter", "meta.definition.variable"], P["text"]),
    tok(["variable.parameter"], P["soft"], "italic"),
    tok(["entity.name.tag", "meta.tag.sgml"], a),
    tok(["entity.other.attribute-name"], P["dim"], "italic"),
    tok(["meta.decorator", "entity.name.function.decorator", "punctuation.decorator"], P["soft"], "italic"),
    tok(["markup.heading", "entity.name.section"], P["white"], "bold"),
    tok(["markup.bold"], P["white"], "bold"), tok(["markup.italic"], P["ink"], "italic"),
    tok(["markup.inline.raw", "markup.fenced_code"], P["soft"]),
    tok(["markup.underline.link", "string.other.link"], a),
    tok(["markup.inserted"], a), tok(["markup.deleted"], P["muted"]), tok(["markup.changed"], P["ink"]),
    tok(["invalid", "invalid.illegal"], a, "underline"),
    tok(["support.type.property-name", "meta.object-literal.key"], P["ink"]),
]

theme = {
    "$schema": "vscode://schemas/color-theme",
    "name": "RAVEN",
    "type": "dark",
    "semanticHighlighting": True,
    "semanticTokenColors": {
        "keyword": a, "function": P["white"], "method": P["white"],
        "class": {"foreground": P["ink"], "italic": True}, "type": {"foreground": P["ink"], "italic": True},
        "parameter": {"foreground": P["soft"], "italic": True}, "variable": P["text"],
        "variable.readonly": P["soft"], "property": P["ink"], "string": P["dim"], "number": P["soft"],
        "comment": {"foreground": P["faint"], "italic": True}, "namespace": P["ink"],
    },
    "colors": colors,
    "tokenColors": tokenColors,
}

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "extension", "themes", "raven-color-theme.json")
with open(out, "w") as f:
    json.dump(theme, f, indent=2)
print(f"make-theme: {len(colors)} UI colours, {len(tokenColors)} token rules -> {out}")
