import SwiftUI

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
