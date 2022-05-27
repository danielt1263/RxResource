//
//  CycleTests.swift
//  
//
//  Created by Daniel Tartaglia on 5/27/22.
//

import RxSwift
import RxTest
import XCTest
import RxResource

class CycleTests: XCTestCase {
	func test() {
		let scheduler = TestScheduler(initialClock: 0)
		let input = scheduler.createColdObservable([.next(2, Input.a), .next(3, Input.b)]).asObservable()
		func logic(input: Observable<Input>) -> Observable<State> {
			input.scan(into: State()) { state, input in
				switch input {
				case .a:
					state.word += "Hello "
				case .b:
					state.word += "World "
				}
			}
		}
		let effect: (Observable<(State, Input)>) -> Observable<Input> = { request in
			request
				.flatMap { (state, input) -> Observable<Input> in
					guard input == .b else { return .empty() }
					return .just(Input.a)
						.delay(.seconds(5), scheduler: scheduler)
				}
		}

		let result = scheduler.start {
			cycle(input: input, logic: logic, effect: effect)
		}

		XCTAssertEqual(result.events, [
			.next(202, State(word: "Hello ")),
			.next(203, State(word: "Hello World ")),
			.next(208, State(word: "Hello World Hello "))
		])
	}

	func testFormatted() {
		let scheduler = TestScheduler(initialClock: 0)
		let input = scheduler.createColdObservable([.next(2, Input.a), .next(3, Input.b)]).asObservable()
		func reduce(state: inout State, input: Input) {
			switch input {
			case .a:
				state.word += "Hello "
			case .b:
				state.word += "World "
			}
		}
		let effect: (Observable<(State, Input)>) -> Observable<Input> = { request in
			request
				.flatMap { (state, input) -> Observable<Input> in
					guard input == .b else { return .empty() }
					return .just(Input.a)
						.delay(.seconds(5), scheduler: scheduler)
				}
		}

		let result = scheduler.start {
			cycle(inputs: [input], initialState: State(), reduce: reduce(state:input:), effects: [effect])
		}

		XCTAssertEqual(result.events, [
			.next(200, State(word: "")),
			.next(202, State(word: "Hello ")),
			.next(203, State(word: "Hello World ")),
			.next(208, State(word: "Hello World Hello "))
		])
	}
}

enum Input {
	case a
	case b
}

struct State: Equatable {
	var word: String = ""
}
