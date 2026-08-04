import Foundation
import simd

public struct FuncSignature: Hashable {
	let name: String
	let paramCount: Int
	public init(_ name: String, _ paramCount: Int) {
		self.name = name
		self.paramCount = paramCount
	}
}

extension String.StringInterpolation {
	mutating func appendInterpolation(_ value: FuncSignature) {
		var res = "\(value.name)("
		if value.paramCount > 0 { res += "_" }
		for _ in 1..<value.paramCount { res += ", _" }
		appendInterpolation(res + ")")
	}
}

public typealias Function = ([Double]) -> Double

public struct ExprEvaluator {
	public enum EvalError: Error, Equatable {
		case unknownFunction(String)
		case unknownVariable(String)
	}

	public var funcs: [FuncSignature: Function] = [:]
	public var vars: [String: Double] = [:]

	public init() {}
	public func withDefaultFuncs() -> Self {
		withFuncs([
			FuncSignature("abs", 1): { abs($0[0]) },
			FuncSignature("sqrt", 1): { sqrt($0[0]) },
			FuncSignature("log", 1): { log($0[0]) },
			FuncSignature("log2", 1): { log2($0[0]) },
			FuncSignature("log10", 1): { log10($0[0]) },
			FuncSignature("sin", 1): { sin($0[0]) },
			FuncSignature("cos", 1): { cos($0[0]) },
			FuncSignature("tan", 1): { tan($0[0]) },
		])
	}
	public func withDefaultConsts() -> Self {
		withConsts(["PI": .pi, "e": exp(1)])
	}

	public func withFuncs(_ funcs: [FuncSignature: Function]) -> Self {
		var new = self
		for (signature, function) in funcs {
			new.funcs[signature] = function
		}
		return new
	}
	public func withConsts(_ vars: [String: Double]) -> Self {
		var new = self
		for (name, value) in vars {
			new.vars[name] = value
		}
		return new
	}

	public func eval(_ expr: Expr, _ point: SIMD3<Double>) throws -> Double {
		return try eval(expr, ["x": point.x, "y": point.y, "z": point.z])
	}

	public func eval(_ expr: Expr, _ vars: [String: Double]) throws -> Double {
		let new = withConsts(vars)
		return try new.eval(expr)
	}

	public func eval(_ expr: Expr) throws -> Double {
		switch expr {
			case .binary(let bin, let l, let r):
				return try bin.eval(
					eval(l), eval(r))
			case .unary(let u, let v): return try u.eval(eval(v))
			case .value(let v): return v
			case .variable(let name):
				guard let v = vars[name] else {
					throw EvalError.unknownVariable(name)
				}
				return v
			case .function(let name, let values):
				let signature = FuncSignature(name, values.count)
				guard let fun = funcs[signature] else {
					throw EvalError.unknownFunction(name)
				}
				let values = try values.map { val in
					return try eval(val)
				}
				return fun(values)
		}
	}

	private func simplifyBinary(expr: Expr, op: Expr.BinaryOp, l: Expr, r: Expr) throws -> Expr {
		let l = try simplify(l)
		let r = try simplify(r)

		if case .value(let l) = l, case .value(let r) = r {
			return .value(op.eval(l, r))
		}
		if op == .multiply {
			if case .value(let l) = l, l == 0 { return .value(0) }
			if case .value(let r) = r, r == 0 { return .value(0) }
			if case .value(let l) = l, l == 1 { return r }
			if case .value(let r) = r, r == 1 { return l }
		} else if op == .divide {
			if l == r { return .value(1) }
		} else if op == .subtract {
			if l == r { return .value(0) }
		} else if op == .add {
			if case .value(let l) = l, l == 0 { return r }
			if case .value(let r) = r, r == 0 { return l }
		} else if op == .power {
			if case .value(let l) = l, l == 0 || l == 1 { return .value(l) }
			if case .value(let r) = r, r == 0 { return .value(1) }
			if case .value(let r) = r, r == 1 { return l }
		}

		return .binary(op, l, r)
	}

	public func simplify(_ expr: Expr) throws
		-> Expr
	{
		switch expr {
			case .binary(let op, let l, let r):
				return try simplifyBinary(expr: expr, op: op, l: l, r: r)
			case .unary(let op, let value):
				let v = try simplify(value)
				if case .value(let v) = v { return .value(op.eval(v)) }
				return .unary(op, v)

			case .function(let name, let values):
				let signature = FuncSignature(name, values.count)
				guard let fun = funcs[signature] else {
					throw EvalError.unknownFunction("\(signature)")
				}
				let values = try values.map { val in
					return try simplify(val)
				}
				let valuesResolved = values.compactMap { v in
					if case .value(let new) = v { return new } else { return nil }
				}
				if valuesResolved.count == values.count {
					return .value(fun(valuesResolved))
				}
				return .function(name, values)

			case .value, .variable: return expr
		}
	}

}
