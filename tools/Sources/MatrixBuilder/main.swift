import Foundation

@main struct MatrixBuilder {
    static func main() throws {
        let args = CommandLine.arguments.dropFirst()
        if args.contains("--help") || args.contains("-h") || args.isEmpty {
            print("MatrixBuilder — build spec/matrix.json from PDFs in spec/sources (placeholder).")
            print("Usage: MatrixBuilder --out spec/matrix.json")
            return
        }
        // Placeholder: real implementation will parse PDFs and emit matrix JSON.
        // Exits with code 2 to signal unimplemented pipeline step in strict mode.
        fputs("MatrixBuilder: not yet implemented for parsing PDFs.\n", stderr)
        exit(2)
    }
}
