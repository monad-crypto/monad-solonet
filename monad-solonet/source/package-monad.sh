#!/usr/bin/env bash

set -ex

MONAD_VERSION="0.0.0"

mkdir -p /app/package/usr/local/bin /app/package/usr/local/lib
cd /app/monad-bft

# Rust binaries
cp target/release/examples/ledger-tail ../package/usr/local/bin/monad-ledger-tail
cp target/release/examples/sign-name-record ../package/usr/local/bin/monad-sign-name-record
cp target/release/examples/triedb-bench ../package/usr/local/bin/
cp target/release/examples/wal2json ../package/usr/local/bin/
cp target/release/examples/txgen ../package/usr/local/bin/monad-txgen
cp target/release/monad-archive-checker ../package/usr/local/bin/
cp target/release/monad-archiver ../package/usr/local/bin/
cp target/release/monad-debug-node ../package/usr/local/bin/
cp target/release/monad-indexer ../package/usr/local/bin/
cp target/release/monad-block-writer ../package/usr/local/bin/
cp target/release/monad-keystore ../package/usr/local/bin/
cp target/release/monad-node ../package/usr/local/bin/
cp target/release/monad-rpc ../package/usr/local/bin/

# C++ binaries
cp /build/category/mpt/monad-mpt ../package/usr/local/bin/
cp /build/cmd/monad ../package/usr/local/bin/
cp /build/cmd/monad-cli ../package/usr/local/bin/

# Libraries
find target/release/build -name "libmonad_execution.so" -exec cp {} ../package/usr/local/lib/ \;
find target/release/build -name "libtriedb_driver.so" -exec cp {} ../package/usr/local/lib/ \;
find target/release/build -name "libquill.so*" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true
find target/release/build -name "libkeccak.so" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true
find target/release/build -name "libsecp256k1.so" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true
find target/release/build -name "libblake3.so*" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true
find target/release/build -name "libc-kzg-4844.so" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true
find target/release/build -name "libsilkpre.so" -exec cp {} ../package/usr/local/lib/ \; 2>/dev/null || true

# Merge Debian structure
cp -r debian/DEBIAN ../package/
cp -r debian/etc ../package/ 2>/dev/null || true
cp -r debian/opt ../package/ 2>/dev/null || true
mkdir -p ../package/usr/lib/systemd/system
cp -r debian/usr/lib/systemd/system/* ../package/usr/lib/systemd/system/ 2>/dev/null || true

cd /app/

# strip (this allows to package faster)
find package/usr/local/bin/ -type f -executable | xargs strip --strip-all 2>/dev/null
find package/usr/local/lib/ -type f -name "*.so*" | xargs strip --strip-all 2>/dev/null

export DEB_VERSION="$MONAD_VERSION"
export DEB_VERSION="$(echo "$DEB_VERSION" | sed -E 's/^([^-]+)-v(.+)$/\2-\1/')"
export DEB_VERSION="$(echo "$DEB_VERSION" | sed -E 's/^v([0-9].*)$/\1/')"
echo "$DEB_VERSION" >/app/package/DEB_VERSION
echo "DEB_VERSION:" && echo "$DEB_VERSION"
DEB_FILE=monad_"$DEB_VERSION"_amd64.deb
echo "DEB_FILE:" && echo "$DEB_FILE"

nfpm package --config /app/nfpm.yml --packager deb --target /app/package
SHA256SUM=$(sha256sum /app/package/$DEB_FILE | awk '{print $1}')
echo "$SHA256SUM" >/app/package/SHA256SUM
echo "SHA256SUM:" && echo "$SHA256SUM"
