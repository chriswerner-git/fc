//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: HelpFlightControlView.swift
//  Purpose: Operator help and first-pass implementation notes.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//


import SwiftUI

struct HelpFlightControlView: View {
    var body: some View {
        FCScreen(title: "FC - Help", subtitle: "First-pass guidance and future expansion notes.", showHelpButton: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: FCLayout.Spacing.section) {
                    helpCard("What Flight Control Does", "Flight Control keeps a local inventory of project devices and periodically checks their health. This first pass implements manual device entry and ping monitoring. The architecture leaves space for ARP, sACN, CITP, TCP, HTTP, timecode, and DSN/Mission Control reporting.")
                    helpCard("Health States", "Healthy means the last check succeeded. Warning is the first missed check by default. Critical is three consecutive missed checks by default. Unknown means Flight Control has not collected enough information yet. Disabled devices are retained in the inventory but skipped.")
                    helpCard("Device Inventory", "Add devices manually, then assign location, discipline, function, responsible party, scene, and tags. These grouping fields are intentionally flexible so the organization model can evolve after real use.")
                    helpCard("Deep Space Network", "DSN controls are placeholders in this build. They reserve app structure for future transmission to Mission Control without pretending that feature is already operational.")
                }
            }
        }
    }

    private func helpCard(_ title: String, _ bodyText: String) -> some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(bodyText).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
