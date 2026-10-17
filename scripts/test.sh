#!/bin/bash
# Pasa los tests de PoxiDropCore.
# Con solo las Command Line Tools, el sistema de compilación de SwiftPM reparte la compilación en
# varias tareas y no todas reciben la ruta del plugin de macros de swift-testing, así que a veces
# falla con «plugin for module 'TestingMacros' not found». Aquí se la pasamos siempre.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
if [ -d "$PLUGINS" ]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
else
    swift test "$@"
fi
