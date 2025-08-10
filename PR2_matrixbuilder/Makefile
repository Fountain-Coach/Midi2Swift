.PHONY: assert-full-spec test matrix tools

assert-full-spec:
	STRICT_FULL_SPEC=1 swift test --package-path swift/Midi2Swift

test:
	swift test --package-path swift/Midi2Swift

tools:
	swift build --package-path tools

matrix: tools
	tools/.build/debug/MatrixBuilder --out spec/matrix.json --sources spec/sources/checksums.json
