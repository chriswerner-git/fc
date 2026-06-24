//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DiagnosticsView.swift
//  Purpose: Diagnostics screen for monitoring engine, configuration, devices, and network interfaces.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//


import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        FCScreen(title: "FC - Diagnostics", subtitle: "Operational details for long-running monitoring stability.") {
            ScrollView {
                VStack(spacing: FCLayout.Spacing.section) {
                    engineSection
                    configurationSection
                    interfaceSection
                    deviceSection
                }
            }
        }
    }

    private var engineSection: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Monitoring Engine").font(.headline)
                LabeledContent("State", value: appState.monitoringRunning ? "Running" : "Stopped")
                LabeledContent("Last Message", value: appState.lastEngineMessage)
                LabeledContent("Last Check", value: appState.lastCheckDate?.formatted(date: .abbreviated, time: .standard) ?? "Never")
                LabeledContent("Next Check", value: appState.nextCheckDate?.formatted(date: .abbreviated, time: .standard) ?? "Pending")
                LabeledContent("Ping Concurrency Limit", value: "\(appState.settings.pingConcurrencyLimit)")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var configurationSection: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration Issues").font(.headline)
                if appState.configurationIssues.isEmpty {
                    Text("No current configuration issues.").foregroundStyle(.secondary)
                } else {
                    ForEach(appState.configurationIssues) { issue in
                        Label(issue.title, systemImage: issue.state.systemImageName).foregroundStyle(issue.state.color)
                        Text(issue.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var interfaceSection: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Network Interfaces").font(.headline); Spacer(); Button("Refresh") { appState.refreshNetworkInterfaces() } }
                ForEach(appState.networkInterfaces) { interface in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interface.displayName).font(.subheadline.bold())
                        Text("Name: \(interface.name) · \(interface.detailDisplay)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Divider()
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var deviceSection: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Device Probe Details").font(.headline)
                ForEach(appState.devices) { device in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Label(device.displayName, systemImage: device.healthState.systemImageName).foregroundStyle(device.healthState.color)
                            Spacer()
                            Text(device.monitoringMethod.displayName).foregroundStyle(.secondary)
                        }
                        Text("Host: \(device.addressDisplay) · Fails: \(device.consecutiveFailures) · Last: \(device.lastCheckedAt?.formatted(date: .abbreviated, time: .standard) ?? "Never")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let error = device.lastErrorMessage {
                            Text(error).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    Divider()
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
