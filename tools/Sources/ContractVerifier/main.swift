import Foundation

@main struct ContractVerifier {
    static func main() throws {
        let env = ProcessInfo.processInfo.environment
        let strict = (env["STRICT_FULL_SPEC"] ?? "0") == "1"
        if strict {
            fputs("ContractVerifier: STRICT_FULL_SPEC=1 requires a populated matrix and generated sources.\n", stderr)
            exit(2)
        } else {
            print("ContractVerifier: non-strict mode (development).")
        }
    }
}
