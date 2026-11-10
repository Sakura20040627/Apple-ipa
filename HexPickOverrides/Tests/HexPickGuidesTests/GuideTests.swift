import XCTest
@testable import HexPickGuides

final class GuideTests: XCTestCase {
    func testBundledAdaptersKeepSourcesAndAttribution() throws {
        let library = try GuideLibrary.bundled()
        XCTAssertEqual(library.guides.filter { $0.metadata.source == .mayhempedia }.count, 233)
        XCTAssertEqual(library.guides.filter { $0.metadata.source == .aramMayhem }.count, 666)
        XCTAssertEqual(Set(library.guides.map(\.id)).count, library.guides.count)
        for guide in library.guides { try guide.metadata.validate(); XCTAssertFalse(guide.sourceURL.absoluteString.isEmpty) }
        let combinations = library.guides.filter { $0.kind == .combination }
        XCTAssertTrue(combinations.allSatisfy { $0.items.isEmpty && $0.starterItems.isEmpty && $0.explanation == nil })
        XCTAssertGreaterThan(library.equipmentCount, 0)
    }
    func testNamespacedIDsAreNotRiotRuntimeIDs() throws {
        let context = try GuideLibrary.bundled().context
        let may = try XCTUnwrap(context.augments["may:41"])
        XCTAssertEqual(may.name, "歌利亚巨人")
        XCTAssertNotEqual(may.riotID, "41")
        XCTAssertTrue(context.items.values.filter { !$0.id.isEmpty }.allSatisfy { $0.iconURL == nil || $0.iconURL!.hasPrefix("https://raw.communitydragon.org/") })
    }
    func testMissingMetadataRejectedAndReferenceAdapterDisabled() throws {
        let library = try GuideLibrary.bundled()
        let invalid = GuideMetadata(source: .mayhempedia, patch: "", updatedAt: "", updateMeaning: "", retrievedAt: "", revision: "")
        XCTAssertThrowsError(try invalid.validate())
        let adapter = AstrBotReferenceAdapter()
        XCTAssertFalse(adapter.productionEnabled)
        XCTAssertThrowsError(try adapter.convert(Data(), context: library.context))
    }
    func testConflictsRemainSeparateAndTrapMeaningNotInvented() throws {
        let library = try GuideLibrary.bundled()
        let may = try XCTUnwrap(library.guides.first { $0.metadata.source == .mayhempedia && !GuideConflict.fields(for: $0, among: library.guides).isEmpty })
        let sameHero = library.guides.filter { $0.heroID == may.heroID }
        XCTAssertTrue(sameHero.contains { $0.metadata.source == .aramMayhem })
        XCTAssertTrue(sameHero.contains { $0.id == may.id })
        XCTAssertEqual(library.guides.filter { $0.metadata.source == .aramMayhem && $0.tags.isEmpty }.count, 403, "Missing upstream tags must stay missing, never be invented")
    }
}
