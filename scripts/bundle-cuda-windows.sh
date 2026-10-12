#!/usr/bin/env bash
# Stage the CUDA runtime libraries onnxruntime's CUDA execution provider links
# into an already-packaged Windows LivePose directory.
#
# WHY THIS EXISTS AT ALL. Microsoft's onnxruntime-win-x64-gpu archive contains
# onnxruntime_providers_cuda.dll but none of the libraries it links, and
# score-addon-onnx installs exactly what that archive contains. So the shipped
# package only reaches the GPU on a machine that already has a matching CUDA
# install on PATH; anywhere else onnxruntime logs
#
#   Error loading "onnxruntime_providers_cuda.dll" which depends on
#   "cublasLt64_13.dll" which is missing. (Error 126)
#
# and silently falls back to the CPU provider.
#
# WHY HERE AND NOT IN score-addon-onnx. The addon is shared; every tool that
# pulls it in would inherit a CUDA-shipping code path it never asked for.
# LivePose is the app that wants the runtime, so LivePose stages it.
#
# WHY A POST-PACKAGING STEP. The usual trick (koaia's scripts/prepare-package.sh)
# is to drop untracked files next to the .score file, because create-app-windows.sh
# copies that whole directory into the package root:
#
#   cp -r "$SCORE_DIR"/* ./          # tools/create-app-windows.sh:141
#
# LivePose has no score file -- RunView.qml builds the pipeline dynamically, so
# the app ships without one -- and the only other input, --qml, lands in the
# package's qml/ subdirectory, which is not where the Windows loader looks. That
# leaves injecting into the finished package, which is what this does.
#
# WHAT GETS SHIPPED is the import table of onnxruntime_providers_cuda.dll, read
# with `objdump -p`, not a guess:
#
#   cublas64_13.dll  cublasLt64_13.dll  cufft64_12.dll  cudnn64_9.dll
#
# The CUDA runtime proper (cudart) is deliberately absent: it is not imported,
# because CUDA 13's redistributable math libraries and the provider link it
# statically. nvrtc, nvJitLink, npp and curand are likewise unused.
#
# cudnn64_9.dll is only a dispatch shim with no non-system imports of its own; it
# LoadLibrary's cudnn_graph64_9, cudnn_ops64_9, cudnn_cnn64_9, cudnn_adv64_9,
# cudnn_ext64_9 and the engine libraries on demand. Hence the whole cuDNN bin/
# directory ships, not the one DLL the import table names.
#
# cuDNN must be built for the same CUDA major as the onnxruntime archive --
# cuda13 for 1.27.1. NVIDIA ships cuda11/cuda12/cuda13 variants of every cuDNN
# 9.x and pairing the wrong one is the usual mistake.
#
# COST: about 1.3 GB, which roughly quadruples the package.
#
# Usage: bundle-cuda-windows.sh <package-dir|package.zip> [cache-dir]
# A .zip is unpacked, completed and repacked in place.

set -euo pipefail

TARGET="${1:-}"
CACHE_DIR="${2:-${RUNNER_TEMP:-/tmp}/livepose-cuda-redist}"

if [[ -z "$TARGET" ]]; then
  echo "usage: $0 <package-dir|package.zip> [cache-dir]" >&2
  exit 2
fi

# git-bash on the Windows runners ships neither unzip nor zip, so go through
# whichever of unzip/zip/7z is actually present -- the same dance
# score's tools/create-app-windows.sh does.
SEVENZIP="$(command -v 7z || command -v 7za || true)"

unpack() {
  local zip="$1" dir="$2"
  mkdir -p "$dir"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$zip" -d "$dir"
  elif [[ -n "$SEVENZIP" ]]; then
    "$SEVENZIP" x -y -o"$dir" "$zip" >/dev/null
  else
    echo "error: need unzip or 7z to read $zip" >&2
    exit 1
  fi
}

pack() {
  local dir="$1" zip="$2"
  rm -f "$zip"
  if command -v zip >/dev/null 2>&1; then
    (cd "$dir" && zip -qr "$zip" .)
  elif [[ -n "$SEVENZIP" ]]; then
    (cd "$dir" && "$SEVENZIP" a -tzip "$zip" . >/dev/null)
  else
    echo "error: need zip or 7z to write $zip" >&2
    exit 1
  fi
}

REPACK_ZIP=""
if [[ -f "$TARGET" && "$TARGET" == *.zip ]]; then
  REPACK_ZIP="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
  PKG_TMP="$(mktemp -d)"
  PKG_DIR="$PKG_TMP/pkg"
  unpack "$REPACK_ZIP" "$PKG_DIR"
else
  PKG_DIR="$TARGET"
fi

if [[ ! -d "$PKG_DIR" ]]; then
  echo "error: no such package: $TARGET" >&2
  exit 2
fi
if [[ ! -f "$PKG_DIR/onnxruntime_providers_cuda.dll" ]]; then
  echo "error: $PKG_DIR has no onnxruntime_providers_cuda.dll; nothing to complete" >&2
  exit 1
