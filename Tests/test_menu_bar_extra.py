from pathlib import Path

source = Path("MenuBarApp/WizControlApp.swift").read_text()
assert "MenuBarExtra {" in source
assert "MenuBarExtra(isInserted:" not in source
