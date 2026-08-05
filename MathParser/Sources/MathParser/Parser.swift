import Foundation

extension Lexer.Token {
	var precedence: Int {
		switch self {
			case .add, .subtract: return 1
			case .multiply, .divide: return 2
			case .power, .negate: return 3
			default: return 0
		}
	}

	var isRightAssociative: Bool {
		self == .power || self == .negate
	}
}

extension Expr {

	public static func parse(_ str: String) throws -> Expr {
		let lexer = Lexer(parse: str)

		var result: [Expr] = []
		var stack: [Lexer.Token] = []

		var functionParameterStack = [0]

		func pop() throws -> Expr {
			guard let last = result.popLast() else {
				throw MathError.notEnoughTokens
			}
			return last
		}

		@discardableResult func moveOpFromStack(_ last: Lexer.Token) throws -> Bool {
			if last == .negate {
				let value = try pop()
				result.append(.unary(.negate, value))
				return true
			}

			let op: Expr.BinaryOp
			switch last {
				case .add: op = .add
				case .subtract: op = .subtract
				case .multiply: op = .multiply
				case .divide: op = .divide
				case .power: op = .power
				default: return false
			}

			let rhs = try pop()
			let lhs = try pop()
			result.append(.binary(op, lhs, rhs))
			return true
		}

		while let token = try lexer.nextToken() {
			switch token {
				case .variable(let name):
					result.append(.variable(name))
				case .value(let value):
					result.append(.value(value))
				case .function(_):
					stack.append(token)
					let idx = lexer.idx
					let count: Int
					if case .open = try lexer.peekToken(), case .close = try lexer.peekToken(n: 2) {
						count = 0
					} else {
						count = 1
					}
					lexer.idx = idx
					functionParameterStack.append(count)
				case .separator:
					if functionParameterStack.isEmpty {
						throw MathError.unexpectedSeparator
					}
					functionParameterStack[functionParameterStack.count - 1] += 1
					while let last = stack.last, last != .open {
						try moveOpFromStack(last)
						stack.removeLast()
					}

				case .add, .subtract, .multiply, .divide, .power, .negate:
					while let last = stack.last,
						last.precedence > token.precedence
							|| (last.precedence == token.precedence && !token.isRightAssociative)
					{
						if try !moveOpFromStack(last) { break }
						stack.removeLast()
					}
					stack.append(token)
				case .open:
					stack.append(token)
				case .close:
					var count = 0
					while let last = stack.last, last != .open {
						try moveOpFromStack(last)
						stack.removeLast()
						count += 1
					}
					stack.removeLast()
					if case .function(let name) = stack.last {
						stack.removeLast()
						let count = functionParameterStack.popLast()!
						guard count <= result.count else {
							throw MathError.notEnoughArguments
						}
						var values: [Expr] = []
						for _ in 0..<count {
							values.append(try pop())
						}
						result.append(.function(name, values.reversed()))
					}
			}
		}
		while let last = stack.popLast() {
            if last == .open {
                throw MathError.unexpectedOpenParam
                }
			try moveOpFromStack(last)
		}

        if let first = result.first {return first}
        throw MathError.empty
	}
}
