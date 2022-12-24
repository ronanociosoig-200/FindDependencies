import os.log
import Foundation
import ArgumentParser
import ProjectAutomation

typealias GraphProject = [String: Project]
let tuistPath = "/usr/local/bin/tuist"
let project = "Project.swift"
let graphFile = "graph.json"

extension Logger {
    private static var subsystem = "findDependencies.sonomos.com"

    /// Log process
    static let process = Logger(subsystem: subsystem, category: "Tuist")
}

@main
struct FindDependencies: ParsableCommand {
    @Flag(help: "Show the dependencies of named module.")
    var showDependencies = false
    
    @Flag(help: "Show the dependents of named module.")
    var showDependents = false
    
    @Flag(name: .shortAndLong, help: "Show the dependents of named module.")
    var debug = false
    
    @Option(name: .shortAndLong, help: "The path to the Project.swift file.")
        var path: String?

    @Argument(help: "The module you are interested in.")
    var moduleName: String

    mutating func run() throws {
        if debug {
            let message = "Checking for \(moduleName) Dependencies: \(showDependencies ? "Yes": "No") Dependents: \(showDependents ? "Yes": "No")"
            
            Logger.process.debug("\(message)")
            Logger.process.debug("----------")
        }

        if !showDependencies && !showDependents {
            Logger.process.error("Either or both of these flags must be specified: --show-dependencies --show-dependents")
            FindDependencies.exit(withError: 0 as? Error)
        }

        do {
            let output = try safeShell("which tuist")

            if output.contains(tuistPath) {
                if debug {
                    Logger.process.debug("Tuist is installed OK")
                }
            } else {
                Logger.process.error("Sorry, this isn't going to work. You need tuist installed at /usr/bin/local")
                FindDependencies.exit(withError: 0 as? Error)
            }
        }
        catch {
            Logger.process.error("\(error)") //handle or silence the error here
        }
        
        // let error = "No such file or directory"
        let defaultPath: String
        
        if debug {
            if let path = path {
                Logger.process.debug("Path parameter: \(path)")
            } else {
                Logger.process.debug("Path parameter: No path defined. Will use the defaul current directory.")
            }
        }
        
        if let path = path {
            if path.hasSuffix("/") {
                defaultPath = path
            } else {
                defaultPath = path + "/"
            }
        } else {
            defaultPath = "./"
        }
        
        if debug {
            Logger.process.debug("Default path: \(defaultPath)")
        }
        
        // Check the Project.swift file
//        if let path = path {
//            let output = try safeShell("file " + defaultPath + project)
//
//            if output.contains(error) {
//                Logger.process.error("Path Error: \(error). Ensure that \(project) can be found at the specified path: \(path)")
//                FindDependencies.exit(withError: 0 as? Error)
//            }
//        } else {
//            let output = try safeShell("file ./" + project)
//
//            if output.contains(error) {
//                Logger.process.error("Path Error: \(error). Ensure that \(project) can be found at the current directory, or pass a path parameter.")
//                FindDependencies.exit(withError: 0 as? Error)
//            }
//        }
        
        // The graph command seems to only work
//        do {
//            let command = "tuist graph -d -t -f json"
//            if debug {
//                Logger.process.debug("Command: \(command)")
//            }
//            let output = try safeShell(command)
//            if !output.isEmpty {
//                Logger.process.info("Output: \(output)")
//            }
//        }
//        catch {
//            Logger.process.error("\(error)") //handle or silence the error here
//        }

        let fileManager = FileManager.default
        let graphPath = defaultPath + graphFile
        
        if debug {
            Logger.process.debug("Tuist graph path: \(graphPath)")
        }
        if fileManager.fileExists(atPath: graphPath) {
            let graphJSONData = fileManager.contents(atPath: graphPath)
            let decoder = JSONDecoder()
            do {
                if let data = graphJSONData {
                    let graph = try decoder.decode(Graph.self, from: data)
                    let projects = graph.projects
                    
                    for graphProject in projects as GraphProject {
                        let project = graphProject.value
                        
                        parseProject(project: project)
                    }
                }
            } catch {
                Logger.process.error("Error: Failed to parse the graph")
            }
        } else {
            Logger.process.error("Error: No graph exists at path: \(graphPath)")
        }
    }
    
    func parseProject(project: Project) {
        let targets = project.targets
        for target in targets {
            if target.name == moduleName && showDependencies {
                if !target.dependencies.isEmpty {
                    for dependency in target.dependencies {
                        trimDependency(dependency:dependency)
                    }
                } else {
                    if debug { Logger.process.debug("No dependencies") }
                }
            } else {
                if !target.dependencies.isEmpty && showDependents {
                    for dependency in target.dependencies {
                        findDependant(dependency: dependency, in: target)
                    }
                }
            }
        }
    }
    
    func findDependant(dependency: TargetDependency, in target: Target) {
        let parsedDependency = "\(dependency)"
        if parsedDependency.contains(moduleName) {
            if debug {
                Logger.process.debug("Dependant: \(target.name)")
            }
            print("\(target.name)")
        }
    }
    
    func trimDependency(dependency: TargetDependency) {
        let dependencyExtracted = "\(dependency)"
        if debug {
            Logger.process.debug("trimDependency: \(dependencyExtracted)")
        }
        let startingString = "target(name: \""
        let offset = dependencyExtracted.count - startingString.count
        let trimmed = dependencyExtracted.suffix(offset)
        if debug {
            Logger.process.debug("Dependency: \(trimmed.dropLast(2))")
        }
        print("\(trimmed.dropLast(2))")
    }
    
    @discardableResult // Add to suppress warnings when you don't want/need a result
    func safeShell(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh") //<--updated
        task.standardInput = nil

        try task.run() //<--updated
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
}
