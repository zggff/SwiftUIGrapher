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

	public func parse() {
		parseTask?.cancel()
		guard let color = color.metalColor else { return }
		guard !text.isEmpty else {
			state = .none
			self.revision += 1
			return
		}

		let textToParse = text
		let bounds = self.bounds

		let handler = evaluator
		parseTask = Task.detached(priority: .userInitiated) {
			do {
				guard let expr = try Expr.parse(textToParse) else {
					return
				}
				let simplified = try handler.simplify(expr)
				if case .value(let val) = simplified {
					await MainActor.run {
						self.state = .value(val)
						self.revision += 1
					}
					return
				}

				let f: MarchingCubes.Func = { point in try handler.eval(expr, at: point) }
				let newCube = try MarchingCubes(color: color, bounds: bounds, f: f, )
				try Task.checkCancellation()

				await MainActor.run {
					self.state = .mesh(newCube)
					self.revision += 1
				}
			} catch is CancellationError {
			} catch {
				if !Task.isCancelled {
					await MainActor.run {
						self.state = .error("\(error)")
						self.revision += 1
					}
				}
			}
		}
	}
}
