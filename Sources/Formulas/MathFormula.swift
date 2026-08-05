import MathParser
import SwiftUI

@Observable
@MainActor
class MathFormula: Identifiable {
	enum State {
		case none
		case error(String)
		case value(Double)
		case mesh(MarchingCubes)
		case assignment(Expr)

		var isError: Bool {
			if case .error = self { return true }
			return false
		}
		var cube: MarchingCubes? {
			if case .mesh(let c) = self { return c }
			return nil
		}
	}

	public var state: State = .none

	public let evaluator: ExprEvaluator = ExprEvaluator().withDefaultFuncs().withDefaultConsts()

	public var color: Color {
		didSet {
			if case .mesh(var cube) = state, let color = color.metalColor {
				cube.color = color
			}
		}
	}

	public var bounds: ClosedRange<Float>
	public var display = true

	public var text: String {
		didSet { parse() }
	}

	private func setState(_ newState: State = .none) {
		self.state = newState
		self.revision += 1
	}

	public private(set) var revision: Int = 0
	private var parseTask: Task<Void, Never>?

	public init(text: String, bounds: ClosedRange<Float>) {
		self.text = text
		self.bounds = bounds
		color = Color(
			red: Double.random(in: 0...1), green: Double.random(in: 0...1),
			blue: Double.random(in: 0...1),
		)
		parse()
	}

	private func createCube(expr: Expr) {
		guard let color = color.metalColor else { return }
		let evaluator = self.evaluator
		let bounds = self.bounds
		parseTask = Task.detached(priority: .userInitiated) {
			do {
				let simplified = try evaluator.simplify(expr)
				if case .value(let val) = simplified {
					await MainActor.run {
						self.state = .value(val)
						self.revision += 1
					}
					return
				}

				if case .value(let val) = simplified {
					await MainActor.run {
						self.state = .value(val)
						self.setState()
					}
					return
				}

				let f: MarchingCubes.Func = { point in try evaluator.eval(expr, at: point) }
				let newCube = try MarchingCubes(color: color, bounds: bounds, f: f, )
				try Task.checkCancellation()

				await MainActor.run {
					self.setState(.mesh(newCube))
				}
			} catch is CancellationError {
			} catch {
				if !Task.isCancelled {
					await MainActor.run {
						self.setState(.error("\(error)"))
					}
				}
			}
		}
	}

	public func handleStatement(text: String) throws {
		return try createCube(expr: Expr.parse(text))
	}

	public func handleAssignment() throws {
		let parts = try text.split(separator: "=").map(String.init).map(Expr.parse)
		guard parts.count == 2 else {
			return setState(.error("assignment must have two parts"))
		}
		if case .value(let x) = parts[0], case .value(let y) = parts[1], x != y {
			return setState(.error("left is not equal to right"))
		}
		if parts[0] == parts[1] {
			return setState(.error("parts cannot be equal"))
		}

		return createCube(expr: .binary(.subtract, parts[0], parts[1]))
	}

	public func parse() {
		parseTask?.cancel()

		guard !text.isEmpty else {
			return setState()
		}
		do {
			if text.contains("=") {
				try handleAssignment()
			} else {
				try handleStatement(text: text)
			}
		} catch {
			return setState(.error(error.localizedDescription))
		}
	}
}
