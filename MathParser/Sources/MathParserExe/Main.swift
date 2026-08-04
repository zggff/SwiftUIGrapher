import MathParser

// let input = "10x+abs(x)10x*1"
let input = "x - (1 - 2) + 2 - 4 - 4"

let expr = try Expr.parse(input)!
printExpr(expr)
let evaluator = ExprEvaluator().withDefaultFuncs().withDefaultConsts()

// evaluator.flatten(expr, direct: .add, inverse: .subtract)
// 	.forEach({ print($0) })
// let simplified = try evaluator.simplify(expr)
// print("--------------------------------")
// printExpr(simplified)

func printExpr(_ expr: Expr, depth: Int = 0) {
	for _ in 0..<depth {
		print("  ", terminator: "")
	}

	switch expr {
		case .value(let f):
			print(f)
			return
		case .variable(let s):
			print(s)
			return
		case .function(let name, let values):
			print("\(name)()")
			for val in values {
				printExpr(val, depth: depth + 1)
			}
		case .unary(_, let val):
			print("Neg")
			printExpr(val, depth: depth + 1)
		case .binary(let op, let l, let r):
			switch op {
				case .add: print("Add")
				case .subtract: print("Sub")
				case .multiply: print("Mul")
				case .divide: print("Div")
				case .power: print("Pow")

			}
			printExpr(l, depth: depth + 1)
			printExpr(r, depth: depth + 1)

	}
}
