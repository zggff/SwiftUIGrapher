import Foundation
import simd

// public struct Expression {
// 	public var expr: Expr
// 	public var variables: [String]
// 	public var functions: [String]
	// public init(from str: String) throws {
	// 	let tokens = try str.tokenise()
	// }
// }

public struct ExprEvaluator {
	public var funcs: [String: (Float) -> Float] = [:]
	public init(funcs: [String: (Float) -> Float] = [:]) {
		self.funcs["abs"] = abs
		self.funcs["sqrt"] = sqrt
		self.funcs["log"] = log
		self.funcs["log2"] = log2
		self.funcs["log10"] = log10
        self.funcs["sin"] = sin
        self.funcs["cos"] = cos 
        self.funcs["tan"] = tan

		for (name, f) in funcs {
			self.funcs[name] = f
		}
	}
	public func simplify(expr: Expr) throws -> Expr {
		return try expr.simplify(with: funcs)
	}
	public func eval(_ expr: Expr, at p: SIMD3<Float>) throws -> Float {
		let vars = ["x": p.x, "y": p.y, "z": p.z]
		return try expr.eval(for: vars, with: funcs)
	}
}

public enum BinaryOp: Equatable {
	case add
	case subtract
	case multiply
	case divide
	case power
	func eval(_ a: Float, _ b: Float) -> Float {
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
	func eval(_ a: Float) -> Float {
		return switch self {
			case .negate: -a
		}
	}
}

public indirect enum Expr: Equatable {
	public enum ParseError: Error, Equatable {
		case mismatchedParenthesis
		case notEnoughTokens
		case tooManyTokens
		case invalidIdentifier(String)
	}
	public enum EvalError: Error, Equatable {
		case unknownFunction(String)
		case unknownVariable(String)
	}

	case binary(BinaryOp, Expr, Expr)
	case unary(UnaryOp, Expr)

	case variable(String)
	case value(Float)
	case function(String, Expr)

	public func simplify(with funcs: [String: (Float) -> Float]) throws
		-> Expr
	{
		switch self {
			case .binary(let bin, let l, let r):
				let lS = try l.simplify(with: funcs)
				let rS = try r.simplify(with: funcs)
				if case .value(let lV) = lS, case .value(let rV) = rS {
					return .value(bin.eval(lV, rV))
				}
				return .binary(bin, lS, rS)
			case .unary(let u, let v):
				let vS = try v.simplify(with: funcs)
				if case .value(let vV) = vS { return .value(u.eval(vV)) }
				return .unary(u, vS)

			case .function(let name, let v):
				guard let fun = funcs[name] else {
					throw EvalError.unknownFunction(name)
				}
				let vS = try v.simplify(with: funcs)
				if case .value(let vV) = vS { return .value(fun(vV)) }
				return .function(name, vS)
			case .value, .variable: return self
		}
	}

	public func eval(for vars: [String: Float], with funcs: [String: (Float) -> Float]) throws
		-> Float
	{
		switch self {
			case .binary(let bin, let l, let r):
				return try bin.eval(
					l.eval(for: vars, with: funcs), r.eval(for: vars, with: funcs))
			case .unary(let u, let v): return try u.eval(v.eval(for: vars, with: funcs))

			case .value(let v): return v
			case .variable(let name):
				guard let v = vars[name] else {
					throw EvalError.unknownVariable(name)
				}
				return v
			case .function(let name, let v):
				guard let fun = funcs[name] else {
					throw EvalError.unknownFunction(name)
				}
				return try fun(v.eval(for: vars, with: funcs))
		}
	}

	public init(parse s: String) throws {
		let tokens = try s.tokenise().shunt()
		try self.init(tokens: tokens)
	}

	init(tokens: [Token]) throws {
		var stack: [Expr] = []
		func pop() throws -> Expr {
			guard let op = stack.popLast() else {
				throw Expr.ParseError.notEnoughTokens
			}
			return op
		}

		for tok in tokens {
			switch tok {
				case .variable(let s):
					stack.append(.variable(s))
				case .value(let f):
					stack.append(.value(f))
				case .sub:
					let b = try pop()
					let a = try pop()
					stack.append(.binary(.subtract, a, b))
				case .add:
					let b = try pop()
					let a = try pop()
					stack.append(.binary(.add, a, b))
				case .mul:
					let b = try pop()
					let a = try pop()
					stack.append(.binary(.multiply, a, b))
				case .div:
					let b = try pop()
					let a = try pop()
					stack.append(.binary(.divide, a, b))
				case .pow:
					let b = try pop()
					let a = try pop()
					stack.append(.binary(.power, a, b))
				case .function(let name):
					let op = try pop()
					stack.append(.function(name, op))
				case .neg:
					let a = try pop()
					stack.append(.unary(.negate, a))
				case .open, .close: throw Expr.ParseError.mismatchedParenthesis
			}
		}
		if stack.count > 1 {
			throw Expr.ParseError.tooManyTokens
		}
		guard let expr = stack.last else { throw ParseError.notEnoughTokens }
		self = expr
	}
}

public enum Token: Equatable {
	case open
	case add
	case sub
	case mul
	case div
	case pow
	case neg
	case close
	case value(Float)
	case variable(String)
	case function(String)

