#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build-host
swiftc -swift-version 5 TicketLibre/Core/Models.swift TicketLibre/Core/Money.swift TicketLibre/Core/ReceiptParser.swift tests-portable/CoreTests.swift -o .build-host/core-tests
.build-host/core-tests
