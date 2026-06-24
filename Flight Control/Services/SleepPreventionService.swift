//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: SleepPreventionService.swift
//  Purpose: Optional macOS idle sleep assertion for persistent monitoring use.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control, a macOS utility developed
//  by Lunar Telephone Company for persistent project-location device
//  inventory, network health monitoring, dashboard visibility, and future
//  Deep Space Network reporting.
//
//  This software is provided for internal operational use and project support.
//  No portion of this file may be copied, distributed, disclosed, modified,
//  or reused outside authorized Lunar Telephone Company work without prior
//  written permission.
//

import Foundation
import IOKit.pwr_mgt

final class SleepPreventionService {
    private var assertionID = IOPMAssertionID(0)

    var isActive: Bool {
        assertionID != 0
    }

    func enable(reason: String) throws {
        guard isActive == false else { return }

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            assertionID = 0
            throw SleepPreventionError.assertionCreationFailed(result)
        }

        assertionID = newAssertionID
    }

    func disable() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    deinit {
        disable()
    }
}

enum SleepPreventionError: LocalizedError {
    case assertionCreationFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .assertionCreationFailed(let code):
            return "macOS sleep-prevention assertion failed with code \(code)."
        }
    }
}
