import XCTest

import XoodooTests
import XoodyakTests

var tests = [XCTestCaseEntry]()
tests += XoodooTests.__allTests()
tests += XoodyakTests.__allTests()

XCTMain(tests)
