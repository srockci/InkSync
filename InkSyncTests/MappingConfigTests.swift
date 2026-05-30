import XCTest
@testable import InkSync

final class MappingConfigTests: XCTestCase {
    func testAddMappingNew() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")

        XCTAssertEqual(config.lists(for: "dev1"), ["list1"])
        XCTAssertEqual(config.device(for: "list1"), "dev1")
    }

    func testAddMappingDuplicateListToDifferentDevice() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")
        config.addMapping(deviceId: "dev2", listId: "list1")

        XCTAssertNil(config.device(for: "list1"))
        XCTAssertTrue(config.lists(for: "dev1").isEmpty)
        XCTAssertEqual(config.lists(for: "dev2"), ["list1"])
    }

    func testAddMappingSameDeviceSameList() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")
        config.addMapping(deviceId: "dev1", listId: "list1")

        XCTAssertEqual(config.lists(for: "dev1"), ["list1"])
        XCTAssertEqual(config.device(for: "list1"), "dev1")
    }

    func testAddMappingMultipleListsToDevice() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")
        config.addMapping(deviceId: "dev1", listId: "list2")
        config.addMapping(deviceId: "dev1", listId: "list3")

        XCTAssertEqual(config.lists(for: "dev1"), ["list1", "list2", "list3"])
        XCTAssertEqual(config.device(for: "list1"), "dev1")
        XCTAssertEqual(config.device(for: "list2"), "dev1")
        XCTAssertEqual(config.device(for: "list3"), "dev1")
    }

    func testRemoveMapping() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")

        config.removeMapping(deviceId: "dev1", listId: "list1")

        XCTAssertTrue(config.lists(for: "dev1").isEmpty)
        XCTAssertNil(config.device(for: "list1"))
    }

    func testRemoveMappingCleansUpDeviceIfEmpty() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")

        config.removeMapping(deviceId: "dev1", listId: "list1")

        XCTAssertNil(config.deviceToLists["dev1"])
    }

    func testUnassignedLists() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")

        let allLists = ["list1", "list2", "list3"]
        let unassigned = config.unassignedLists(allListIds: allLists)

        XCTAssertEqual(unassigned, ["list2", "list3"])
    }

    func testUnassignedListsAllAssigned() {
        var config = MappingConfig()
        config.addMapping(deviceId: "dev1", listId: "list1")
        config.addMapping(deviceId: "dev2", listId: "list2")

        let allLists = ["list1", "list2"]
        let unassigned = config.unassignedLists(allListIds: allLists)

        XCTAssertTrue(unassigned.isEmpty)
    }

    func testUnassignedListsNoMappings() {
        var config = MappingConfig()

        let allLists = ["list1", "list2", "list3"]
        let unassigned = config.unassignedLists(allListIds: allLists)

        XCTAssertEqual(unassigned, ["list1", "list2", "list3"])
    }

    func testListsForUnknownDevice() {
        var config = MappingConfig()

        XCTAssertTrue(config.lists(for: "unknown").isEmpty)
    }

    func testDeviceForUnknownList() {
        var config = MappingConfig()

        XCTAssertNil(config.device(for: "unknown"))
    }
}