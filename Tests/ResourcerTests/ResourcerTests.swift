import RxSwift
import XCTest
@testable import Resourcer

final class ResourcerTests: XCTestCase {
    func testResourceFactory() throws {
		TestAsset.created = false
		var disposeCalled = false
		func mockDispose(testAsset: TestAsset) {
			XCTAssertEqual(testAsset.value, "example")
			disposeCalled = true
		}
		let resourceFactory = Resource.resourceFactory(TestAsset(value: "example"), dispose: mockDispose)
		XCTAssertFalse(TestAsset.created)
		let resource = try resourceFactory()
		XCTAssert(TestAsset.created)
		resource.dispose()
		XCTAssert(disposeCalled)
	}

	func testObservableFactory() throws {
		TestAsset.created = false
		var generateCalled = false
		func mockGenerate(disposeBag: DisposeBag, testAsset: TestAsset) -> Observable<String> {
			generateCalled = true
			return .just(testAsset.value)
		}
		let observableFactory = Resource<TestAsset>.observableFactory(mockGenerate(disposeBag:testAsset:))
		XCTAssertFalse(generateCalled)
		let resource = Resource(asset: TestAsset(value: "example1"), dispose: { _ in })
		let action = observableFactory(resource)
		XCTAssert(generateCalled)
		_ = action
			.subscribe(onNext: {
				XCTAssertEqual($0, "example1")
			})
	}
}

struct TestAsset: Equatable {
	static var created = false
	let value: String
	init(value: String) {
		self.value = value
		TestAsset.created = true
	}
}
