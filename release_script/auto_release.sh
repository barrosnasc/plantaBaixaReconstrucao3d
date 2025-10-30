#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
COUNT_FILE="$SCRIPT_DIR/release_count.txt"
PDF_PATH="$PROJECT_ROOT/ProjetoDePesquisa.pdf"

# Dica: configure o hook local em `.git/hooks/post-commit` chamando este script
# e confirme que o GitHub CLI está autenticado (`gh auth status`) antes de usar.

if [[ ! -f "$PDF_PATH" ]]; then
  echo "Arquivo PDF não encontrado em: $PDF_PATH" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) não encontrado no PATH." >&2
  exit 1
fi

current=0
last_sha=""
if [[ -f "$COUNT_FILE" ]]; then
  read -r stored_count stored_sha < "$COUNT_FILE"
  if [[ -n "${stored_count:-}" ]]; then
    if ! [[ "$stored_count" =~ ^[0-9]+$ ]]; then
      echo "Valor inválido do contador em $COUNT_FILE" >&2
      exit 1
    fi
    current="$stored_count"
  fi
  if [[ -n "${stored_sha:-}" && "$stored_sha" != "-" ]]; then
    if ! [[ "$stored_sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
      echo "Valor inválido de SHA em $COUNT_FILE" >&2
      exit 1
    fi
    last_sha="$stored_sha"
  fi
fi

pdf_sha="$(sha256sum "$PDF_PATH" | awk '{print $1}')"

if [[ -n "$last_sha" && "$pdf_sha" == "$last_sha" ]]; then
  echo "PDF não alterado desde o último release; nenhum release criado."
  exit 0
fi

next=$((current + 1))
tag="auto-release-${next}"
title="Auto Release ${next}"
commit_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"

cd "$PROJECT_ROOT"

if gh release view "$tag" >/dev/null 2>&1; then
  echo "Release com tag $tag já existe." >&2
  exit 1
fi

gh release create "$tag" "$PDF_PATH" \
  --title "$title" \
  --notes "Release gerado automaticamente para o commit ${commit_sha}."

echo "$next $pdf_sha" > "$COUNT_FILE"
