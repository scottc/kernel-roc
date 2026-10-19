app [config] { pf: platform "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.5.0/CupqPH9snWf11g7tWgcJf4Yg5cJ3K9fhL7fSgqDcqJQH.tar.zst" }

import pf.Tool

# Roc versions:
# https://github.com/roc-lang/roc-overlay/blob/master/sources.json

config = [
	Name("kernal-roc"),
	Overlay("roc", "github:roc-lang/roc-overlay"),
	Shell("default", [Use("ci-env")]),
	Environment("dev-env", [
    	Overlays(["roc"]),
    	Command("roc", "rocpkgs.nightly-2026-10-13-b17d287"),
  			Tools([
                "zig",
				"qemu",
				"grub2",
				"xorriso"
			]),
	]),
	Environment(
		"ci-env",
		[
			Overlays(["roc"]),
			Command("roc", "rocpkgs.nightly-2026-10-13-b17d287"),
			Tools([
				"zig",
				"qemu",
				"grub2",
				"xorriso"
			]),
		],
	),
	Task("ci", [
	    Use("ci-env"),
		Run([
		    "scripts/ci.roc", "--",
			"--baseline=godot4.3",
			"--engines=none",
			"--targets=x64musl",
			"--tests=all",
			"-Doptimize=Debug"
		])
	]),
	Environment(
		"gh-publish-env",
		[
			Overlays(["roc"]),
			Command("roc", "rocpkgs.nightly-2026-10-13-b17d287"),
			Tools([
			    "gh",
    			"zig",
			]),
		],
	),
	Task("publish", [
	    Use("gh-publish-env"),
		Run([
		    "scripts/publish.roc", "--",
		]),
	]),
]
