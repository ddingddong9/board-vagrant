#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./prepare.sh
vagrant validate
provider="${VAGRANT_DEFAULT_PROVIDER:-vmware_desktop}"
for role in db was web; do
  vagrant up "$role" --provider="$provider"
done
./check.sh
