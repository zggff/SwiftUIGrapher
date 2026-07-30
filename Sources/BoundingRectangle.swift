import Render3D

public struct BoundingRectangle: InstancedRenderable {
	public var model: Render3D.Matrix { Matrix(1) }
	public let color: Render3D.Vec4

	public func mesh(for device: any MTLDevice) throws -> Render3D.Mesh? {
		return try Mesh(device, vertices: vertices, indices: indices)
	}

	public let meshId: MeshID
	private let vertices: [Vertex]
	private let indices: [UInt16]

	public init(min: Vec3, max: Vec3, color: Vec4, thickness: Float = 0.02) {
		self.color = color
		self.meshId = MeshID(rawValue: "volumetric_box_\(min)-\(max)-\(thickness)")

		let c0 = Vec3(min.x, min.y, min.z)
		let c1 = Vec3(max.x, min.y, min.z)
		let c2 = Vec3(max.x, max.y, min.z)
		let c3 = Vec3(min.x, max.y, min.z)
		let c4 = Vec3(min.x, min.y, max.z)
		let c5 = Vec3(max.x, min.y, max.z)
		let c6 = Vec3(max.x, max.y, max.z)
		let c7 = Vec3(min.x, max.y, max.z)

		let edgePairs: [(Vec3, Vec3)] = [
			(c0, c1), (c1, c2), (c2, c3), (c3, c0),
			(c4, c5), (c5, c6), (c6, c7), (c7, c4),
			(c0, c4), (c1, c5), (c2, c6), (c3, c7),
		]

		var builtVertices: [Vertex] = []
		var builtIndices: [UInt16] = []
		var indexOffset: UInt16 = 0

		for (pStart, pEnd) in edgePairs {
			let direction = normalize(pEnd - pStart)
			let arbitrary = abs(direction.y) > 0.9 ? Vec3(1, 0, 0) : Vec3(0, 1, 0)
			
			let perp1 = normalize(cross(direction, arbitrary)) * thickness
			let perp2 = normalize(cross(direction, perp1)) * thickness

			let offsets = [
				-perp1 - perp2,
				 perp1 - perp2,
				 perp1 + perp2,
				-perp1 + perp2
			]

			for offset in offsets {
				builtVertices.append(Vertex(position: pStart + offset))
				builtVertices.append(Vertex(position: pEnd + offset))
			}

			for i: UInt16 in 0..<4 {
				let next = (i + 1) % 4
				let s0 = indexOffset + i * 2
				let e0 = indexOffset + i * 2 + 1
				let s1 = indexOffset + next * 2
				let e1 = indexOffset + next * 2 + 1

				builtIndices.append(contentsOf: [
					s0, e0, e1,
					s0, e1, s1
				])
			}
			indexOffset += 8
		}

		self.vertices = builtVertices
		self.indices = builtIndices
	}
}
