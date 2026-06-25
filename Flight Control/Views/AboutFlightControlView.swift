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
                copyrightLine: "© 2026 Lunar Telephone Company. All rights reserved.",
                websiteDisplayText: websiteDisplayText,
                websiteURLString: websiteURLString,
                supportEmail: supportEmail,
                noticeTitle: "Flight Control Notice",
                noticeText: flightControlNoticeText,
                licenseTitle: "License / Terms of Use",
                licenseText: licenseText
            ) {
                thirdPartyNoticePanel
            }
        }
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

    private var flightControlNoticeText: String {
        "Flight Control is a local operator-assist utility for device inventory, network reachability checks, system-health visibility, timecode monitoring, and future remote reporting. Operators should verify monitored systems, alert rules, network conditions, and operating procedures before relying on it during rehearsal, public operation, or production use."
    }

    private var licenseText: String {
        "Flight Control is provided for authorized project monitoring and operational support. Use it at your own risk. The software, source code, interface design, workflows, and documentation remain proprietary to Lunar Telephone Company and may not be copied, redistributed, modified, or reused outside authorized work without written permission."
    }

    private var thirdPartyNoticePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Third-Party Timecode Decoder")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Flight Control uses x42/libltc through a local LTCLib wrapper for SMPTE LTC audio decoding.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("x42/libltc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Copyright © 2006–2022 Robin Gareus and contributors. Licensed under the GNU Lesser General Public License v3 or later. Source and license notices are included with the local LTCLib package used by Flight Control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Upstream: https://github.com/x42/libltc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