	var precedence: Int {
		return switch self {
			case .add, .sub: 2
			case .mul, .div: 3
			case .neg: 4
			case .pow: 5
			default: 10
		}
	}
	var leftAssociated: Bool {
		return switch self {
			case .pow, .neg: false
			default: true
		}
	}
	var isOperator: Bool {
		switch self {
			case .add, .sub, .mul, .div, .pow, .neg: return true
			default: return false
		}
	}
	var isValue: Bool {
		switch self {
			case .value, .variable: return true
			default: return false
		}
	}

}

extension [Token] {
	func shunt() throws -> [Token] {
		var res: [Token] = []
		var stack: [Token] = []
		for t in self {
			switch t {
				case .value, .variable:
					res.append(t)
				case .function, .open:
					stack.append(t)
				case .close:
					while true {
						guard let l = stack.popLast() else {
							throw Expr.ParseError.mismatchedParenthesis
						}
						if l == .open { break }
						res.append(l)
					}
					if case .function(_) = stack.last {
						res.append(stack.popLast()!)
					}

				default:
					while let l = stack.last,
						l != .open
							&& (l.precedence > t.precedence
								|| (l.precedence == t.precedence && t.leftAssociated))
					{
						res.append(stack.popLast()!)
					}
					stack.append(t)
			}
		}
		if stack.contains(.open) { throw Expr.ParseError.mismatchedParenthesis }
		return res + stack.reversed()
	}
}

extension String {
	public var isValidIdentifier: Bool {
		guard let firstChar = self.first, firstChar.isLetter else {
			return false
		}
		return self.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
	}

	public func tokenise() throws -> [Token] {
		var tokens: [Token] = []
		func append(_ token: Token) throws {
			if case .variable(let name) = token,
				!name.allSatisfy({ c in
					("a"..."z").contains(c) || ("A"..."Z").contains(c) || ("0"..."9").contains(c)
				})
			{
				throw Expr.ParseError.invalidIdentifier(name)
			}

			guard var last = tokens.last else {
				return tokens.append(token)
			}
			var token = token
			if (last.isValue || last == .close) && token == .neg {
				token = .sub
			}
			if token == .open, case .variable(let name) = last {
				last = .function(name)
				tokens[tokens.count - 1] = last
			}

			if (last.isValue || last == .close) && (token.isValue) {
				tokens.append(.mul)
			}
			tokens.append(token)
		}

		let scanner = Scanner(string: self)
		scanner.charactersToBeSkipped = nil
		while !scanner.isAtEnd {
			_ = scanner.scanCharacters(from: .whitespaces)
			guard !scanner.isAtEnd else { break }
			let currentIndex = scanner.currentIndex
			let char = scanner.string[currentIndex]
			if char.isNumber || char == "." {
				if let floatVal = scanner.scanFloat() {
					try append(.value(floatVal))
				}
			} else if let name = scanner.scanUpToCharacters(
				from: CharacterSet(charactersIn: "+-*/^() "))
			{
				try append(.variable(name))
			} else if let opChar = scanner.scanCharacter(), "+-*/^()".contains(opChar) {
				switch opChar {
					case "+": try append(.add)
					case "-": try append(.neg)
					case "*": try append(.mul)
					case "/": try append(.div)
					case "^": try append(.pow)
					case "(": try append(.open)
					case ")": try append(.close)
					default: break
				}
			}
		}
		return tokens
	}
}
