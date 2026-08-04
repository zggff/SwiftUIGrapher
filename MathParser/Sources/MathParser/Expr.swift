import Foundation

public indirect enum Expr: Equatable {
	case binary(BinaryOp, Expr, Expr)
	case unary(UnaryOp, Expr)
	case variable(String)
	case value(Double)
	case function(String, [Expr])

	public enum BinaryOp: Equatable {
		case add
		case subtract
		case multiply
		case divide
		case power
		var precedence: Int {
			switch self {
				case .add, .subtract: return 1
				case .multiply, .divide: return 2
				case .power: return 3
			}
		}
		func eval(_ a: Double, _ b: Double) -> Double {
			return switch self {
				case .add: a + b
				case .subtract: a - b
				case .multiply: a * b
				case .divide: a / b
				case .power: pow(a, b)
			}
		}
	}

	public enum UnaryOp: Equatable {
		case negate
		func eval(_ a: Double) -> Double {
			return switch self {
				case .negate: -a
			}
		}
	}
}
