import Darwin
import Foundation

exit(PNCommandRunner.run(rawArguments: Array(CommandLine.arguments.dropFirst())))
