//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AboutFlightControlView.swift
//  Purpose: About window for Flight Control, using LunarKit shared layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import AppKit
import SwiftUI
import LunarKit

struct AboutFlightControlView: View {
    private let websiteDisplayText = "www.lunartelephone.com"
    private let websiteURLString = "https://www.lunartelephone.com"
    private let supportEmail = "missioncontrol@lunartelephone.com"

    var body: some View {
        FCScreen(
            title: "About",
            subtitle: "Version, copyright, and operational context.",
            systemImage: "paperplane.fill",
            showHelpButton: false
        ) {
            LTCAboutShell(
                identity: flightControlIdentity,
                version: appVersion,
                build: appBuild,
                copyrightLine: "© 2026 Lunar Telephone Company. All rights reserved."
            ) {
                contactCard
                flightControlNoticeCard
            }
        }
    }

    private var contactCard: some View {
        LTCCard(title: "Contact", systemImage: "link") {
            VStack(alignment: .leading, spacing: 12) {
                linkedInfoRow(label: "Website", value: websiteDisplayText, systemImage: "safari") {
                    openWebsite()
                }

                linkedInfoRow(label: "Email", value: supportEmail, systemImage: "envelope") {
                    openSupportEmail()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var flightControlNoticeCard: some View {
        LTCCard(title: "Flight Control Notice", systemImage: "antenna.radiowaves.left.and.right") {
            Text("Flight Control is a local operator-assist utility for project device inventory, network reachability checks, system-health visibility, and future Deep Space Network reporting. Operators remain responsible for verifying monitored systems, alert rules, network conditions, and operating procedures before rehearsal, public operation, or production use.")
                .font(LTCDesign.FontToken.cardCaption)
                .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func linkedInfoRow(label: String, value: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                .frame(width: 90, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                    Image(systemName: systemImage)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LTCDesign.ColorToken.accent)
        }
    }

    private func openWebsite() {
        guard let url = URL(string: websiteURLString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openSupportEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Flight Control Support"),
            URLQueryItem(name: "body", value: "Hello Mission Control,\n\nI need support with Flight Control.\n\nVersion: \(appVersion)\nBuild: \(appBuild)\n")
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    private var flightControlIdentity: LTCAppIdentity {
        LTCAppIdentity(
            initials: "FC",
            displayName: "Flight Control",
            headerTitle: "FLIGHT CONTROL",
            appIconName: "AppIcon",
            companyIconName: "LTCIcon",
            companyLogoName: "LTCLogo"
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
