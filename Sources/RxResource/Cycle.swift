//
//  Cycle.swift
//
//  Created by Daniel Tartaglia on 27 May 2022.
//  Copyright © 2022 Daniel Tartaglia. MIT License.
//

import RxSwift

public typealias Effect<State, Input> = (Observable<(State, Input)>) -> Observable<Input>

public func cycle<State, Input>(
	inputs: [Observable<Input>],
	initialState: State,
	reduce: @escaping (inout State, Input) -> Void,
	effects: [Effect<State, Input>]
) -> Observable<State> {
	Observable.using(
		Resource.build(PublishSubject<Input>()),
		observableFactory: Resource.createObservable { disposeBag, subject in
			let outsideInputs = Observable.merge(inputs)
				.share(replay: 1)
			let inputs = Observable.merge(outsideInputs, subject.asObservable())
				.share(replay: 1)
			let state = inputs
				.scan(into: initialState, accumulator: reduce)
				.startWith(initialState)
				.share(replay: 1)

			Observable.merge(effects.map { $0(Observable.zip(state, inputs)) })
				.subscribe(subject)
				.disposed(by: disposeBag)

			return state
				.take(until: outsideInputs.materialize().takeLast(1))
		}
	)
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
				.take(until: sharedInput.takeLast(1))
				.share(replay: 1)
			effect(state)
				.subscribe(subject)
				.disposed(by: disposeBag)
			return state
		}
	)
}
