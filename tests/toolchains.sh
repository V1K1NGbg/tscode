#!/bin/bash
# Executed inside the image by smoke.sh.
set -eo pipefail
tscode-install all
. /tscode/config/bash-env
python3 -c 'import venv; print("Python OK")'
python3 -m pip --version
python3 -m venv /tmp/tscode-venv
node -e 'if (!process.release.lts) process.exit(1)'
npm --version
nvm current
printf 'class Hello { public static void main(String[] args) { System.out.println("Java OK"); }}\n' > /tmp/Hello.java
java /tmp/Hello.java
lua5.4 -e 'assert(1+1 == 2)'
printf 'fn main() { println!("Rust OK"); }\n' > /tmp/hello.rs
rustc /tmp/hello.rs -o /tmp/rust-hello
/tmp/rust-hello
printf 'int main(void) { return 0; }\n' > /tmp/hello.c
gcc /tmp/hello.c -o /tmp/c-hello
/tmp/c-hello
cmake --version
gdb --version
test "$(stat -c %u /config/toolchains)" = "$(stat -c %u /config)"
cp /config/toolchains /tmp/selections
tscode-install all
cmp /tmp/selections /config/toolchains
for tool in ranger opencode carbonyl; do command -v "$tool"; done
opencode --version
carbonyl --version
bash -ic 'nvm current; node --version; npm --version'
