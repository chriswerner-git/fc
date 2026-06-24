//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: HelpFlightControlView.swift
//  Purpose: Operator help and first-pass implementation notes, using LunarKit shared layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI
import LunarKit

struct HelpFlightControlView: View {
    var body: some View {
        FCScreen(
            title: "Help",
            subtitle: "Operator guidance and future expansion notes.",
            systemImage: "questionmark.circle",
            showHelpButton: false
        ) {
            LTCHelpShell(sections: helpSections)
        }
    }

    private var helpSections: [LTCHelpSection] {
        [
            LTCHelpSection(
                title: "What Flight Control Does",
                body: "Flight Control keeps a local inventory of project devices and periodically checks their health. This first pass implements manual device entry and ping monitoring. The architecture leaves space for ARP, sACN, CITP, TCP, HTTP, timecode, camera feeds, and Deep Space Network reporting."
            ),
            LTCHelpSection(
                title: "Health States",
                body: "Healthy means the last check succeeded. Warning is the first missed check by default. Critical is three consecutive missed checks by default. Unknown means Flight Control has not collected enough information yet. Disabled devices are retained in the inventory but skipped."
            ),
            LTCHelpSection(
                title: "Device Inventory",
                body: "Add devices manually, organize them into nested groups, and apply tags as needed. Groups and tags are intentionally flexible so each project can organize devices by location, discipline, responsible party, system type, scene, or whatever structure is most useful."
            ),
            LTCHelpSection(
                title: "Dashboard Layout",
                body: "The Dashboard summarizes project health, local interfaces, recent alerts, future weather/timecode/camera modules, and compact device-status blocks. Device blocks can be arranged on the dashboard and opened for detail review."
            ),
            LTCHelpSection(
                title: "Deep Space Network",
                body: "Deep Space Network and Mission Control are placeholders in this build. They reserve app structure for future status transmission to another location without presenting that feature as active."
            )
        ]
    }
}
