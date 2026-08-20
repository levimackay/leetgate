import Testing
import Foundation
@testable import LeetgateCore

private let existing = """
##
# Host Database
##
127.0.0.1\tlocalhost
255.255.255.255\tbroadcasthost
::1             localhost
10.0.0.5\tstaging.client.internal
"""

@Test func renderNullsBothApexAndWWW() {
    let block = HostsFile.render(domains: ["reddit.com"])
    #expect(block.contains("0.0.0.0 reddit.com"))
    #expect(block.contains("0.0.0.0 www.reddit.com"))
    #expect(block.hasPrefix(HostsFile.beginMarker))
    #expect(block.hasSuffix(HostsFile.endMarker))
}

@Test func spliceAppendsBlockWhenNoMarkersPresent() {
    let block = HostsFile.render(domains: ["reddit.com"])
    let result = HostsFile.splice(into: existing, block: block)
    #expect(result.contains("10.0.0.5\tstaging.client.internal"))
    #expect(result.contains("0.0.0.0 reddit.com"))
    #expect(result.contains(HostsFile.beginMarker))
}

@Test func spliceReplacesAnExistingBlockWithoutDuplicating() {
    let first = HostsFile.splice(into: existing, block: HostsFile.render(domains: ["reddit.com"]))
    let second = HostsFile.splice(into: first, block: HostsFile.render(domains: ["youtube.com"]))
    #expect(second.contains("0.0.0.0 youtube.com"))
    #expect(!second.contains("0.0.0.0 reddit.com"))
    let markerCount = second.components(separatedBy: HostsFile.beginMarker).count - 1
    #expect(markerCount == 1)
}

@Test func spliceWithNilBlockRemovesOurSectionAndNothingElse() {
    let blocked = HostsFile.splice(into: existing, block: HostsFile.render(domains: ["reddit.com"]))
    let cleared = HostsFile.splice(into: blocked, block: nil)
    #expect(!cleared.contains(HostsFile.beginMarker))
    #expect(!cleared.contains("0.0.0.0 reddit.com"))
    #expect(cleared.contains("10.0.0.5\tstaging.client.internal"))
    #expect(cleared.contains("127.0.0.1\tlocalhost"))
}

@Test func removalIsIdempotentWhenNoBlockExists() {
    #expect(HostsFile.splice(into: existing, block: nil).contains("127.0.0.1\tlocalhost"))
}

@Test func foreignContentAfterOurBlockSurvivesReplacement() {
    let withTrailer = HostsFile.splice(into: existing, block: HostsFile.render(domains: ["reddit.com"]))
        + "\n192.168.1.9\tprinter.local\n"
    let replaced = HostsFile.splice(into: withTrailer, block: HostsFile.render(domains: ["x.com"]))
    #expect(replaced.contains("192.168.1.9\tprinter.local"))
    #expect(replaced.contains("0.0.0.0 x.com"))
}

@Test func leetcodeIsNeverRenderedEvenIfPassedIn() {
    let block = HostsFile.render(domains: ["leetcode.com", "reddit.com"])
    #expect(!block.contains("leetcode.com"))
    #expect(block.contains("reddit.com"))
}
