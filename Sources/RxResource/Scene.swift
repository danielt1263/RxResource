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

	func action<Action>(
		disposeBag: DisposeBag,
		configure: @escaping (DisposeBag, Self) -> Observable<Action>
	) -> Observable<Action> {
		wrapAction(disposeBag: disposeBag, coordinator: StaticCoordinator(controller: self), configure: configure)
	}
}

extension UIViewController {
	public func present<VC, Action>(
		controller: @autoclosure @escaping () -> VC,
		animated: Bool,
		over sourceView: UIView? = nil,
		configure: @escaping (DisposeBag, VC) -> Observable<Action>
	) -> Observable<Action>
	where VC: UIViewController {
		Observable.using(
			Resource.build(
				PresentationCoordinator(
					parent: self,
					child: controller(),
					animated: animated,
					assignToPopover: sourceView.map { assignToPopover($0) }
				)
			),
			observableFactory: Resource.createObservable { disposeBag, coordinator in
				return wrapAction(disposeBag: disposeBag, coordinator: coordinator, configure: configure)
			}
		)
	}

	public func present<VC, Action>(
		controller: @autoclosure @escaping () -> VC,
		animated: Bool,
		over barButtonItem: UIBarButtonItem,
		configure: @escaping (DisposeBag, VC) -> Observable<Action>
	) -> Observable<Action> where VC: UIViewController {
		Observable.using(
			Resource.build(
				PresentationCoordinator(
					parent: self,
					child: controller(),
					animated: animated,
					assignToPopover: assignToPopover(barButtonItem)
				)
			),
			observableFactory: Resource.createObservable { disposeBag, coordinator in
				return wrapAction(disposeBag: disposeBag, coordinator: coordinator, configure: configure)
			}
		)
	}

	public func show<VC, Action>(
		controller: @autoclosure @escaping () -> VC,
		sender: Any? = nil,
		configure: @escaping (DisposeBag, VC) -> Observable<Action>
	) -> Observable<Action> where VC: UIViewController {
		Observable.using(
			Resource.build(ShowCoordinator(
				child: controller(),
				sender: sender,
				show: self.show(_:sender:)
			)),
			observableFactory: Resource.createObservable { disposeBag, coordinator in
				return wrapAction(disposeBag: disposeBag, coordinator: coordinator, configure: configure)
			}
		)
	}

	public func showDetail<VC, Action>(
		controller: @autoclosure @escaping () -> VC,
		sender: Any? = nil,
		configure: @escaping (DisposeBag, VC) -> Observable<Action>
	) -> Observable<Action> where VC: UIViewController {
		Observable.using(
			Resource.build(ShowCoordinator(
				child: controller(),
				sender: sender,
				show: self.showDetailViewController(_:sender:)
			)),
			observableFactory: Resource.createObservable { disposeBag, coordinator in
				return wrapAction(disposeBag: disposeBag, coordinator: coordinator, configure: configure)
			}
		)
	}
}

extension UINavigationController {
	public func push<VC, Action>(
		controller: @autoclosure @escaping () -> VC,
		animated: Bool,
		configure: @escaping (DisposeBag, VC) -> Observable<Action>
	) -> Observable<Action> where VC: UIViewController {
		Observable.using(
			Resource.build(NavigationCoordinator(navigation: self, controller: controller(), animated: animated)),
			observableFactory: Resource.createObservable { disposeBag, coordinator in
				return wrapAction(disposeBag: disposeBag, coordinator: coordinator, configure: configure)
			}
		)
	}
}

private protocol Coordinator: Disposable {
	associatedtype VC: UIViewController
	var controller: VC? { get }
}

private class StaticCoordinator<VC>: Coordinator where VC: UIViewController {
	weak var controller: VC?
	init(controller: VC) {
		self.controller = controller
	}

	func dispose() {
		controller = nil
	}
}

private class PresentationCoordinator<VC>: Coordinator where VC: UIViewController {
	weak var controller: VC?
	let animated: Bool

	init(parent: UIViewController?, child: VC, animated: Bool, assignToPopover: ((UIPopoverPresentationController) -> Void)?) {
		self.controller = child
		self.animated = animated
		queue.async { [weak parent] in
			let semaphore = DispatchSemaphore(value: 0)
			DispatchQueue.main.async {
				if let assignToPopover {
					child.modalPresentationStyle = .popover
					if let popoverPresentationController = child.popoverPresentationController {
						assignToPopover(popoverPresentationController)
					}
				}
				parent?.topMost().present(child, animated: animated, completion: {
					semaphore.signal()
				})
			}
			semaphore.wait()
		}
	}

	func dispose() {
		queue.async { [weak controller, animated] in
			let semaphore = DispatchSemaphore(value: 0)
			DispatchQueue.main.async {
				if let parent = controller?.presentingViewController, controller!.isBeingDismissed == false {
					parent.dismiss(animated: animated, completion: {
						semaphore.signal()
					})
				}
				else {
					semaphore.signal()
				}
			}
			semaphore.wait()
		}
	}
}

private let queue = DispatchQueue(label: "ScenePresentationHandler")

private class NavigationCoordinator<VC>: Coordinator where VC: UIViewController {
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

private class ShowCoordinator<VC>: Coordinator where VC: UIViewController {
	weak var controller: VC?

	init(child: VC, sender: Any?, show: ((UIViewController, Any?) -> Void)?) {
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

private func wrapAction<Coord, Action>(
	disposeBag: DisposeBag,
	coordinator: Coord,
	configure: @escaping (DisposeBag, Coord.VC) -> Observable<Action>
) -> Observable<Action>
where Coord: Coordinator {
	guard let controller = coordinator.controller else { return Observable.empty() }
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
		.do(
			onError: { _ in coordinator.dispose() },
			onCompleted: { coordinator.dispose() }
		)
}

private func assignToPopover(_ barButtonItem: UIBarButtonItem) -> (UIPopoverPresentationController) -> Void {
	{ popoverPresentationController in
		popoverPresentationController.barButtonItem = barButtonItem
	}
}

private func assignToPopover(_ sourceView: UIView) -> (UIPopoverPresentationController) -> Void {
	{ popoverPresentationController in
		popoverPresentationController.sourceView = sourceView
		popoverPresentationController.sourceRect = sourceView.bounds
	}
}

private extension UIViewController {
	func topMost() -> UIViewController {
		var result = self
		while let vc = result.presentedViewController, !vc.isBeingDismissed {
			result = vc
		}
		return result
	}
}

private extension Reactive where Base: UIViewController {
	var viewDidLoad: Observable<Void> {
		base.rx.methodInvoked(#selector(UIViewController.viewDidLoad))
			.map { _ in }
	}
}