fi

# Pinned to the versions this was validated against. onnxruntime 1.27.1 is the
# gpu_cuda13 archive (score-addon-onnx cmake/onnxruntime.cmake), so these are the
# CUDA 13 / cuFFT 12 sonames its provider imports.
CUBLAS_VER=13.6.0.2
CUFFT_VER=12.3.0.29
CUDNN_VER=9.27.0.42
CUDA_REDIST=https://developer.download.nvidia.com/compute/cuda/redist
CUDNN_REDIST=https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64

fetch() {
  local url="$1" dest="$2"
  [[ -f "$dest" ]] && { echo "  cached $(basename "$dest")"; return; }
  echo "  fetching $(basename "$dest")"
  curl -fsSL --retry 3 -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
}

extract() {
  local zip="$1" dir="$2"
  [[ -d "$dir" ]] || unpack "$zip" "$dir"
}

mkdir -p "$CACHE_DIR"
echo "Staging the CUDA runtime into $PKG_DIR"

cublas_a="libcublas-windows-x86_64-${CUBLAS_VER}-archive"
cufft_a="libcufft-windows-x86_64-${CUFFT_VER}-archive"
cudnn_a="cudnn-windows-x86_64-${CUDNN_VER}_cuda13-archive"

fetch "$CUDA_REDIST/libcublas/windows-x86_64/${cublas_a}.zip" "$CACHE_DIR/${cublas_a}.zip"
fetch "$CUDA_REDIST/libcufft/windows-x86_64/${cufft_a}.zip"   "$CACHE_DIR/${cufft_a}.zip"
fetch "$CUDNN_REDIST/${cudnn_a}.zip"                          "$CACHE_DIR/${cudnn_a}.zip"

extract "$CACHE_DIR/${cublas_a}.zip" "$CACHE_DIR/x/$cublas_a"
extract "$CACHE_DIR/${cufft_a}.zip"  "$CACHE_DIR/x/$cufft_a"
extract "$CACHE_DIR/${cudnn_a}.zip"  "$CACHE_DIR/x/$cudnn_a"

# The archives nest one directory deep; find the real bin/x64 rather than assume.
bin_of() {
  find "$1" -type d -path '*/bin/x64' -print -quit
}

cublas_bin="$(bin_of "$CACHE_DIR/x/$cublas_a")"
cufft_bin="$(bin_of "$CACHE_DIR/x/$cufft_a")"
cudnn_bin="$(bin_of "$CACHE_DIR/x/$cudnn_a")"

install -m 644 "$cublas_bin/cublas64_13.dll"   "$PKG_DIR/"
install -m 644 "$cublas_bin/cublasLt64_13.dll" "$PKG_DIR/"
install -m 644 "$cufft_bin/cufft64_12.dll"     "$PKG_DIR/"
install -m 644 "$cudnn_bin"/cudnn*.dll         "$PKG_DIR/"

# A missing DLL here does not fail the package, it fails at the user's first
# inference with a bare Error 126, so check before shipping.
missing=()
for dll in cublas64_13.dll cublasLt64_13.dll cufft64_12.dll cudnn64_9.dll \
           cudnn_graph64_9.dll cudnn_ops64_9.dll cudnn_cnn64_9.dll; do
  [[ -f "$PKG_DIR/$dll" ]] || missing+=("$dll")
done
if (( ${#missing[@]} )); then
  echo "error: not staged: ${missing[*]}" >&2
  exit 1
fi

# Belt and braces: if a PE reader is around, re-derive the provider's imports and
# confirm every non-system one now resolves inside the package. Keeps this honest
# across an onnxruntime bump, which is exactly when the pinned list goes stale.
objdump_bin="$(command -v llvm-objdump || command -v objdump || true)"
if [[ -n "$objdump_bin" ]]; then
  unresolved=()
  while read -r dep; do
    case "$dep" in
      cublas*|cublasLt*|cudnn*|cufft*|cudart*|nvrtc*|nvJitLink*|curand*|npp*)
        [[ -f "$PKG_DIR/$dep" ]] || unresolved+=("$dep") ;;
    esac
  done < <("$objdump_bin" -p "$PKG_DIR/onnxruntime_providers_cuda.dll" 2>/dev/null \
           | sed -n 's/.*DLL Name: //p' | sort -u)
  if (( ${#unresolved[@]} )); then
    echo "error: onnxruntime_providers_cuda.dll still imports: ${unresolved[*]}" >&2
    echo "       the pinned redistributable set is out of date for this onnxruntime" >&2
    exit 1
  fi
  echo "  import table satisfied"
fi

echo "Staged $(du -sm "$PKG_DIR" | cut -f1) MB total in $PKG_DIR"

if [[ -n "$REPACK_ZIP" ]]; then
  pack "$PKG_DIR" "$REPACK_ZIP"
  echo "Repacked $REPACK_ZIP ($(du -sm "$REPACK_ZIP" | cut -f1) MB)"
  rm -rf "$PKG_TMP"
fi
