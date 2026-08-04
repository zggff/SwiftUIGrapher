import Foundation

enum MathError: LocalizedError {
	case unknownFunction(FuncSignature)
	case unknownVariable(String)
	case invalidNumber(String)
	case invalidCharacter(Character)

	case notEnoughTokens
	case notEnoughArguments
	case unexpectedSeparator
	case unexpectedOpenParam

	public var errorDescription: String? {
		switch self {
			case .unknownFunction(let signature): "function `\(signature)` does not exist"
			case .unknownVariable(let name): "variable `\(name)` does not exist"
			case .invalidNumber(let number): "failed to parse `\(number)` as float"
			case .invalidCharacter(let c): "`\(c)` is an invalid character"
			case .notEnoughTokens, .notEnoughArguments: "too few tokens"
            case .unexpectedSeparator: "separator encountered outside of function"
            case .unexpectedOpenParam: "found an unclosed parenthesis"
		}
	}

}
