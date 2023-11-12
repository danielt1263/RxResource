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
					state += "Hello "
				case .b:
					state += "World "
				}
			}
		}
		let effect: (Observable<(State)>) -> Observable<Input> = { request in
			request
				.flatMap { state -> Observable<Input> in
					guard state == "Hello World " else { return .empty() }
					return .just(Input.a)
						.delay(.seconds(5), scheduler: scheduler)
				}
		}

		let result = scheduler.start {
			cycle(input: input, logic: logic, effect: effect)
		}

		XCTAssertEqual(result.events, [
			.next(202, "Hello "),
			.next(203, "Hello World "),
			.next(208, "Hello World Hello ")
		])
	}

	func testReducer() {
		let scheduler = TestScheduler(initialClock: 0)
		let input = scheduler.createColdObservable([.next(2, Input.a), .next(3, Input.b)]).asObservable()
		func reduce(state: inout State, input: Input) {
			switch input {
			case .a:
				state += "Hello "
			case .b:
				state += "World "
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
			.next(200, ""),
			.next(202, "Hello "),
			.next(203, "Hello World "),
			.next(208, "Hello World Hello ")
		])
	}

	func test1() {
		let scheduler = TestScheduler(initialClock: 0)
		let input = scheduler.createColdObservable([.completed(1)]) as TestableObservable<String>
		let sut = cycle(
			inputs: [input.asObservable()],
			initialState: "X",
			reduce: { _, _ in
				XCTFail()
			},
			effects: [{ $0.flatMap { _, _ in
					XCTFail()
					return Observable<String>.empty()
				}
			}]
		)

		let result = scheduler.start { sut }

		XCTAssertEqual(result.events, [
			.next(200, "X"),
			.completed(201)
		])
	}

	func test2() {
		let scheduler = TestScheduler(initialClock: 0)
		let input = scheduler.createColdObservable([.next(2, "A"), .completed(2)])
		let args = scheduler.createObserver((String, String).self)
		let sut = cycle(
			inputs: [input.asObservable()],
			initialState: "X",
			reduce: { state, input in
				XCTAssertEqual(state, "X")
				XCTAssertEqual(input, "A")
				state = "Y"
			},
			effects: [{
				$0.flatMap {
					args.onNext($0)
					return scheduler.createColdObservable([.completed(1)]) as TestableObservable<String>
				}
			}]
		)

		let result = scheduler.start { sut }

		XCTAssertEqual(args.events.map { $0.map { $0.map { $0.0 } } }, [
			.next(202, "X")
		])
		XCTAssertEqual(args.events.map { $0.map { $0.map { $0.1 } } }, [
			.next(202, "A")
		])
		XCTAssertEqual(result.events, [
			.next(200, "X"),
			.next(202, "Y"),
			.completed(202)
		])
	}

}

enum Input {
	case a
	case b
}

typealias State = String

extension Recorded {
	func map<T>(_ fn: (Value) -> T) -> Recorded<T> {
		Recorded<T>(time: time, value: fn(value))
	}
}
