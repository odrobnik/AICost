import ArgumentParser
import Foundation
import OpenAICost

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        self.write(Data(string.utf8))
    }
}
