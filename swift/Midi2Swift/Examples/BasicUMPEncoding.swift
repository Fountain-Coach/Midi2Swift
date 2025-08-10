import Foundation
import UMP
import System
import ChannelVoice

@main
struct Demo {
    static func main() {
        let noteOn = UMP32(0x20903C64)
        print(String(format: "UMP32: 0x%08X", noteOn.raw))
    }
}
