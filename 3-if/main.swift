//
//  main.swift
//  evaluator
//
//  Created by jason.pepas on 1/28/23.
//

import Foundation


// MARK: - Errors

enum EvalutorError: Error {
    case badJSON
    case unableToEvaluateASTNode(_ node: ASTNode)
    case symbolNotFound(_ symbolName: String)
    case unexpectedArgumentType(_ badValue: LispValue)
    case incorrectNumberOfArguments(_ badArgs: [LispValue])
    case notImplemented
}


// MARK: - LispValue

typealias LispFunction = ([LispValue]) throws -> (LispValue)

func LispAdd(_ args: [LispValue]) throws -> LispValue {
    let sum: Double = try args.reduce(0) { partialResult, nextValue in
        guard case .number(let d) = nextValue else {
            throw EvalutorError.unexpectedArgumentType(nextValue)
        }
        return partialResult + d
    }
    return .number(sum)
}

func LispSubtract(_ args: [LispValue]) throws -> LispValue {
    guard let firstArg = args.first else {
        throw EvalutorError.incorrectNumberOfArguments(args)
    }
    guard case .number(let firstNumber) = firstArg else {
        throw EvalutorError.unexpectedArgumentType(firstArg)
    }
    guard args.count > 1 else {
        return .number(-firstNumber)
    }
    let sum: Double = try args.dropFirst(1).reduce(firstNumber) { partialResult, nextValue in
        guard case .number(let d) = nextValue else {
            throw EvalutorError.unexpectedArgumentType(nextValue)
        }
        return partialResult - d
    }
    return .number(sum)
}

func LispLessThan(_ args: [LispValue]) throws -> LispValue {
    for arg in args {
        guard case .number = arg else {
            throw EvalutorError.unexpectedArgumentType(arg)
        }
    }
    var previousNumber: Double? = nil
    for number in args.compactMap({ $0.number }) {
        if let previousNumber {
            if !(previousNumber < number) {
                return .boolean(false)
            }
        }
        previousNumber = number
    }
    return .boolean(true)
}

func LispGreaterThan(_ args: [LispValue]) throws -> LispValue {
    for arg in args {
        guard case .number = arg else {
            throw EvalutorError.unexpectedArgumentType(arg)
        }
    }
    var previousNumber: Double? = nil
    for number in args.compactMap({ $0.number }) {
        if let previousNumber {
            if !(previousNumber > number) {
                return .boolean(false)
            }
        }
        previousNumber = number
    }
    return .boolean(true)
}

enum LispValue: CustomStringConvertible {
    case number(_ value: Double)
    case boolean(_ value: Bool)
    case builtinFunc(_ value: LispFunction)
    case noValue
    
    var description: String {
        switch self {
        case .number(let value):
            // drop any superfluous fractional portion when printing.
            if Double(Int(value)) == value {
                return "\(Int(value))"
            } else {
                return "\(value)"
            }
        case .boolean(let value):
            if value {
                return "#t"
            } else {
                return "#f"
            }
        case .builtinFunc(_):
            return "STOPSHIP"
        case .noValue:
            return ""
        }
    }
    
    var number: Double? {
        switch self {
        case .number(let value): return value
        case .boolean, .builtinFunc, .noValue: return nil
        }
    }

    var boolean: Bool? {
        switch self {
        case .boolean(let value): return value
        case .number, .builtinFunc, .noValue: return nil
        }
    }

    var builtinFunc: LispFunction? {
        switch self {
        case .boolean, .number, .noValue: return nil
        case .builtinFunc(let value): return value
        }
    }
}


// MARK: - AST

typealias ASTNode = Dictionary<String,Any>

enum ASTType: String {
    case number
    case symbol
    case list
}

extension ASTNode {
    var type: ASTType {
        get throws {
            guard let typeStr = self["type"] as? String,
                  let typeEnum = ASTType(rawValue: typeStr)
            else {
                throw EvalutorError.badJSON
            }
            return typeEnum
        }
    }
    
    var number: Double? {
        return self["value"] as? Double
    }
    
