#!/usr/bin/env bash

set -euo pipefail
shopt -s extglob

fun_dir="${FUN_DIR:-.}"
build_dir="$fun_dir/.build"
defn_dir="${FUN_DEFN_DIR:-$build_dir/defn/fun}"
k_release_dir="${K_RELEASE:-${build_dir}/k/k-distribution/target/release/k}"

# Utilities
# ---------

notif() { echo "== $@" >&2 ; }
fatal() { echo "[FATAL] $@" ; exit 1 ; }

pretty_diff() { git --no-pager diff --no-index --ignore-all-space "$@" ; }

# Runners
# -------

# User Commands

run_krun() {
    export K_OPTS=-Xss500m
    krun --directory "$backend_dir" "$run_file" "$@"
}

run_prove() {
    local def_module
    def_module="$1" ; shift
    export K_OPTS=-Xmx8G
    kprove --directory "$backend_dir" "$run_file" --def-module "$def_module" "$@"
}

# Main
# ----

run_command="$1" ; shift

if [[ "$run_command" == 'help' ]] || [[ "$run_command" == '--help' ]] ; then
    echo "
        usage: $0 run   [--backend (llvm|haskell)] <pgm>  <K arg>*
               $0 prove                            <spec> <def_module> <K arg>*

               $0 [help|--help|version|--version]

           $0 run       : Run a single EVM program
           $0 prove     : Run an EVM K proof

           $0 help    : Display this help message.
           $0 version : Display the versions of FUN, K, Kore, and Z3 in use.

           Note: <pgm> is a path to a file containing an EVM program/test.
                 <spec> is a K specification to be proved.
                 <K arg> is an argument you want to pass to K.
                 <def_module> is the module to take as axioms when doing verification.
    "
    exit 0
fi

if [[ "$run_command" == 'version' ]] || [[ "$run_command" == '--version' ]]; then
    notif "FUN Version"
    git rev-parse --short HEAD
    notif "K Version"
    kompile --version
    notif "Kore Version"
    kore-exec --version
    notif "Z3 Version"
    z3 --version
    exit 0
fi

backend="llvm"
[[ ! "$run_command" == 'prove' ]] || backend='haskell'
args=()
while [[ $# -gt 0 ]]; do
    arg="$1"
    case $arg in
        --backend)    args+=("$arg" "$2") ; backend="$2"      ; shift 2 ;;
        --backend-dir)                      backend_dir="$2"  ; shift 2 ;;
        *)            break                                             ;;
    esac
done
backend_dir="${backend_dir:-$defn_dir/$backend}"

# get the run file
run_file="$1" ; shift
if [[ "$run_file" == '-' ]]; then
    tmp_input="$(mktemp)"
    trap "rm -rf $tmp_input" INT TERM EXIT
    cat - > "$tmp_input"
    run_file="$tmp_input"
fi
[[ -f "$run_file" ]] || fatal "File does not exist: $run_file"

case "$run_command-$backend" in
    run-@(llvm|haskell) ) run_krun  "$@" ;;
    prove-haskell       ) run_prove "$@" ;;
    *) $0 help ; fatal "Unknown command on backend: $run_command $backend" ;;
esac

