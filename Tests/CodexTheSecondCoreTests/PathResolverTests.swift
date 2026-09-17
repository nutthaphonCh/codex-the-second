import Testing
@testable import CodexTheSecondCore

@Suite("Path resolution")
struct PathResolverTests {
    let home = "/Users/test"

    @Test func expandsBareTilde() {
        #expect(PathResolver.expand("~", homeDirectory: home) == "/Users/test")
    }

    @Test func expandsTildePrefix() {
        #expect(PathResolver.expand("~/.codex-personal", homeDirectory: home) == "/Users/test/.codex-personal")
    }

    @Test func leavesAbsolutePathsAlone() {
        #expect(PathResolver.expand("/opt/codex", homeDirectory: home) == "/opt/codex")
    }

    @Test func doesNotExpandTildeInTheMiddle() {
        #expect(PathResolver.expand("/opt/~/x", homeDirectory: home) == "/opt/~/x")
    }

    @Test func stripsTrailingSlashAndCollapsesDotDot() {
        #expect(PathResolver.expand("~/a/../b/", homeDirectory: home) == "/Users/test/b")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(PathResolver.expand("  ~/.codex-work \n", homeDirectory: home) == "/Users/test/.codex-work")
    }

    @Test func detectsContainment() {
        #expect(PathResolver.isSameOrInside("/Users/test/.codex", parent: "/Users/test/.codex"))
        #expect(PathResolver.isSameOrInside("/Users/test/.codex/auth.json", parent: "/Users/test/.codex"))
        #expect(!PathResolver.isSameOrInside("/Users/test/.codex-personal", parent: "/Users/test/.codex"))
    }
}
