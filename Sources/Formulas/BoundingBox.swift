import Render3D

struct BoundingBox: InstancedRenderable {
	var model: Matrix { Matrix.translation(pos) }

	let color: Vec4 = Vec4(0, 0, 0, 1)
	let size: Float
	let pos: Vec3

	func getMesh() throws -> some MeshSource {
		try MeshBuilder<UInt16>().create { ctx in
			ctx.fillColor = nil
			let color = Vec3(0.2, 0.2, 0.2)

			ctx.color = Vec4(color, 1.0)
			ctx.thickness = 0.01
			ctx.drawCube(center: Vec3(0, 0, 0), size: size)

			let dist: Float = size / 2

			ctx.color = Vec4(color, 0.1)
			ctx.drawQuad(
				Vec3(-dist, 0, -dist),
				Vec3(dist, 0, -dist),
				Vec3(dist, 0, dist),
				Vec3(-dist, 0, dist))

			let distInt = Int(dist) - 1
			for i in -distInt...distInt {
				ctx.color = Vec4(color, 0.4)
				ctx.thickness = 0.005
				ctx.drawLine(Vec3(Float(i), 0, -dist), Vec3(Float(i), 0, dist))
				ctx.drawLine(Vec3(-dist, 0, Float(i)), Vec3(dist, 0, Float(i)))
			}

			ctx.color = Vec4(color, 1)
			ctx.thickness = 0.05
			let radius: Float = 0.5
			ctx.drawLine(Vec3(-dist, 0, 0), Vec3(dist - radius, 0, 0))
			ctx.drawCone(from: Vec3(dist - radius, 0, 0), to: Vec3(dist, 0, 0), radius: radius / 2)

			ctx.drawLine(Vec3(0, -dist, 0), Vec3(0, dist - radius, 0))
			ctx.drawCone(from: Vec3(0, dist - radius, 0), to: Vec3(0, dist, 0), radius: radius / 2)

			ctx.drawLine(Vec3(0, 0, -dist), Vec3(0, 0, dist - radius))
			ctx.drawCone(from: Vec3(0, 0, dist - radius), to: Vec3(0, 0, dist), radius: radius / 2)

			ctx.color = Vec4(1, 0, 0, 1)
			ctx.thickness = 1
			let scale = Vec3(repeating: 0.3)
			let defaultTransform =
				Matrix.scale(scale) * Matrix.translation(Vec3(-0.5, -1, 0))

			try ctx.drawMesh(
				Character("X").getMesh(),
				transform: Matrix.translation(Vec3(dist + radius, 0, 0))
					* defaultTransform
			)

			try ctx.drawMesh(
				Character("Y").getMesh(),
				transform: Matrix.translation(Vec3(0, dist + radius, 0))
					* defaultTransform
			)

			try ctx.drawMesh(
				Character("Z").getMesh(),
				transform: Matrix.translation(Vec3(0, 0, dist + radius))
					* Matrix.rotation(around: Vec3(0, 1, 0), radians: Float(-90.degrees))
					* defaultTransform
			)

		}.getMesh()
	}
	let vertexColorType: Uniforms.VertexColorType = .useAsColor

	let meshId: Render3D.MeshID
}

extension MeshBuilder.Context {
	func drawCone(from a: Vec3, to b: Vec3, radius: Float, slices: Int = 10) {
		guard let color, let (p1, p2) = (b - a).perpendicularCross() else { return }
		for i in 0..<slices {
			let angle1 = Float.pi * 2 * Float(i) / Float(slices)
			let angle2 = Float.pi * 2 * Float(i + 1) / Float(slices)
			builder.addTriangle(
				a + radius * (sin(angle1) * p1 + cos(angle1) * p2),
				a + radius * (sin(angle2) * p1 + cos(angle2) * p2),
				b,
				color: color)
			builder.addTriangle(
				a + radius * (sin(angle1) * p1 + cos(angle1) * p2),
				a + radius * (sin(angle2) * p1 + cos(angle2) * p2),
				a,
				color: color)
		}
	}
}
