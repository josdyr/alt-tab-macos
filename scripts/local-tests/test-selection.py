"""Run the actual selection tests with fail-fast assertions outside the Xcode test target."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / "src/switcher/state/SelectionResolverTests.swift").read_text()
source = source.replace("import XCTest", "import Foundation").replace(": XCTestCase", "")
names = re.findall(r"func (test\w+)\(\)", source)
assertions = r'''func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) { precondition(a == b, message, file: file, line: line) }
func XCTAssertTrue(_ a: Bool, _ message: String = "") { precondition(a, message) }
func XCTAssertFalse(_ a: Bool, _ message: String = "") { precondition(!a, message) }
func XCTAssertNil<T>(_ a: T?, _ message: String = "") { precondition(a == nil, message) }
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory)
    main = path / "main.swift"
    main.write_text(assertions + source + "\nlet suite = SelectionResolverTests()\n" + "\n".join("suite." + name + "()" for name in names))
    subprocess.run(["swiftc", str(root / "src/switcher/state/SelectionResolver.swift"), str(main), "-o", str(path / "tests")], check=True)
    subprocess.run([str(path / "tests")], check=True)
print(f"{len(names)} actual selection test methods passed with precondition assertion adapter")
