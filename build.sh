#!/bin/zsh
set -eu
cd "$(dirname "$0")"
bundle=build/Blink.app/Contents
mkdir -p "$bundle/MacOS"
cp Info.plist "$bundle/Info.plist"
swiftc -O Index.swift main.swift -o "$bundle/MacOS/Blink"
codesign --force --sign - build/Blink.app
