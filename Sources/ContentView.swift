import MathParser
import Render3DViews
import SwiftUI

@Observable
@MainActor
class MathFormula: Identifiable {
	public var cube: MarchingCubes? = nil
	public var color: Vec4
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
		var randColor = Vec4.random(in: 0...1)
		randColor.w = 1
		color = randColor
		parse()
	}

	public func parse() {
		parseTask?.cancel()

		let textToParse = text
		let color = self.color
		let bounds = self.bounds

		parseTask = Task.detached(priority: .userInitiated) {
			do {
				let handler = ExprEvaluator()
				let expr = try Expr(parse: textToParse)
				let f: MarchingCubes.Func = { f in try handler.eval(expr, at: f) }
				let newCube = try MarchingCubes(color: color, bounds: bounds, f: f, )
				try Task.checkCancellation()

				await MainActor.run {
					self.cube = newCube
					self.errorMessage = nil
					self.revision += 1
				}
			} catch is CancellationError {
			} catch {
				let message: String
				switch error {
					case Expr.ParseError.invalidIdentifier(let s):
						message = "invalid symbol: \(s)"
					case Expr.ParseError.mismatchedParenthesis:
						message = "parenthesis do not match"
					case Expr.EvalError.unknownFunction(let s):
						message = "unknown function: \(s)"
					case Expr.EvalError.unknownVariable(let s):
						message = "unknown variable: \(s)"
					default:
						message = "\(error)"
				}

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

struct FormulaInput: View {
	@Bindable var formula: MathFormula
	var onDelete: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Toggle("", isOn: $formula.display)
				TextField("Enter formula...", text: $formula.text)
					.textFieldStyle(.roundedBorder)
					.font(.title2)
				Button(
					role: .destructive, action: onDelete, label: { Text("Delete").font(.title2) })
			}

			if let error = formula.errorMessage {
				Text(error)
					.font(.title3)
					.foregroundColor(.red)
			} else {
				Text("Valid surface")
					.font(.title3)
					.foregroundColor(.secondary)
			}
		}
		.padding(.vertical, 4)
	}
}

struct ContentView: View {
	@State var formulas: [MathFormula] = []
	@State var scene = Scene3D()
	let bounds: ClosedRange<Float> = -10...10

	private func setScene() {
		let s = bounds.upperBound - bounds.lowerBound
		let c = bounds.lowerBound + (bounds.upperBound - bounds.lowerBound) / 2
		scene.draw { ctx in
			for f in formulas {
				if f.display, let c = f.cube {
					ctx.draw(c)
				}
			}
			ctx.draw(
				Primitive.Cube(
					center: Vec3(repeating: c),
					size: Vec3(repeating: s),
					color: Vec4(0.6, 0.6, 1.0, 0.2))
			)
		}
	}
	@State var cameraState = OrbitingCameraState(distance: 30)

	private func deleteFormula(_ formula: MathFormula) {
		formulas.removeAll { $0.id == formula.id }
		setScene()
	}

	var body: some View {
		HStack {
			VStack {
				Button {
					formulas.append(MathFormula(text: "", bounds: bounds))
				} label: {
					Text("add").font(.title)
				}
				.buttonStyle(.bordered)
				List {
					ForEach(formulas) { formula in
						FormulaInput(
							formula: formula,
							onDelete: { deleteFormula(formula) }
						)
					}
				}
			}
			.frame(width: 300)
			OrbitingSceneView(scene: scene, cameraState: $cameraState)
		}
		.onAppear { setScene() }
		.onChange(of: formulas.map { $0.revision }) {
			setScene()
		}
		.onChange(of: formulas.map { $0.display }) {
			setScene()
		}
		.padding()
	}
}
