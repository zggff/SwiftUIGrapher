import MathParser
import SwiftUI

@Observable
@MainActor
class MathFormula: Identifiable {
	public var cube: MarchingCubes? = nil
	public let evaluator: ExprEvaluator = ExprEvaluator().withDefaultFuncs().withDefaultConsts()
	public var color: Color {
		didSet {
			if let cube, let color = color.metalColor {
				cube.color = color
			}
		}
	}
	public var bounds: ClosedRange<Float>
	public var display = true

	public var text: String {
		didSet { parse() }
	}
	public var errorMessage: String? = nil

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
			cube = nil
			self.revision += 1
			self.errorMessage = nil
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
				let f: MarchingCubes.Func = { point in try handler.eval(expr, at: point) }
				let newCube = try MarchingCubes(color: color, bounds: bounds, f: f, )
				try Task.checkCancellation()

				await MainActor.run {
					self.cube = newCube
					self.errorMessage = nil
					self.revision += 1
				}
			} catch is CancellationError {
			} catch {
				let message = "\(error)"

				if !Task.isCancelled {
					await MainActor.run {
						self.cube = nil
						self.errorMessage = message
						self.revision += 1
					}
				}
			}
		}
	}
}
