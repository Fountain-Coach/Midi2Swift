.PHONY: assert-full-spec test matrix tools

assert-full-spec:
	STRICT_FULL_SPEC=1 swift test --package-path swift/Midi2Swift

test:
	swift test --package-path swift/Midi2Swift

tools:
	swift build --package-path tools

matrix: tools
	tools/.build/debug/MatrixBuilder --out spec/matrix.json --sources spec/sources/checksums.json

codegen: tools
	tools/.build/debug/SwiftGen --in spec/matrix.json --out swift/Midi2Swift/Sources

clean:
	rm -rf spec/matrix.json spec/coverage.json spec/coverage.html
	rm -rf swift/Midi2Swift/Sources/**/Generated
