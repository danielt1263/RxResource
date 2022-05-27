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
			input.scan(into: initialState, accumulator: reduce).startWith(initialState)
		},
		effect: { action in
			Observable.merge(effects.map { $0(action) })
		})
}

public func cycle<State, Input>(
	input: Observable<Input>,
	logic: @escaping (Observable<Input>) -> Observable<State>,
	effect: @escaping (Observable<(State, Input)>) -> Observable<Input>
) -> Observable<State> {
	Observable.using(
		Resource.build(PublishSubject<Input>()),
		observableFactory: Resource.createObservable { disposeBag, subject in
			let outsideInput = input
				.share(replay: 1)
			let allInputs = Observable.merge(outsideInput, subject)
				.take(until: outsideInput.takeLast(1))
				.share(replay: 1)
			let state = logic(allInputs)
				.share(replay: 1)
			let reactionInput = Observable.zip(state, allInputs)
			effect(reactionInput)
				.subscribe(subject)
				.disposed(by: disposeBag)
			return state
		})
}
