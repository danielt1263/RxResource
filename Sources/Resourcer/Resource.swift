import RxSwift

public final class Resource<Asset>: Disposable {
	public static func resourceFactory(
		_ asset: @autoclosure @escaping () throws -> Asset,
		dispose: @escaping (Asset) -> Void
	) -> () throws -> Resource<Asset> {
		{ Resource(asset: try asset(), dispose: dispose) }
	}

	public static func observableFactory<Action>(
		_ fn: @escaping (DisposeBag, Asset) -> Observable<Action>
	) -> (Resource<Asset>) -> Observable<Action> {
		{ resource in fn(resource.disposeBag, resource.asset) }
	}

	private let asset: Asset
	private let _dispose: (Asset) -> Void
	private let disposeBag = DisposeBag()

	public init(asset: Asset, dispose: @escaping (Asset) -> Void) {
		self.asset = asset
		self._dispose = dispose
	}

	public func dispose() {
		_dispose(asset)
	}
}
