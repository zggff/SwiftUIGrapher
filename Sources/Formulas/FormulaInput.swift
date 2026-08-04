import SwiftUI

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