    var symbol: String? {
        return self["value"] as? String
    }
    
    var list: [ASTNode]? {
        return self["value"] as? [ASTNode]
    }
}


// MARK: - Evaluator

typealias Environment = Dictionary<String, LispValue>

let g_env: Environment = [
    "pi": .number(3.14159),
    "+": .builtinFunc(LispAdd),
    "-": .builtinFunc(LispSubtract),
    "#t": .boolean(true),
    "#f": .boolean(false),
    "<": .builtinFunc(LispLessThan),
    ">": .builtinFunc(LispGreaterThan),
]

func lookup(symbolName: String, env: Environment) throws -> LispValue {
    guard let value = env[symbolName] else {
        throw EvalutorError.symbolNotFound(symbolName)
    }
    return value
}

func lisp_apply(oper: LispValue, operands: [LispValue]) throws -> LispValue {
    return try oper.builtinFunc!(operands) // STOPSHIP
}

extension LispValue {
    var isTruthy: Bool {
        if case .boolean(let value) = self {
            return value
        } else {
            return true
        }
    }
}

func lisp_eval(ast: ASTNode, env: Environment) throws -> LispValue {
    if let value = ast.number {
        return .number(value)

    } else if let symbolName = ast.symbol {
        return try lookup(symbolName: symbolName, env: env)

    } else if let nodes = ast.list {
        guard let head = nodes[safe: 0] else {
            // TODO: maybe make a specific "can't evalue zero-argument list" error?
            throw EvalutorError.incorrectNumberOfArguments([])
        }
        
        // This is an 'if' statement.
        if head.symbol == "if" {
            guard let predicate = nodes[safe: 1] else {
                // TODO: maybe make a specific error here
                throw EvalutorError.incorrectNumberOfArguments([])
            }
            let predicateValue = try lisp_eval(ast: predicate, env: env)
            if predicateValue.isTruthy {
                // evaluate and return consequent.
                guard let consequent = nodes[safe: 2] else {
                    // TODO: maybe make a specific error here
                    throw EvalutorError.incorrectNumberOfArguments([])
                }
                let consequentValue = try lisp_eval(ast: consequent, env: env)
                return consequentValue
            } else {
                // evaluate and return alternative.
                guard let alternative = nodes[safe: 3] else {
                    return .noValue
                }
                let alternativeValue = try lisp_eval(ast: alternative, env: env)
                return alternativeValue
            }
            
        } else {
            // This is a typical list.
            let values = try nodes.map {
                return try lisp_eval(ast: $0, env: env)
            }
            let oper = values[0]
            let operands = Array(values.dropFirst())
            return try lisp_apply(oper: oper, operands: operands)
        }
        
    } else {
        throw EvalutorError.unableToEvaluateASTNode(ast)
    }
}


// MARK: - Input

func readStdin() -> Data? {
    guard let firstLine = readLine(strippingNewline: false) else {
        return nil
    }
    var content = firstLine
    while(true) {
        if let line = readLine(strippingNewline: false) {
            content += line
        } else {
            break
        }
    }
    return content.data(using: .utf8)
}

func readFile(path: String) throws -> Data {
    let url: URL
    if #available(macOS 13.0, *) {
        url = URL(filePath: FileManager.default.currentDirectoryPath).appending(component: path)
    } else {
        url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    }
    return try Data(contentsOf: url)
}

func getInput() throws -> Data? {
    if CommandLine.arguments.count > 1 {
        let fname = CommandLine.arguments[1]
        return try readFile(path: fname)
    } else {
        return readStdin()
    }
}


// MARK: - main

func main() throws {
    guard let data = try getInput() else {
        exit(1)
    }
    let asts = try JSONSerialization.jsonObject(with: data)
    guard let asts = asts as? [ASTNode] else {
        throw EvalutorError.badJSON
    }
    try asts.forEach { ast in
        let value = try lisp_eval(ast: ast, env: g_env)
        print(value)
    }
}
try main()


// Thanks to https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings
extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
