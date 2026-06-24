//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: StatusCardView.swift
//  Purpose: Reusable dashboard status card component.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//


import SwiftUI

struct StatusCardView: View {
    let title: String
    let value: String
    let detail: String
    let state: DeviceHealthState

    var body: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: state.systemImageName).foregroundStyle(state.color)
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
