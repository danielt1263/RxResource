//
//  Cycle.swift
//
//  Created by Daniel Tartaglia on 27 May 2022.
//  Copyright © 2022 Daniel Tartaglia. MIT License.
//

import RxSwift

public typealias Reaction<State, Input> = (Observable<(State, Input)>) -> Observable<Input>

public func cycle<State, Input>(
	inputs: [Observable<Input>],
	initialState: State,
	reduce: @escaping (inout State, Input) -> Void,
	effects: [(Observable<(State, Input)>) -> Observable<Input>]
) -> Observable<State> {
	cycle(
		input: Observable.merge(inputs),
		logic: { input in
			let sharedInput = input
				.share(replay: 1)
			return Observable.zip(sharedInput.scan(into: initialState, accumulator: reduce), sharedInput)
		},
		effect: { action in
			Observable.merge(effects.map { $0(action) })
		})
		.map { $0.0 }
		.startWith(initialState)
}

public func cycle<Output, Input>(
	input: Observable<Input>,
	logic: @escaping (Observable<Input>) -> Observable<Output>,
	effect: @escaping (Observable<Output>) -> Observable<Input>
) -> Observable<Output> {
	Observable.using(
		Resource.build(PublishSubject<Input>()),
		observableFactory: Resource.createObservable { disposeBag, subject in
			let sharedInput = input
				.share(replay: 1)
			let state = logic(Observable.merge(sharedInput, subject))
				.share(replay: 1)
			effect(state)
				.take(until: sharedInput.takeLast(1))
				.observe(on: MainScheduler.asyncInstance)
				.subscribe(subject)
				.disposed(by: disposeBag)
			return state
		}
	)
}
