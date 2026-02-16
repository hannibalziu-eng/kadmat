#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
cd "$ROOT_DIR"

echo "[Repository Status Summary]"
git status --porcelain=v1 | awk '{print $1}' | sort | uniq -c | sort -nr

echo
echo "[Top Untracked by Root Folder]"
git status --porcelain=v1 \
  | awk '$1=="??"{print $2}' \
  | sed 's#^"##; s#"$##' \
  | cut -d/ -f1 \
  | sort \
  | uniq -c \
  | sort -nr

echo
echo "[Top Modified by Root Folder]"
git status --porcelain=v1 \
  | awk '$1=="M"{print $2}' \
  | sed 's#^"##; s#"$##' \
  | cut -d/ -f1 \
  | sort \
  | uniq -c \
  | sort -nr

echo
echo "[Top Deleted by Root Folder]"
git status --porcelain=v1 \
  | awk '$1=="D"{print $2}' \
  | sed 's#^"##; s#"$##' \
  | cut -d/ -f1 \
  | sort \
  | uniq -c \
  | sort -nr
