import RxSwift

public final class Resource<Asset>: Disposable where Asset: AnyObject {
	public static func build(
		_ asset: @autoclosure @escaping () throws -> Asset,
		dispose: @escaping (Asset) -> Void
	) -> () throws -> Resource<Asset> {
		{ Resource(strongAsset: try asset(), weakAsset: nil, dispose: dispose) }
	}

	public static func buildWeak(
		_ asset: @escaping () throws -> Asset,
		dispose: @escaping (Asset) -> Void
	) -> () throws -> Resource<Asset> {
		{ Resource(strongAsset: nil, weakAsset: try asset(), dispose: dispose) }
	}

	public static func createObservable<Action>(
		_ fn: @escaping (DisposeBag, Asset) -> Observable<Action>
	) -> (Resource<Asset>) -> Observable<Action> {
		{ resource in
			guard let asset = resource.asset else { return .empty() }
			return fn(resource.disposeBag, asset)
		}
	}

	private let strongAsset: Asset?
	private weak var weakAsset: Asset?
	private let _dispose: (Asset) -> Void
	private let disposeBag = DisposeBag()

	private var asset: Asset? {
		weakAsset ?? strongAsset
	}

	private init(strongAsset: Asset?, weakAsset: Asset?, dispose: @escaping (Asset) -> Void) {
		self.strongAsset = strongAsset
		self.weakAsset = weakAsset
		self._dispose = dispose
	}

	public func dispose() {
		guard let asset = asset else { return }
		_dispose(asset)
	}
}
