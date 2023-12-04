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
    case notImplemented
}


// MARK: - LispValue

typealias LispFunction = ([LispValue]) throws -> (LispValue)

func LispPlus(_ args: [LispValue]) throws -> LispValue {
    let sum = args[0].number! + args[1].number! // STOPSHIP fix me
    return .number(sum)
}

enum LispValue: CustomStringConvertible {
    case number(_ value: Double)
    case builtinFunc(_ value: LispFunction)
    
    var description: String {
        switch self {
        case .number(let value):
            // drop any superfluous fractional portion when printing.
            if Double(Int(value)) == value {
                return "\(Int(value))"
            } else {
                return "\(value)"
            }
        case .builtinFunc(_):
            return "STOPSHIP"
        }
    }
    
    var number: Double? {
        switch self {
        case .number(let value): return value
        case .builtinFunc: return nil
        }
    }
    
    var builtinFunc: LispFunction? {
        switch self {
        case .number: return nil
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
    "+": .builtinFunc(LispPlus)
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

func lisp_eval(ast: ASTNode, env: Environment) throws -> LispValue {
    if let value = ast.number {
        return .number(value)
    } else if let symbolName = ast.symbol {
        return try lookup(symbolName: symbolName, env: env)
    } else if let nodes = ast.list {
        let values = try nodes.map {
            return try lisp_eval(ast: $0, env: env)
        }
        let oper = values[0]
        let operands = Array(values.dropFirst())
        return try lisp_apply(oper: oper, operands: operands)
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
