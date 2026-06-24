//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AboutFlightControlView.swift
//  Purpose: About window for Flight Control.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import AppKit
import SwiftUI

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
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    applicationCard
                    companyCard
                    disclaimerCard
                    licenseCard
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var applicationCard: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Application", subtitle: "Build information")

                HStack(alignment: .center, spacing: 18) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .accessibilityLabel("Flight Control app icon")

                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(label: "Application", value: AppInfo.appName)
                        infoRow(label: "Version", value: AppInfo.versionString)
                        infoRow(label: "Build", value: AppInfo.buildString)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var companyCard: some View {
        FCCard {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(title: "Lunar Telephone Company", subtitle: "Mission Control")

                    linkedInfoRow(label: "Website", value: websiteDisplayText, systemImage: "safari") {
                        openWebsite()
                    }

                    linkedInfoRow(label: "Email", value: supportEmail, systemImage: "envelope") {
                        openSupportEmail()
                    }

                    Text(AppInfo.copyrightLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Image("LTCIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .accessibilityLabel("Lunar Telephone Company icon")

                    Image("LTCLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 148, height: 42)
                        .accessibilityLabel("Lunar Telephone Company logo")
                }
                .opacity(0.92)
            }
        }
    }

    private var disclaimerCard: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "Disclaimer", subtitle: "Operational notice")

                Text(disclaimerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var licenseCard: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "License / Terms of Use", subtitle: "Summary notice")

                ScrollView(.vertical) {
                    Text(licenseText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 8)
                }
                .frame(height: 118)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.headline.bold())
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
        }
    }

    private func linkedInfoRow(label: String, value: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                    Image(systemName: systemImage)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(FCDesign.ColorToken.active)
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
            URLQueryItem(name: "body", value: "Hello Mission Control,\n\nI need support with Flight Control.\n\nVersion: \(AppInfo.versionString)\nBuild: \(AppInfo.buildString)\n")
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    private var disclaimerText: String {
        """
        Flight Control is an operator-assist utility for tracking configured project devices, checking network reachability, and summarizing system health. Operators are responsible for verifying all monitored devices, network conditions, alert rules, and operational procedures before rehearsal, public operation, or production use.

        Lunar Telephone Company is not responsible for unintended operation, missed alerts, incorrect device state, network failures, equipment behavior, data loss, show interruption, or damages resulting from configuration errors, connected-system behavior, local network conditions, or use in production environments.
        """
    }

    private var licenseText: String {
        """
        Flight Control is licensed for use as an operator-assist monitoring and project-location device inventory utility. Use of this software is at the operator's own risk.

        This software is provided “as is,” without warranty of any kind, express or implied. Lunar Telephone Company does not warrant that the software will be uninterrupted, error-free, suitable for any specific production environment, or compatible with all networks, control systems, connected devices, or operating conditions.

        No portion of this software, interface, configuration model, source code, documentation, or related intellectual property may be copied, distributed, disclosed, modified, reverse engineered, or reused outside authorized Lunar Telephone Company work without prior written permission.
        """
    }
}
