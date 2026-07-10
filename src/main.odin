package main

import app "../packages/app"

import "core:os"

main :: proc() {
	os.exit(app.run_cli())
}
