#if canImport(XCTest)
import Foundation
import XCTest
@testable import SnippetCore

final class SnippetMatcherTests: XCTestCase {
    func testLongestMatchWins() {
        let rules = [
            SnippetRule(trigger: "meine website", replacement: "https://example.com"),
            SnippetRule(trigger: "website", replacement: "https://fallback.example")
        ]

        let matcher = DefaultSnippetMatcher(rules: rules)
        let output = matcher.applyToFinal("Das ist meine Website heute", locale: Locale(identifier: "de_AT"))

        XCTAssertEqual(output, "Das ist https://example.com heute")
    }

    func testCaseInsensitiveReplacement() {
        let rules = [
            SnippetRule(trigger: "HOMEPAGE", replacement: "https://acme.dev", caseSensitive: false)
        ]

        let matcher = DefaultSnippetMatcher(rules: rules)
        let output = matcher.applyToFinal("Unsere homepage ist live", locale: Locale(identifier: "de_AT"))

        XCTAssertEqual(output, "Unsere https://acme.dev ist live")
    }

    func testStreamingReplacementEmitsOperation() {
        let rule = SnippetRule(trigger: "support email", replacement: "support@acme.dev")
        let matcher = DefaultSnippetMatcher(rules: [rule])

        XCTAssertTrue(matcher.consumeCommittedToken("support").isEmpty)
        let ops = matcher.consumeCommittedToken("email")

        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.replaceLastTokenCount, 2)
        XCTAssertEqual(ops.first?.replacementText, "support@acme.dev")
    }

    func testApplyToFinalHandlesDiacriticInsensitiveLocale() {
        let rule = SnippetRule(trigger: "cafe", replacement: "coffee")
        let matcher = DefaultSnippetMatcher(rules: [rule])

        let output = matcher.applyToFinal("Willkommen im Café", locale: Locale(identifier: "de_AT"))

        XCTAssertEqual(output, "Willkommen im coffee")
    }
}
#endif
