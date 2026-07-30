import Inject
import MathParser
import Render3DViews
import SwiftUI

extension CGColor {
	var metalColor: Vec4? {
		guard self.numberOfComponents == 4, let colorComponents = self.components else {
			return nil
		}
		return Vec4(colorComponents.map { c in Float(c) })
	}
}

#if canImport(AppKit)
	public typealias NativeColor = NSColor
#elseif canImport(UiKit)
	public typealias NativeColor = UiColor
#endif

extension Color {
	var metalColor: Vec4? {
		let native = NativeColor(self)
		return Vec4(
			Float(native.redComponent),
			Float(native.greenComponent),
			Float(native.blueComponent),
			Float(native.alphaComponent),
		)
	}
}

@Observable
@MainActor
class MathFormula: Identifiable {
	public var cube: MarchingCubes? = nil
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
	var onNeedsRender: () -> Void
	var onDelete: () -> Void

	var body: some View {
		HStack {
			VStack(alignment: .center, spacing: 12) {
				Toggle("", isOn: $formula.display)
					.onChange(of: formula.display, onNeedsRender)
					.toggleStyle(.checkbox)
					.frame(width: 25, height: 25)
					.labelsHidden()
				ColorPicker("", selection: $formula.color, supportsOpacity: false)
					.labelsHidden()
					.scaleEffect(2.5)
					.frame(width: 25, height: 25)
					.clipShape(Circle())
					.contentShape(Circle())
					.onChange(of: formula.color, onNeedsRender)
			}
			VStack(alignment: .trailing) {
				HStack {
					if let error = formula.errorMessage {
						Text(error)
					}
					Button(
						role: .destructive, action: onDelete,
						label: { Label("trash", systemImage: "trash") }
					).labelStyle(.iconOnly)
				}

				TextField("Enter formula...", text: $formula.text)
					.textFieldStyle(.plain)
					.padding(4)
					.font(.title2)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(
								formula.errorMessage == nil ? Color.blue : Color.red,
								lineWidth: 2))
			}
		}
		.onChange(of: formula.revision, { onNeedsRender() })
		.padding(10)
		.border(Color.blue, width: 2)
	}
}

struct ResizableView<Content: View>: View {
	@State var width = CGFloat(300)
	@ViewBuilder var content: Content

	var body: some View {
		HStack(spacing: 0) {
			content
				.frame(width: width)
			Rectangle()
				.fill(Color.gray)
				.frame(width: 10)
				.contentShape(Rectangle())
				.gesture(
					DragGesture()
						.onChanged { value in
							width = max(200, width + value.translation.width)
						}
				)
		}.padding(0)
	}
}

struct ContentView: View {
	@ObserveInjection var redraw

	@State var formulas: [MathFormula] = [
		MathFormula(text: "x^2 + y^2 + z^2 - 4", bounds: -10...10)
	]
	@State var scene = Scene3D(additionalRenderGroups: [.wireframe, .noLight])
	let bounds: ClosedRange<Float> = -10...10

	private func setScene() {
		scene.draw { ctx in
			for f in formulas {
				if f.display, let c = f.cube {
					ctx.draw(c)
				}
			}
			ctx.draw(
				BoundingRectangle(
					min: Vec3(repeating: bounds.lowerBound),
					max: Vec3(repeating: bounds.upperBound), color: Vec4(0.5, 0.5, 0.5, 1)),
				in: .opaque
			)
		}
	}
	@State var cameraState = OrbitingCameraState(distance: 30)

	private func deleteFormula(_ formula: MathFormula) {
		formulas.removeAll { $0.id == formula.id }
		setScene()
	}

	var body: some View {
		HStack(spacing: 0) {
			ResizableView {
				List {
					ForEach(formulas) { formula in
						FormulaInput(
							formula: formula,
							onNeedsRender: { setScene() },
							onDelete: { deleteFormula(formula) }
						)
					}
					Button {
						formulas.append(MathFormula(text: "", bounds: bounds))
					} label: {
						Text("add").font(.title)
							.frame(maxWidth: .infinity)
					}
					.frame(maxWidth: .infinity)
					.buttonStyle(.bordered)

				}
			}
			OrbitingSceneView(scene: scene, cameraState: $cameraState)
		}
		.onAppear { setScene() }
		.padding()
		.enableInjection()
	}
}
