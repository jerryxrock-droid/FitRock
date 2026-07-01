import XCTest

final class FitRockUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--accept-privacy-consent", "--skip-onboarding", "--reset-ui-data"]
        app.launch()
    }

    func testFirstLaunchRequiresPrivacyConsentBeforeOnboarding() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-onboarding", "--reset-ui-data", "--reset-privacy-consent"]
        app.launch()

        XCTAssertTrue(app.staticTexts["隐私政策与训练免责声明"].waitForExistence(timeout: 5))
        let continueButton = app.buttons["同意并继续"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertFalse(continueButton.isEnabled)

        app.buttons["我已阅读并同意隐私政策和训练免责声明"].tap()
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["快速记录每一组"].waitForExistence(timeout: 5))
    }

    func testFirstLaunchOnboardingStartsFirstWorkout() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--accept-privacy-consent", "--reset-onboarding", "--reset-ui-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["快速记录每一组"].waitForExistence(timeout: 5))
        for _ in 0..<3 {
            waitAndTap("继续")
        }
        XCTAssertTrue(app.staticTexts["每周灵活完成计划"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "第 1 练")).firstMatch.waitForExistence(timeout: 5))
        waitAndTap("继续")
        waitAndTap("开始第一次训练")
        XCTAssertTrue(app.tabBars.buttons["训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["训练"].waitForExistence(timeout: 5) || app.staticTexts["训练"].waitForExistence(timeout: 5))
    }

    func testSettingsCanReplayOnboarding() {
        app.tabBars.buttons["统计"].tap()
        app.navigationBars.buttons["设置"].tap()
        waitAndTap("查看新手引导")
        XCTAssertTrue(app.staticTexts["快速记录每一组"].waitForExistence(timeout: 5))
    }

    func testSettingsShowsPrivacyAndDisclaimer() {
        app.tabBars.buttons["统计"].tap()
        app.navigationBars.buttons["设置"].tap()

        waitAndTap("重新查看隐私条款")
        XCTAssertTrue(app.staticTexts["隐私政策与训练免责声明"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["查看完整隐私政策"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["设置"].tap()

        waitAndTap("隐私与健康数据")
        XCTAssertTrue(app.staticTexts["本地优先"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["不用于广告"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["设置"].tap()

        waitAndTap("训练免责声明")
        XCTAssertTrue(app.staticTexts["训练建议性质"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["必要时咨询专业人士"].waitForExistence(timeout: 5))
    }

    func testLaunchAndTabNavigation() {
        XCTAssertTrue(app.tabBars.buttons["日历"].waitForExistence(timeout: 5))

        for tab in ["日历", "训练", "动作库", "统计"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2) || app.staticTexts[tab].waitForExistence(timeout: 2))
        }
    }

    func testWorkoutSmokeFlow() {
        app.tabBars.buttons["训练"].tap()
        tapIfExists("放弃")
        if app.buttons["开始自由训练"].waitForExistence(timeout: 1) {
            app.buttons["开始自由训练"].tap()
        } else {
            tapIfExists("开始训练")
        }
        waitAndTap("添加动作")
        if app.searchFields.firstMatch.waitForExistence(timeout: 3) {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("卧推")
        }
        tapButtonOrText("杠铃卧推")
        XCTAssertTrue(app.staticTexts["杠铃卧推"].waitForExistence(timeout: 5))
        app.staticTexts["杠铃卧推"].tap()
        waitAndTap("添加一组")

        XCTAssertTrue(app.staticTexts["杠铃卧推"].waitForExistence(timeout: 5))
    }

    func testExerciseLibraryFlow() {
        app.tabBars.buttons["动作库"].tap()
        if app.buttons["器械"].waitForExistence(timeout: 3) {
            app.buttons["器械"].tap()
        }
        if app.searchFields.firstMatch.waitForExistence(timeout: 3) {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("Smith")
        }
        XCTAssertTrue(app.staticTexts.matching(identifier: "史密斯机").firstMatch.waitForExistence(timeout: 5) || app.staticTexts["史密斯机"].waitForExistence(timeout: 5))
    }

    func testWorkoutCanSearchEquipmentCatalogExercise() {
        app.tabBars.buttons["训练"].tap()
        if app.buttons["开始自由训练"].waitForExistence(timeout: 1) {
            app.buttons["开始自由训练"].tap()
        }
        waitAndTap("添加动作")
        if app.searchFields.firstMatch.waitForExistence(timeout: 3) {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("划船机")
        }
        XCTAssertTrue(app.staticTexts["器械教学"].waitForExistence(timeout: 5))
    }

    func testStatsScreenDoesNotCrash() {
        app.tabBars.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["统计"].waitForExistence(timeout: 5) || app.staticTexts["统计"].waitForExistence(timeout: 5))
    }

    func testEmptyStatsDoesNotShowSamplePreview() {
        app.tabBars.buttons["统计"].tap()
        XCTAssertTrue(app.staticTexts["计划复盘"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["示例预览"].exists)
        XCTAssertFalse(app.staticTexts["示例 4 周增肌计划"].exists)
    }

    func testStatsPlanAndHeatmapSectionsExist() {
        app.tabBars.buttons["统计"].tap()
        XCTAssertTrue(app.staticTexts["肌肉热力图"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["计划复盘"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["本周"].exists)
        XCTAssertFalse(app.buttons["本月"].exists)
        XCTAssertFalse(app.staticTexts["训练历史"].exists)
        XCTAssertFalse(app.buttons["生成计划"].exists)
        XCTAssertFalse(app.buttons["调整计划"].exists)
        XCTAssertFalse(app.staticTexts["动作排行榜"].exists)
    }

    func testCalendarShowsRecentWorkoutsEntryByDefault() {
        app.tabBars.buttons["日历"].tap()
        XCTAssertTrue(app.staticTexts["最近训练"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["训练历史"].exists)
    }

    func testTrainingPlanUsesWeeklyPoolEntry() {
        app.tabBars.buttons["训练"].tap()
        XCTAssertFalse(app.staticTexts["还没有训练计划"].exists)
        if app.buttons["训练管理"].waitForExistence(timeout: 3) {
            app.buttons["训练管理"].tap()
            XCTAssertTrue(app.navigationBars["训练管理"].waitForExistence(timeout: 5))
            if app.buttons["训练计划"].waitForExistence(timeout: 2) {
                app.buttons["训练计划"].tap()
            }
            XCTAssertTrue(app.staticTexts["还没有训练计划"].waitForExistence(timeout: 5))
            waitAndTapFirstHittableButton("按计划偏好生成4周计划")
            waitAndTap("关闭")
        }

        XCTAssertTrue(app.staticTexts["本周计划"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["开始推荐训练"].waitForExistence(timeout: 5))
    }

    func testTrainingManagementShowsTemplatesPlanAndPreferences() {
        app.tabBars.buttons["训练"].tap()
        waitAndTap("训练管理")
        XCTAssertTrue(app.navigationBars["训练管理"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["模板"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["训练计划"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["计划偏好"].waitForExistence(timeout: 5))
        app.buttons["计划偏好"].tap()
        XCTAssertTrue(app.staticTexts["动作控制"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["轮换与补强"].waitForExistence(timeout: 5))
    }

    func testExerciseHistoryEntryExistsFromLibrary() {
        app.tabBars.buttons["动作库"].tap()
        if app.searchFields.firstMatch.waitForExistence(timeout: 3) {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("卧推")
        }
        if app.staticTexts["杠铃卧推"].waitForExistence(timeout: 5) {
            app.staticTexts["杠铃卧推"].tap()
            XCTAssertTrue(app.staticTexts["动作历史"].waitForExistence(timeout: 5))
        }
    }

    private func waitAndTap(_ label: String) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(label)")
        button.tap()
    }

    private func tapIfExists(_ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 1) {
            button.tap()
        }
    }

    private func tapButtonOrText(_ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }

        let text = app.staticTexts[label]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Missing button or text: \(label)")
        text.tap()
    }

    private func waitAndTapFirstHittableButton(_ label: String) {
        let query = app.buttons.matching(identifier: label)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 5), "Missing button: \(label)")
        for index in 0..<query.count {
            let button = query.element(boundBy: index)
            if button.isHittable {
                button.tap()
                return
            }
        }
        XCTFail("No hittable button: \(label)")
    }
}
