import Foundation

public final class Lexer {
	private var input: [Character]
	var idx: Int = 0

	private var previousToken: Token? = nil
	private var bufferedToken: Token? = nil

	public enum Token: Equatable, Comparable {
		case value(Double)
		case variable(String)
		case function(String)

		case add
		case subtract
		case multiply
		case divide
		case power
		case negate

		case open
		case close
		case separator

		var impliesMultiplicationLHS: Bool {
			switch self {
				case .value, .variable, .close: return true
				default: return false
			}
		}

		var impliesMultiplicationRHS: Bool {
			switch self {
				case .variable, .value, .function, .open: return true
				default: return false
			}
		}

		var isOperator: Bool {
			switch self {
				case .add, .subtract, .multiply, .divide, .power, .negate: return true
				default: return false
			}
		}
	}

	public enum LexerError: LocalizedError {
		case invalidNumber(String)
		case invalidCharacter(Character)
		public var errorDescription: String? {
			switch self {
				case .invalidNumber(let n): "failed to parse `\(n)` as float"
				case .invalidCharacter(let c): "`\(c)` is an invalid character"
			}
		}
	}

	var current: Character? {
		guard idx < input.count else { return nil }
		return input[idx]
	}

	public init(parse input: String) {
		self.input = Array(input)
	}

	public func tokenise() throws -> [Token] {
		var res: [Token] = []
		while let tok = try nextToken() {
			res.append(tok)
		}
		return res
	}

	public func peekToken(n: Int = 1) throws -> Token? {
		let idxBack = idx
		let prevBack = previousToken
		let bufBack = bufferedToken

		var tok: Token? = nil
		for _ in 0..<n {
			tok = try nextToken()
		}

		self.idx = idxBack
		self.previousToken = prevBack
		self.bufferedToken = bufBack
		return tok
	}

	private func skipWhitespace() {
		while let c = current, c.isWhitespace {
			idx += 1
		}
	}

	private func tryParseNumber() throws -> Token? {
		var digits = ""
		var dotEncountered = false
		while let c = current, c.isASCII && (c.isNumber || c == ".") {
			idx += 1
			digits.append(c)
			if c == "." {
				if dotEncountered {
					throw LexerError.invalidNumber(digits)
				}
				dotEncountered = true
			}
		}
		if digits.isEmpty { return nil }
		guard let number = Double(digits) else {
			throw LexerError.invalidNumber(digits)
		}
		return .value(number)
	}

	private func tryParse() throws -> Token? {
		if let number = try tryParseNumber() {
			return number
		}
		var name = ""
		while let c = current, c.isASCII && (c.isLetter || c.isNumber) {
			name.append(c)
			idx += 1
		}
		if name.isEmpty, let c = current {
			throw LexerError.invalidCharacter(c)
		}

		if let c = current, c == "(" {
			return .function(name)
		}
		return .variable(name)
	}

	public func nextToken() throws -> Token? {
		if let bufferedToken {
			self.bufferedToken = nil
			previousToken = bufferedToken
			return bufferedToken
		}

		skipWhitespace()
		guard let current else { return nil }

		let rawToken =
			switch current {
				case "+": advance(.add)
				case "-": advance(.subtract)
				case "*": advance(.multiply)
				case "/": advance(.divide)
				case "^": advance(.power)
				case "(": advance(.open)
				case ")": advance(.close)
				case ",": advance(.separator)
				default: try tryParse()
			}
		guard var rawToken else { return nil }
		if rawToken == .subtract {
			if previousToken == nil || previousToken == .open || previousToken == .separator
				|| previousToken?.isOperator == true
			{
				rawToken = .negate
			}
		}

		if let prev = previousToken, prev.impliesMultiplicationLHS,
			rawToken.impliesMultiplicationRHS
		{
			bufferedToken = rawToken
			rawToken = .multiply
		}

		previousToken = rawToken
		return rawToken
	}

	@inline(always)
	private func advance() {
		idx += 1
	}

	@inline(always)
	private func advance(_ tok: Token) -> Token {
		idx += 1
		return tok
	}
}
