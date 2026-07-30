// Quick standalone check that networksetup works in this environment.
import Foundation

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
task.arguments = ["-listallnetworkservices"]
let pipe = Pipe()
task.standardOutput = pipe
try task.run()
task.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
print(String(data: data, encoding: .utf8) ?? "")
print("exit=\(task.terminationStatus)")
