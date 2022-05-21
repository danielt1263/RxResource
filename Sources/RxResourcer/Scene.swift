//
//  Scene.swift
//  
//  Created by Daniel Tartaglia on 19 May 2022.
//  Copyright © 2021 Daniel Tartaglia. MIT License.
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

public func presentScene<VC, Action>(
	controller: @autoclosure @escaping () -> VC,
	from parent: UIViewController?,
	animated: Bool,
	over sourceView: UIView? = nil,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	Observable.using(
		Resource.resourceFactory(
			{ () -> VC in
				let control = controller()
				if let popoverPresentationController = control.popoverPresentationController,
				   let sourceView = sourceView {
					popoverPresentationController.sourceView = sourceView
					popoverPresentationController.sourceRect = sourceView.bounds
				}
				return control
			}(),
			dispose: { $0.parent?.dismiss(animated: animated) }
		),
		observableFactory: Resource.observableFactory { [weak parent] disposeBag, controller in
			defer { parent?.present(controller, animated: animated) }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
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
		Resource.resourceFactory(
			{ () -> VC in
				let control = controller()
				if let popoverPresentationController = control.popoverPresentationController {
					popoverPresentationController.barButtonItem = barButtonItem
				}
				return control
			}(),
			dispose: { $0.parent?.dismiss(animated: animated) }
		),
		observableFactory: Resource.observableFactory { [weak parent] disposeBag, controller in
			defer { parent?.present(controller, animated: animated) }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
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
		Resource.resourceFactory(controller(), dispose: { controller in
			if let navigation = controller.navigationController,
			   let index = navigation.viewControllers.firstIndex(of: controller), index > 0 {
				navigation.popToViewController(navigation.viewControllers[index - 1], animated: animated)
			}
		}),
		observableFactory: Resource.observableFactory { [weak navigation] disposeBag, controller in
			defer { navigation?.pushViewController(controller, animated: animated) }
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
		Resource.resourceFactory(controller(), dispose: { controller in
			if let navigation = controller.navigationController,
			   let index = navigation.viewControllers.firstIndex(of: controller), index > 0 {
				navigation.popToViewController(navigation.viewControllers[index - 1], animated: true)
			}
		}),
		observableFactory: Resource.observableFactory { [weak parent] disposeBag, controller in
			defer { parent?.show(controller, sender: sender) }
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
		Resource.resourceFactory(controller(), dispose: { controller in
			if let navigation = controller.navigationController,
			   let index = navigation.viewControllers.firstIndex(of: controller), index > 0 {
				navigation.popToViewController(navigation.viewControllers[index - 1], animated: true)
			}
		}),
		observableFactory: Resource.observableFactory { [weak parent] disposeBag, controller in
			defer { parent?.showDetailViewController(controller, sender: sender) }
			return wrapAction(disposeBag: disposeBag, controller: controller, configure: configure)
		}
	)
}

public func assignScene<VC, Action>(
	disposeBag: DisposeBag,
	controller: VC,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> (controller: VC, action: Observable<Action>) where VC: UIViewController {
	return (controller, wrapAction(disposeBag: disposeBag, controller: controller, configure: configure))
}

private func wrapAction<VC, Action>(
	disposeBag: DisposeBag,
	controller: VC,
	configure: @escaping (DisposeBag, VC) -> Observable<Action>
) -> Observable<Action> where VC: UIViewController {
	let action = controller.rx.viewDidLoad
		.take(1)
		.flatMap { [weak controller] () -> Observable<Action> in
			guard let controller = controller else { return .empty() }
			return configure(disposeBag, controller)
		}
		.take(until: controller.rx.deallocating)
		.publish()
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
