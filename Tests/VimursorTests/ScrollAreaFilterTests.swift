import Testing
import CoreGraphics
@testable import Vimursor

@Suite("ScrollAreaFilter Tests")
struct ScrollAreaFilterTests {

    // MARK: - filterByWindow

    @Test("Area containing entire window is excluded (desktop-level area)")
    func areaContainingEntireWindowExcluded() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area is larger than window and contains it
        let area = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.isEmpty)
    }

    @Test("Area with no intersection is excluded")
    func areaWithNoIntersectionExcluded() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area is completely outside window
        let area = CGRect(x: 1000, y: 1000, width: 400, height: 300)
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.isEmpty)
    }

    @Test("Area with less than 50% visible is excluded")
    func areaWithLessThan50PercentVisibleExcluded() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // intersection = x:100..900, y:200..700 = 800x500 = 400000
        // original area = 2000*600 = 1200000
        // ratio = 400000/1200000 = 33% < 50% → excluded
        let area2 = CGRect(x: 0, y: 200, width: 2000, height: 600)
        let result = ScrollAreaFilter.filterByWindow(areas: [area2], windowFrame: windowFrame)
        #expect(result.isEmpty)
    }

    @Test("Area fully inside window is kept unchanged")
    func areaFullyInsideWindowKept() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area fully inside window
        let area = CGRect(x: 200, y: 200, width: 300, height: 200)
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.count == 1)
        #expect(result[0].frame == area)
        #expect(result[0].originMoved == false)
    }

    @Test("Area partially outside window is clipped and origin shifted")
    func areaPartiallyOutsideWindowClipped() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area extends left beyond window boundary
        let area = CGRect(x: 50, y: 200, width: 400, height: 200)
        // intersection: x:100..450, y:200..400 = 350x200
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.count == 1)
        #expect(result[0].frame.origin.x == 100)  // clipped to window left
        #expect(result[0].frame.width == 350)
        #expect(result[0].frame.height == 200)
        #expect(result[0].originMoved == true)
    }

    @Test("Area partially outside without origin shift has originMoved=false")
    func areaClippedRightNoOriginMove() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area extends right beyond window boundary but origin is inside
        let area = CGRect(x: 200, y: 200, width: 800, height: 200)
        // intersection: x:200..900, y:200..400 = 700x200
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.count == 1)
        #expect(result[0].frame.origin.x == 200)
        #expect(result[0].frame.width == 700)
        #expect(result[0].originMoved == false)
    }

    @Test("Clipped area too small in width is excluded")
    func clippedAreaTooSmallWidthExcluded() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area's intersection width < 100
        let area = CGRect(x: 50, y: 200, width: 120, height: 300)
        // intersection: x:100..170, y:200..500 = 70x300 → width < 100 → excluded
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.isEmpty)
    }

    @Test("Clipped area too small in height is excluded")
    func clippedAreaTooSmallHeightExcluded() {
        let windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Area's intersection height < 100
        let area = CGRect(x: 200, y: 50, width: 300, height: 120)
        // intersection: x:200..500, y:100..170 = 300x70 → height < 100 → excluded
        let result = ScrollAreaFilter.filterByWindow(areas: [area], windowFrame: windowFrame)
        #expect(result.isEmpty)
    }

    @Test("Multiple areas: only valid ones are kept")
    func multipleAreasFilteredCorrectly() {
        let windowFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let areaInsideFrame = CGRect(x: 50, y: 50, width: 400, height: 300)
        let areaOutsideFrame = CGRect(x: 1100, y: 0, width: 200, height: 200)
        let result = ScrollAreaFilter.filterByWindow(areas: [areaInsideFrame, areaOutsideFrame], windowFrame: windowFrame)
        #expect(result.count == 1)
        #expect(result[0].originalFrame == areaInsideFrame)
    }

    // MARK: - removeOverlaps

    @Test("No overlapping areas: both kept")
    func noOverlapBothKept() {
        let area1 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originalFrame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originMoved: false
        )
        let area2 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 300, y: 300, width: 200, height: 200),
            originalFrame: CGRect(x: 300, y: 300, width: 200, height: 200),
            originMoved: false
        )
        let result = ScrollAreaFilter.removeOverlaps(areas: [area1, area2])
        #expect(result.count == 2)
    }

    @Test(">50% overlap, one originMoved: originMoved one excluded")
    func overlapOneOriginMovedExcluded() {
        let area1 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originalFrame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originMoved: false
        )
        // Overlaps heavily with area1, but its origin was moved (it's a partial clipped view)
        let area2 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 50, y: 50, width: 200, height: 200),
            originalFrame: CGRect(x: 50, y: 50, width: 200, height: 200),
            originMoved: true
        )
        // intersection: x:50..200, y:50..200 = 150x150 = 22500
        // area1 = 40000, area2 = 40000
        // ratio vs area1: 22500/40000 = 56.25% > 50% → overlap
        // area2 has originMoved → exclude area2
        let result = ScrollAreaFilter.removeOverlaps(areas: [area1, area2])
        #expect(result.count == 1)
        #expect(result[0].frame == area1.frame)
    }

    @Test(">50% overlap, both originMoved=false: smaller excluded")
    func overlapBothNotMovedSmallerExcluded() {
        let area1 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 0, y: 0, width: 300, height: 300),
            originalFrame: CGRect(x: 0, y: 0, width: 300, height: 300),
            originMoved: false
        )
        let area2 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 50, y: 50, width: 150, height: 150),
            originalFrame: CGRect(x: 50, y: 50, width: 150, height: 150),
            originMoved: false
        )
        // intersection = 150x150 = 22500
        // area2 = 22500 → ratio vs area2: 22500/22500 = 100% > 50% → overlap
        // both originMoved=false → exclude smaller (area2)
        let result = ScrollAreaFilter.removeOverlaps(areas: [area1, area2])
        #expect(result.count == 1)
        #expect(result[0].frame == area1.frame)
    }

    @Test("<50% overlap: both kept")
    func lessOverlapBothKept() {
        let area1 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originalFrame: CGRect(x: 0, y: 0, width: 200, height: 200),
            originMoved: false
        )
        let area2 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 150, y: 150, width: 200, height: 200),
            originalFrame: CGRect(x: 150, y: 150, width: 200, height: 200),
            originMoved: false
        )
        // intersection: x:150..200, y:150..200 = 50x50 = 2500
        // area1 = 40000, ratio = 2500/40000 = 6.25% < 50% → no overlap
        let result = ScrollAreaFilter.removeOverlaps(areas: [area1, area2])
        #expect(result.count == 2)
    }

    @Test("Three areas with chain overlap: correct exclusions")
    func threeAreasChainOverlap() {
        // area1 large, area2 inside area1, area3 separate
        let area1 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 0, y: 0, width: 400, height: 400),
            originalFrame: CGRect(x: 0, y: 0, width: 400, height: 400),
            originMoved: false
        )
        let area2 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 50, y: 50, width: 200, height: 200),
            originalFrame: CGRect(x: 50, y: 50, width: 200, height: 200),
            originMoved: false
        )
        let area3 = ScrollAreaFilter.FilteredArea(
            frame: CGRect(x: 600, y: 0, width: 200, height: 200),
            originalFrame: CGRect(x: 600, y: 0, width: 200, height: 200),
            originMoved: false
        )
        let result = ScrollAreaFilter.removeOverlaps(areas: [area1, area2, area3])
        // area2 overlaps >50% with area1 → smaller (area2) excluded
        // area3 no overlap with area1 → kept
        #expect(result.count == 2)
        let frames = result.map { $0.frame }
        #expect(frames.contains(area1.frame))
        #expect(frames.contains(area3.frame))
    }

    // MARK: - Integration: filterByWindow + removeOverlaps pipeline

    @Test("Full pipeline: filterByWindow then removeOverlaps produces correct output")
    func fullFilterPipelineProducesCorrectOutput() {
        // Simulate three scroll areas inside a window; one overlaps another heavily
        let windowFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)

        // area1: sidebar — fully inside window
        let frame1 = CGRect(x: 0, y: 0, width: 300, height: 800)
        // area2: main content — fully inside window
        let frame2 = CGRect(x: 300, y: 0, width: 900, height: 800)
        // area3: nearly identical to area2 (duplicate — should be removed by dedup)
        let frame3 = CGRect(x: 300, y: 0, width: 900, height: 800)

        let filtered = ScrollAreaFilter.filterByWindow(
            areas: [frame1, frame2, frame3],
            windowFrame: windowFrame
        )
        // All three pass the window filter (fully visible, large enough)
        #expect(filtered.count == 3)

        let deduped = ScrollAreaFilter.removeOverlaps(areas: filtered)
        // area3 is identical to area2 → 100% overlap → smaller (equal size → first one kept, second excluded)
        // Result: area1 and one of area2/area3
        #expect(deduped.count == 2)

        let resultFrames = deduped.map { $0.frame }
        #expect(resultFrames.contains(frame1))
        #expect(resultFrames.contains(frame2))
    }
}
