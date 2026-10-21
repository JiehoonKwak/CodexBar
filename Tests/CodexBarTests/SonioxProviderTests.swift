import AppKit
import CodexBarCore
import Foundation
import SwiftUI
import Testing
@testable import CodexBar
@testable import CodexBarCLI

@MainActor
struct SonioxProviderTests {
    @Test
    func `standard settings persist the organization key and detect availability`() throws {
        let fixture = try ProviderSettingsDescriptorTests().makeSettingsFixture(suite: "SonioxProviderTests")
        let implementation = try #require(ProviderCatalog.implementation(for: .soniox))
        let fields = implementation.settingsFields(context: fixture.settingsContext(provider: .soniox))
        let field = try #require(fields.first)
        #expect(fields.count == 1)
        #expect(field.kind == .secure)
        #expect(field.title == "API key")
        #expect(ProviderSelection(argument: "SONIOX")?.asList == [.soniox])
        #expect(!implementation.isAvailable(context: .init(
            provider: .soniox, settings: fixture.settings, environment: [:])))
        field.binding.wrappedValue = "snx_org_fixture"
        #expect(fixture.settings[providerConfig: .soniox, field: .apiKey] == "snx_org_fixture")
        #expect(implementation.isAvailable(context: .init(
            provider: .soniox, settings: fixture.settings, environment: [:])))
    }

    @Test
    func `menu card separates the monthly budget from prepaid balance`() throws {
        let now = Date(timeIntervalSince1970: 1_792_540_800)
        let resetsAt = try #require(ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z"))
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 6, windowMinutes: nil, resetsAt: resetsAt, resetDescription: "$6.00 / $100.00"),
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 6, limit: 100, currencyCode: "USD", period: "This month", balance: 18.5, updatedAt: now),
            updatedAt: now)
        let model = try UsageMenuCardView.Model.make(.init(
            provider: .soniox,
            metadata: #require(ProviderDefaults.metadata[.soniox]),
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: true,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))
        #expect(model.metrics.first?.title == "Monthly budget")
        #expect(model.metrics.first?.percent == 6)
        #expect(model.metrics.first?.detailText == "$6.00 / $100.00")
        #expect(model.metrics.first?.resetText?.contains("$") == false)
        #expect(model.providerCost?.spendLine == "This month: $6.00")
        #expect(model.providerCost?.balanceLine == "Balance: $18.50")

        if let path = ProcessInfo.processInfo.environment["CODEXBAR_SONIOX_SCREENSHOT_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for dark in [false, true] {
                let view = UsageMenuCardView(model: model, width: 380)
                    .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.displayScale, 2)
                    .background(Color(nsColor: .windowBackgroundColor))
                let hosting = NSHostingView(rootView: view)
                hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                let data = try #require(MenuLayoutScreenshotRenderTests.pngDataWithWindow(hosting: hosting))
                try data.write(to: directory.appendingPathComponent("soniox-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
