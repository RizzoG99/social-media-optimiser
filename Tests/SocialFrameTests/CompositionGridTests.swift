import XCTest
@testable import SocialFrame

final class CompositionGridTests: XCTestCase {
    func testGuideGeometryStaysInsideCanvas() {
        for grid in CompositionGrid.allCases {
            for line in grid.lines {
                for point in [line.start, line.end] {
                    XCTAssertTrue((0...1).contains(point.x), grid.rawValue)
                    XCTAssertTrue((0...1).contains(point.y), grid.rawValue)
                }
                XCTAssertNotEqual(line.start, line.end)
            }
        }
    }
    func testGuidesHaveDistinctCompositionPatterns() {
        XCTAssertTrue(CompositionGrid.none.lines.isEmpty)
        XCTAssertEqual(CompositionGrid.thirds.lines.count, 4)
        XCTAssertEqual(CompositionGrid.goldenRatio.lines.count, 4)
        XCTAssertEqual(CompositionGrid.center.lines.count, 2)
        XCTAssertEqual(CompositionGrid.diagonals.lines.count, 2)
        XCTAssertEqual(CompositionGrid.fine.lines.count, 14)
        XCTAssertEqual(CompositionGrid.thirds.lines[0].start.x, 1 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(CompositionGrid.goldenRatio.lines[0].start.x, 0.381966, accuracy: 0.0001)
        XCTAssertNotEqual(CompositionGrid.thirds.lines, CompositionGrid.goldenRatio.lines)
        XCTAssertEqual(CompositionGrid.diagonals.lines[0].end, CGPoint(x: 1, y: 1))
    }
}
