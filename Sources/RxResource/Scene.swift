//
//  Scene.swift
//
//  Created by Daniel Tartaglia on 19 May 2022.
//  Copyright © 2022 Daniel Tartaglia. MIT License.
//

import RxCocoa
import RxSwift
import UIKit

public extension NSObjectProtocol where Self: UIViewController {
	static func fromStoryboard(
		storyboardName: String = "",
		bundle: Bundle? = nil,
		identifier: String = ""
	) -> Self {
		let storyboard = UIStoryboard(
			name: storyboardName.isEmpty ? String(describing: self) : storyboardName,
			bundle: bundle
		)
		return identifier.isEmpty ?
		storyboard.instantiateInitialViewController() as! Self :
		storyboard.instantiateViewController(withIdentifier: identifier) as! Self
	}
}

public func scene<VC, Action>(
	disposeBag: DisposeBag,
	controller: VC,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> (controller: VC, action: Observable<Action>)
where VC: UIViewController {
	(controller, wrapAction(disposeBag: disposeBag, controller: controller, configure: configure))
}

public func presentScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from parent: UIViewController?,
	animated: Bool,
	over sourceView: UIView? = nil,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action>
where VC: UIViewController {
	Observable.using(
		Resource.build(
			PresentationCoordinator(parent: parent, child: controller(), sourceView: sourceView, animated: animated)
		),
		observableFactory: Resource.createObservable { disposeBag, state in
			guard let child = state.child else { return .empty() }
			return wrapAction(disposeBag: disposeBag, controller: child, configure: configure)
		}
	)
}

public func presentScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from parent: UIViewController?,
	animated: Bool,
	over barButtonItem: UIBarButtonItem,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	Observable.using(
		Resource.build(PresentationCoordinator(
			parent: parent,
			child: controller(),
			barButtonItem: barButtonItem,
			animated: animated
		)),
		observableFactory: Resource.createObservable { disposeBag, state in
			guard let child = state.child else { return .empty() }
			return wrapAction(disposeBag: disposeBag, controller: child, configure: configure)
		}
	)
}

public func pushScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from navigation: UINavigationController?,
	animated: Bool,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	Observable.using(
		Resource.build(NavigationCoordinator(navigation: navigation, controller: controller(), animated: animated)),
		observableFactory: Resource.createObservable { disposeBag, coordinator in
			guard let controller = coordinator.controller else { return .empty() }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
		}
	)
}

public func showScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from parent: UIViewController?,
	sender: Any? = nil,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	Observable.using(
		Resource.build(ShowCoordinator(
			parent: parent,
			child: controller(),
			sender: sender, show: parent?.show(_:sender:)
		)),
		observableFactory: Resource.createObservable { disposeBag, coordinator in
			guard let controller = coordinator.controller else { return .empty() }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
		}
	)
}

public func showDetailScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from parent: UIViewController?,
	sender: Any? = nil,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	Observable.using(
		Resource.build(ShowCoordinator(
			parent: parent,
			child: controller(),
			sender: sender,
			show: parent?.showDetailViewController(_:sender:)
		)),
		observableFactory: Resource.createObservable { disposeBag, coordinator in
			guard let controller = coordinator.controller else { return .empty() }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
		}
	)
}

class PresentationCoordinator<VC>: Disposable where VC: UIViewController {
	weak var parent: UIViewController?
	weak var child: VC?
	let animated: Bool

	init(parent: UIViewController?, child: VC, barButtonItem: UIBarButtonItem, animated: Bool) {
		self.parent = parent
		self.child = child
		self.animated = animated
		if let popoverPresentationController = child.popoverPresentationController {
			popoverPresentationController.barButtonItem = barButtonItem
		}
		parent?.present(child, animated: animated)
	}

	init(parent: UIViewController?, child: VC, sourceView: UIView?, animated: Bool) {
		self.parent = parent
		self.child = child
		self.animated = animated
		if let popoverPresentationController = child.popoverPresentationController,
		   let sourceView = sourceView {
			popoverPresentationController.sourceView = sourceView
			popoverPresentationController.sourceRect = sourceView.bounds
		}
		parent?.present(child, animated: animated)
	}

	func dispose() {
		guard let parent = parent, let child = child else { return }
		if parent.presentedViewController === child && !child.isBeingDismissed {
			parent.dismiss(animated: animated)
		}
	}
}

class NavigationCoordinator<VC>: Disposable where VC: UIViewController {
	weak var navigation: UINavigationController?
	weak var controller: VC?
	let animated: Bool

	init(navigation: UINavigationController?, controller: VC, animated: Bool) {
		self.navigation = navigation
		self.controller = controller
		self.animated = animated
		navigation?.pushViewController(controller, animated: animated)
	}

	func dispose() {
		if let navigation = navigation, let controller = controller,
		   let index = navigation.viewControllers.firstIndex(where: { $0 === controller }),
		   index > 0 {
			navigation.popToViewController(navigation.viewControllers[index - 1], animated: animated)
		}
	}
}

class ShowCoordinator<VC>: Disposable where VC: UIViewController {
	weak var controller: VC?

	init(parent: UIViewController?, child: VC, sender: Any?, show: ((UIViewController, Any?) -> Void)?) {
		self.controller = child
		show?(child, sender)
	}

	func dispose() {
		if let controller = controller, let navigation = controller.navigationController,
		   let index = navigation.viewControllers.firstIndex(where: { $0 === controller }),
		   index > 0 {
			navigation.popToViewController(navigation.viewControllers[index - 1], animated: true)
		}
	}
}

private func wrapAction<VC, Action>(
	disposeBag: DisposeBag,
	controller: VC,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action>
where VC: UIViewController {
	let action = Observable.merge(controller.rx.viewDidLoad, controller.isViewLoaded ? .just(()) : .empty())
		.take(1)
		.flatMap { [weak controller] in
			controller.map { configure(disposeBag, $0) } ?? Observable.empty()
		}
		.take(until: controller.rx.deallocating)
		.replay(1)
	action.connect()
		.disposed(by: disposeBag)
	return action
}

private extension Reactive where Base: UIViewController {
	var viewDidLoad: Observable<Void> {
		base.rx.methodInvoked(#selector(UIViewController.viewDidLoad))
			.map { _ in }
	}
}
