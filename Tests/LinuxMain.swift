import XCTest

import XoodooTests
import XoodyakTests

var tests = [XCTestCaseEntry]()
tests += XoodooTests.allTests()
tests += XoodyakTests.allTests()
XCTMain(tests)
