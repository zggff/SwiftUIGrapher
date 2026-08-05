import Inject
import Render3DViews
import SwiftUI
import MathParser

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

struct ContentView: View {
	@ObserveInjection var redraw

	@State var formulas: [MathFormula] = [
		MathFormula(text: "x^2 + y^2 + z^2 - 4", bounds: -10...10)
	]
    var mathEvaluator: ExprEvaluator = ExprEvaluator().withDefaultFuncs().withDefaultConsts()

	@State var scene = Scene3D().withGroup(.opaque).withGroup(.wireframe).withGroup(.transparent)
	let bounds: ClosedRange<Float> = -10...10

	private func setScene() {
		scene.draw { ctx in
			try ctx.draw(formulas.filter(\.display).compactMap(\.state.cube)).in(.opaque)
			try ctx.draw(
				BoundingBox(
					size: bounds.upperBound - bounds.lowerBound, pos: Vec3(0, 0, 0),
					meshId: "BoundingBox")
			)
			.in(.opaque).in(.transparent)
		}
	}
	@State var cameraState = OrbitingCameraState(yaw: 45, pitch: 30, distance: 30, )

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
