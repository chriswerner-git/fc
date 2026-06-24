//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: FCDesignSystem.swift
//  Purpose: Centralized SwiftUI design tokens for Flight Control.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//


import SwiftUI

enum FCDesign {
    enum ColorToken {
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let controlBackground = Color(nsColor: .controlBackgroundColor)
        static let textBackground = Color(nsColor: .textBackgroundColor)
        static let active = Color.blue
        static let good = Color.green
        static let warning = Color.orange
        static let critical = Color.red
        static let quietSurface = Color.primary.opacity(0.055)
        static let standardBorder = Color.white.opacity(0.08)
        static let strongBorder = Color.white.opacity(0.16)
    }

    enum Radius {
        static let panel: CGFloat = 16
        static let card: CGFloat = 14
        static let inset: CGFloat = 12
        static let chip: CGFloat = 7
    }

    enum Opacity {
        static let cardBackground = 0.72
        static let insetBackground = 0.18
        static let screenControlBackground = 0.58
    }

    static func screenBackground() -> LinearGradient {
        LinearGradient(colors: [ColorToken.windowBackground, ColorToken.controlBackground.opacity(Opacity.screenControlBackground)], startPoint: .top, endPoint: .bottom)
    }

    static func cardBackground(cornerRadius: CGFloat = Radius.panel) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ColorToken.controlBackground.opacity(Opacity.cardBackground))
            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    static func cardBorder(cornerRadius: CGFloat = Radius.panel) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorToken.standardBorder, lineWidth: 1)
    }
}
