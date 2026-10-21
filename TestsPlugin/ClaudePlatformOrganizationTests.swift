import Foundation
import Testing
@testable import CodexBarCore

extension ClaudePlatformPluginTests {
    @Test(arguments: BundledPluginTestSupport.engines)
    func `a forbidden api organization falls through to the next readable one`(
        engine: ProviderPluginEngineKind) async throws
    {
        let fixture = Fixture(
            organizations: """
            [{"uuid":"\(Self.chatOrganization)","name":"Synthetic Chat Organization","capabilities":["chat"]},
             {"uuid":"\(Self.apiOrganization)","name":"Synthetic Member Org","capabilities":["api"]},
             {"uuid":"\(Self.otherAPIOrganization)","name":"Synthetic Owner Org","capabilities":["api"]}]
            """,
            creditsStatus: [Self.apiOrganization: 403])
        let usage = try await Self.fetch(engine, fixture: fixture)
        #expect(usage.providerCost?.balance == 187.25)
        #expect(usage.identity?.accountOrganization == "Synthetic Owner Org")
        #expect(await fixture.paths == [
            "/api/organizations",
            "/api/organizations/\(Self.apiOrganization)/prepaid/credits",
            "/api/organizations/\(Self.otherAPIOrganization)/prepaid/credits",
            "/api/organizations/\(Self.otherAPIOrganization)/current_spend",
        ])
        #expect(await fixture.rejections == 0)
    }

    @Test(arguments: [false, true], BundledPluginTestSupport.engines)
    func `explicit organization selects its own balance regardless of list order`(
        reversed: Bool, engine: ProviderPluginEngineKind) async throws
    {
        var organizations = [
            "{\"uuid\":\"\(Self.apiOrganization)\",\"name\":\"Same name\",\"capabilities\":[\"api\"]}",
            "{\"uuid\":\"\(Self.otherAPIOrganization)\",\"name\":\"Same name\",\"capabilities\":[\"api\"]}",
        ]
        if reversed { organizations.reverse() }
        let fixture = Fixture(
            organizations: "[\(organizations.joined(separator: ","))]",
            creditsByOrganization: [
                Self.apiOrganization: #"{"amount":1,"currency":"USD"}"#,
                Self.otherAPIOrganization: Self.credits(
                    amount: 8008,
                    promo: Self.grant(
                        name: "API credit", program: "subscription_api_credit",
                        remaining: 8008, granted: 10000, expires: "2026-10-28T00:00:00Z"),
                    tranches: ""),
            ])
        let usage = try await Self.fetch(engine, fixture: fixture, organization: Self.otherAPIOrganization)
        #expect(usage.providerCost?.balance == 80.08)
        #expect(usage.primary != nil)
        #expect(await fixture.paths == [
            "/api/organizations",
            "/api/organizations/\(Self.otherAPIOrganization)/prepaid/credits",
            "/api/organizations/\(Self.otherAPIOrganization)/current_spend",
        ])
    }

    @Test(arguments: ["missing", "denied"], BundledPluginTestSupport.engines)
    func `unavailable selected organization never substitutes another wallet`(
        failure: String, engine: ProviderPluginEngineKind) async
    {
        let fixture = Fixture(
            organizations: """
            [{"uuid":"\(Self.otherAPIOrganization)","capabilities":["api"]},
             {"uuid":"\(Self.apiOrganization)","capabilities":["api"]}]
            """,
            creditsStatus: failure == "denied" ? [Self.apiOrganization: 403] : [:])
        await #expect {
            try await Self.fetch(
                engine, fixture: fixture,
                organization: failure == "missing" ? Self.chatOrganization : Self.apiOrganization)
        } throws: { ($0 as? ProviderFetchClassifiedError)?.kind == .permissionDenied }
        #expect(await fixture.paths == (failure == "missing" ? ["/api/organizations"] : [
            "/api/organizations", "/api/organizations/\(Self.apiOrganization)/prepaid/credits",
        ]))
    }
}
