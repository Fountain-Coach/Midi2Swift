.PHONY: assert-full-spec test ci

assert-full-spec:
	STRICT_FULL_SPEC=1 swift test --package-path swift/Midi2Swift

test:
	swift test --package-path swift/Midi2Swift
