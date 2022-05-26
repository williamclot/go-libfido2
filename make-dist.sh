#!/bin/bash
set -eu

main() {
  local target=''
  target="$(uname -s)-$(uname -m)"
  case "$target" in
    Darwin-x86_64)
      ;;
    *)
      echo "$0 not implemented for $target" >&2
      exit 1
      ;;
  esac
  # Sanity check.
  if [[ -z "$target" ]]; then
    echo "$0: target cannot be empty" >&2
    exit 1
  fi

  cd "$(dirname "$0")"
  git submodule update --init

  local tmp=''
  tmp="$(mktemp -d)"
  #shellcheck disable=SC2064  # Early expansion on purpose.
  trap "rm -fr '$tmp'" EXIT

  # Get packages from $tmp, we shouldn't need anything else.
  export PKG_CONFIG_PATH="$tmp/lib/pkgconfig"

  # Clean any leftovers from previous builds.
  for d in third_party/*; do
    pushd "$d"
    [[ -f Makefile ]] && make clean
    git clean -df
    popd
  done

  echo 'Building openssl'
  pushd 'third_party/openssl'
  ./config \
    -mmacosx-version-min=10.12 \
    --prefix="$tmp" \
    --openssldir="$tmp/openssl@1.1" \
    no-shared \
    no-zlib
  # Build and copy only what we need instead of 'make && make install'.
  # It's a bit quicker.
  make build_generated libcrypto.a libcrypto.pc
  mkdir -p "$tmp/"{include,lib/pkgconfig}
  cp -r include/openssl "$tmp/include/"
  cp libcrypto.a "$tmp/lib/"
  cp libcrypto.pc "$tmp/lib/pkgconfig"
  popd # third_party/openssl

  echo 'Building libcbor' >&2
  pushd 'third_party/libcbor'
  cmake \
    -DCBOR_CUSTOM_ALLOC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$tmp" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DWITH_EXAMPLES=OFF \
    -G "Unix Makefiles" \
    .
  make
  make install
  popd # third_party/libcbor

  echo 'Building libfido2' >&2
  pushd 'third_party/libfido2'
  cmake \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_MANPAGES=OFF \
    -DBUILD_TOOLS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$tmp" \
    -G "Unix Makefiles" \
    .
  make
  make install
  popd # third_party/libfido2

  local dist="dist/$target"
  rm -fr "$dist"
  mkdir -p "$dist/lib"
  cp -r "$tmp/include" "$dist/"
  cp -r "$tmp/lib"/lib{cbor,crypto,fido2}.a "$dist/lib/"

  cat >"$dist/README" <<EOF
openssl: $(cd third_party/openssl; git rev-parse HEAD)
libfido2: $(cd third_party/libfido2; git rev-parse HEAD)
libcbor: $(cd third_party/libcbor; git rev-parse HEAD)
EOF
}

main "$@"
