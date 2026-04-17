//
//  NumberFormatting.swift
//  Kair Health
//
//  Shared numeric formatting helpers used across Health, Today, and Coach.
//

import Foundation

extension Double {
    var formattedPercent0: String {
        formatted(.percent.precision(.fractionLength(0)))
    }

    var formattedPercent1: String {
        formatted(.percent.precision(.fractionLength(1)))
    }

    var formattedOneDecimal: String {
        formatted(.number.precision(.fractionLength(1)))
    }
}
