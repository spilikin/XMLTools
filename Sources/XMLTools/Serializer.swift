//
//  Serializer.swift
//  XMLTools
//  
//  Created on 26.06.18
//

import Foundation

class XMLRawEncoder {
    var data = Data()
    
}

class XMLSerializer: DefaultDocumentHandler {
    struct Options {
        var indent = false
    }

    internal class State {
        let element:Element?
        var isEmpty = true
        var hasText = false
        var hasChildElements = false

        init() {
            element = nil
        }
        
        init(_ element: Element) {
            self.element = element
        }
    }
    public var options = Options()
    public var data = Data()
    private var identLevel = 0
    private var stateStack = [State]()
    private let encoding = String.Encoding.utf8

    override func startDocument(_ document: Document) {
        write("<?xml version=").attributeValue(document.version)
        write(" encoding=").attributeValue("UTF-8")
        if document.standalone {
            write(" standalone=\"true\"")
        }
        write("?>")
        newLine()
        
    }
    
    override func endDocument(_ document: Document) {
    }
    
    @discardableResult
    private func popState() -> State? {
        return stateStack.popLast()
    }

    @discardableResult
    private func pushState(_ state: State) -> State {
        stateStack.append(state)
        return state
    }
    
    private var state : State {
        get {
            if stateStack.isEmpty {
                stateStack.append(State())
            }
            return stateStack.last!
        }
    }

    override func startElement(_ element: Element, from document: Document) {
        if state.element != nil && state.isEmpty {
            write(">")
            if options.indent {
                newLine()
                write(indentString())
            }
        }
        if state.element != nil && state.hasChildElements {
            if options.indent {
                newLine()
                write(indentString())
            }
        }
        state.isEmpty = false
        state.hasChildElements = true
        write("<")
        if (element.name().namespaceURI != "") {
            let prefix = assureNamespaceDeclaration(element.name().namespaceURI, in:element)
            write(prefix).write(":")
        }
        write(element.name().localName)
        
        for prefix in (element.namespaceContext?.allPrefixes().sorted()) ?? [String]() {
            // skip the built-in xml namespace
            if prefix == "xml" {
                continue
            }
            write(" xmlns")
            if prefix != "" {
                write(":").write(prefix)
            }
            write("=").attributeValue((element.namespaceContext?[prefix])!)
        }
        
        // TODO sort attributes
        for (qname, attr) in element.attributes {
            let value = attr.value ?? ""
            write(" ")
            if (qname.namespaceURI != "") {
                let prefix = assureNamespaceDeclaration(qname.namespaceURI, in: element)
                write(prefix).write(":")
            }
            write(qname.localName).write("=").attributeValue(value)
        }
        
        pushState(State(element))
        identLevel += 1
    }
    
    // assures that the given namespace is declared, if not declares them with ns0..n naming pattern
    private func assureNamespaceDeclaration(_ uri: String, in element: Element) -> String {
        var prefix = element.resolvePrefix(forURI: uri)
        if prefix == nil {
            // no such prefix yes, we neeed to define our own
            if element.namespaceContext == nil {
                element.namespaceContext = NamespaceContext()
            }
            var num = 0
            while (element.resolveURI(forPrefix: "ns\(num)") != nil) {
                num += 1
            }
            prefix = "ns\(num)"
            element.namespaceContext?.declare(prefix!, uri: element.name().namespaceURI)
        }
        return prefix!
    }
    
    override func endElement(_ element: Element, from document: Document) {
        identLevel -= 1
        if state.isEmpty {
            write("/>")
        } else {
            if options.indent && state.hasChildElements {
                newLine()
                write(indentString())
            }
            write("</")
            if (element.name().namespaceURI != "") {
                let prefix = element.resolvePrefix(forURI: element.name().namespaceURI)!
                write(prefix).write(":")

            }
            write(element.name().localName).write(">")
        }
        
        popState()

    }
    
    override func textNode(_ textNode: TextNode, from document: Document) {
        if state.element != nil && state.isEmpty {
            write(">")
        }
        state.isEmpty = false
        state.hasText = true
        text(textNode.value)
    }
    
    override func cdata(_ cdata: CDATANode, from document: Document) {
        
    }
    
    override func comment(_ comment: CommentNode, from document: Document) {
        
    }
    
    override func processingInstruction(_ instruction: ProcessingInstruction, from document: Document) {
        
    }
    
    private func indentString() -> String {
        return String(repeating: " ", count: 4*identLevel)
    }
 
    public func newLine() {
        write("\n")
    }
    
    @discardableResult
    public func write(_ str:String) -> XMLSerializer {
        if let strdata = str.data(using:encoding) {
            data.append(strdata)
        }
        return self
    }
    
    @discardableResult
    public func text(_ str:String) -> XMLSerializer {
        var escaped = str.replacingOccurrences(of: "&", with: "&amp;", options: .literal)
        
        let map = ["<" : "&lt;", ">" : "&gt;"]
        for (char, escaping) in map {
            escaped = escaped.replacingOccurrences(of: char, with: escaping, options: .literal)
        }
        
        write(escaped)
        
        return self
    }
    
    @discardableResult
    public func attributeValue(_ str:String) -> XMLSerializer {
        write("\"")
        var escaped = str.replacingOccurrences(of: "&", with: "&amp;", options: .literal)
        
        let map = ["<" : "&lt;", ">" : "&gt;", "'" : "&apos;", "\"" : "&quot;"]
        for (char, escaping) in map {
            escaped = escaped.replacingOccurrences(of: char, with: escaping, options: .literal)
        }
        write(escaped)
        write("\"")
        return self
    }

}

extension Document {
    
    public func data(indent: Bool = false) -> Data? {
        let serializer = XMLSerializer()
        serializer.options.indent = indent
        do {
            try traverse(serializer)
        } catch {
            return nil
        }
        return serializer.data
    }
}
