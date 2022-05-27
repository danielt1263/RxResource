import RxSwift
import XCTest
@testable import RxResource

final class ResourcerTests: XCTestCase {
    func testBuild() throws {
		TestAsset.created = false
		var disposeCalled = false
		func mockDispose(testAsset: TestAsset) {
			XCTAssertEqual(testAsset.value, "example")
			disposeCalled = true
		}

		let resourceFactory = Resource.build(TestAsset(value: "example"), dispose: mockDispose)

		XCTAssertFalse(TestAsset.created) // creating the resource factory doesn't create the asset
		let resource = try resourceFactory()
		XCTAssert(TestAsset.created) // creating the resource does create the asset
		resource.dispose()
		XCTAssert(disposeCalled) // disposing the resource disposes the asset
	}

	func testObservableFactory() throws {
		TestAsset.created = false
		var generateCalled = false
		func mockGenerate(disposeBag: DisposeBag, testAsset: TestAsset) -> Observable<String> {
			generateCalled = true
			return .just(testAsset.value)
		}
		let observableFactory = Resource<TestAsset>.createObservable(mockGenerate(disposeBag:testAsset:))
		XCTAssertFalse(generateCalled) // creating the factory doesn't call the generator
		let resource = Resource(asset: TestAsset(value: "example1"), dispose: { _ in })
		let action = observableFactory(resource)
		XCTAssert(generateCalled) // calling the factory calls the generate function
		_ = action
			.subscribe(onNext: {
				XCTAssertEqual($0, "example1") // subscribing to the result subscribes to the generator output
			})
	}
}

class TestAsset {
	static var created = false
	let value: String
	init(value: String) {
		self.value = value
		TestAsset.created = true
	}
}
