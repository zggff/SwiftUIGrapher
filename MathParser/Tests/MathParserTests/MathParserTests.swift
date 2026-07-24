import Testing

@testable import MathParser

@Test func tokenise() throws {
	let expected: [Token] = [
		.neg, .open, .value(10), .sub, .value(2), .close, .mul, .function("abs"), .open,
		.variable("x"), .close, .mul, .value(10), .sub, .value(1),
	]
	let s = "-(10-2)abs(x)10-1"
	let got = try s.tokenise()
	#expect(got == expected)

}

@Test func parseFailsWithNotEnoughTokens() {
	#expect(throws: Expr.ParseError.notEnoughTokens) {
		try Expr(parse: "1 + + 2")
	}
}

@Test func parseBasicExpressions() throws {
	let cases: [(String, Expr)] = [
		("1 + x", .binary(.add, .value(1), .variable("x"))),
		("abs(x)", .function("abs", .variable("x"))),
		("-abs(x)", .unary(.negate, .function("abs", .variable("x")))),
	]

	for (input, expected) in cases {
		#expect(try Expr(parse: input) == expected)
	}
}

@Test func parseNegationSimple() throws {
	let cases: [(String, Expr)] = [
		(
			"-abs(x) - 2",
			.binary(.subtract, .unary(.negate, .function("abs", .variable("x"))), .value(2))
		),
		("--x", .unary(.negate, .unary(.negate, .variable("x")))),
		("-x^2", .unary(.negate, .binary(.power, .variable("x"), .value(2)))),
		(
			"--x + -2",
			.binary(
				.add, .unary(.negate, .unary(.negate, .variable("x"))), .unary(.negate, .value(2)))
		),
	]

	for (input, expected) in cases {
		let got = try Expr(parse: input)
		#expect(got == expected)
	}
}

@Test func parseComplexExpression() async throws {
	let expected =
		Expr.binary(
			.multiply,
			.unary(
				.negate,
				.function(
					"abs",
					.binary(.power, .variable("x"), .value(2))
				)),
			.binary(
				.add,
				.binary(
					.add,
					.variable("x"),
					.variable("y"),
				),
				.binary(
					.multiply,
					.value(2),
					.variable("z")
				)
			)

		)
	let got = try Expr(parse: "-abs(x^2) * (x + y + 2 * z)")
	#expect(
		got == expected
	)
}
