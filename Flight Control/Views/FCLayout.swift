//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: FCLayout.swift
//  Purpose: Shared layout constants and reusable screen chrome.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI

enum FCLayout {
    static let appName = "Flight Control"
    static let appNameDisplay = "FLIGHT CONTROL"
    static let headerPrefix = "FC"

    enum TopChrome {
        static let appNameFontSize: CGFloat = 12
        static let appNameFontWeight: Font.Weight = .semibold
        static let appNameTracking: CGFloat = 1.8
        static let dividerHeight: CGFloat = 1
        static let verticalSpacing: CGFloat = 12
        static let headerIconSize: CGFloat = 54
        static let helpButtonSize: CGFloat = 24
    }

    enum Window {
        struct Metrics { let defaultWidth: CGFloat; let defaultHeight: CGFloat; let minWidth: CGFloat; let minHeight: CGFloat }
        static let dashboard = Metrics(defaultWidth: 1280, defaultHeight: 900, minWidth: 980, minHeight: 760)
        static let inventory = Metrics(defaultWidth: 1160, defaultHeight: 820, minWidth: 920, minHeight: 680)
        static let preferences = Metrics(defaultWidth: 900, defaultHeight: 760, minWidth: 760, minHeight: 640)
        static let diagnostics = Metrics(defaultWidth: 980, defaultHeight: 760, minWidth: 760, minHeight: 620)
        static let help = Metrics(defaultWidth: 760, defaultHeight: 720, minWidth: 620, minHeight: 560)
        static let about = Metrics(defaultWidth: 620, defaultHeight: 760, minWidth: 540, minHeight: 620)
    }

    enum Dashboard {
        static let clockPanelHeight: CGFloat = 118
        static let clockPanelVerticalPadding: CGFloat = 8
        static let clockPanelHorizontalPadding: CGFloat = 14
        static let clockProjectNameFontSize: CGFloat = 14
        static let clockTimeFontSize: CGFloat = 38
    }

    enum Spacing {
        static let screenPadding: CGFloat = 18
        static let section: CGFloat = 16
        static let card: CGFloat = 14
        static let compact: CGFloat = 8
    }
}

struct FCScreen<Content: View>: View {
    let title: String
    let subtitle: String
    var systemImage: String? = nil
    var showHelpButton: Bool = true
    let content: Content
    @Environment(\.openWindow) private var openWindow

    init(
        title: String,
        subtitle: String,
        systemImage: String? = nil,
        showHelpButton: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.showHelpButton = showHelpButton
        self.content = content()
    }

    private var displayTitle: String {
        if title.hasPrefix("FC - ") {
            return String(title.dropFirst(5))
        }
        return title
    }

    private var resolvedSystemImage: String {
        if let systemImage { return systemImage }
        switch displayTitle.lowercased() {
        case let value where value.contains("dashboard"):
            return "rectangle.grid.2x2.fill"
        case let value where value.contains("inventory"):
            return "list.bullet.rectangle.portrait"
        case let value where value.contains("preferences"):
            return "slider.horizontal.3"
        case let value where value.contains("diagnostics"):
            return "waveform.path.ecg.rectangle"
        case let value where value.contains("about"):
            return "paperplane.fill"
        case let value where value.contains("help"):
            return "questionmark.circle"
        default:
            return "antenna.radiowaves.left.and.right"
        }
    }

    var body: some View {
        VStack(spacing: FCLayout.TopChrome.verticalSpacing) {
            appNameChrome
            divider
            pageHeader
            content
        }
        .padding(FCLayout.Spacing.screenPadding)
        .background(FCDesign.screenBackground().ignoresSafeArea())
    }

    private var appNameChrome: some View {
        ZStack {
            Text(FCLayout.appNameDisplay)
                .font(.system(
                    size: FCLayout.TopChrome.appNameFontSize,
                    weight: FCLayout.TopChrome.appNameFontWeight
                ))
                .tracking(FCLayout.TopChrome.appNameTracking)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                if showHelpButton {
                    Button { openWindow(id: "help-window") } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: FCLayout.TopChrome.helpButtonSize, height: FCLayout.TopChrome.helpButtonSize)
                    }
                    .buttonStyle(.borderless)
                    .help("Open Flight Control Help")
                }
            }
        }
        .frame(height: 24)
    }

    private var divider: some View {
        Rectangle()
            .fill(FCDesign.ColorToken.strongBorder)
            .frame(height: FCLayout.TopChrome.dividerHeight)
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(FCDesign.ColorToken.active.opacity(0.18))
                    .frame(width: FCLayout.TopChrome.headerIconSize, height: FCLayout.TopChrome.headerIconSize)

                Image(systemName: resolvedSystemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(FCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

struct FCCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .background(FCDesign.cardBackground())
            .overlay(FCDesign.cardBorder())
    }
}
