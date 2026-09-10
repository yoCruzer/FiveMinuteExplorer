//
//  FiveMinuteExplorerUITests.swift
//  FiveMinuteExplorerUITests
//
//  Created by hanghang on 2026/9/7.
//

import XCTest

final class FiveMinuteExplorerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testStabilizationLargeTextFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-has-seen-intro-v0", "NO", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<8 {
                if element.isHittable { return }
                app.swipeUp()
            }
        }
        XCTAssertTrue(app.staticTexts["给我 5 分钟，让我重新看见这里"].waitForExistence(timeout: 10))
        capture("01-intro-large-text")
        let start = app.buttons["开始探索"]
        reveal(start)
        XCTAssertTrue(start.isHittable)
        capture("02-intro-start-reachable")
        start.tap()
        XCTAssertTrue(app.buttons["探索更多"].waitForExistence(timeout: 10))
        capture("03-home-large-text")
        app.buttons["探索更多"].tap()
        let listen = app.collectionViews.buttons["听一听"]
        reveal(listen)
        capture("04-library-categories")
        listen.tap()
        let quest = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-quest-")).firstMatch
        XCTAssertTrue(quest.waitForExistence(timeout: 5))
        capture("05-library-detail-large-text")
        quest.tap()
        XCTAssertTrue(app.buttons["不适合我"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        // Exercise the real >60-second Useful Exit without injecting app-only test state.
        Thread.sleep(forTimeInterval: 65)
        app.activate()
        let dismiss = app.buttons["暂不回答"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        capture("06-feedback-large-text")
        let notTried = app.buttons["没做"]
        reveal(notTried)
        XCTAssertTrue(notTried.isHittable)
        capture("07-feedback-answer-reachable")
        notTried.tap()
        XCTAssertTrue(app.buttons["探索更多"].waitForExistence(timeout: 5))
    }
}
