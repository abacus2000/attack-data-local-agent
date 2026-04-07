#!/bin/bash
set -eu

INIT_FLAG="/data/.attack-data-initialized"
NEO4J_ADDR="bolt://neo4j:7687"

if [ -f "$INIT_FLAG" ]; then
  echo "ATT&CK data already loaded — skipping import."
  exit 0
fi

echo "First run — starting ATT&CK data import..."
cypher-shell -a "$NEO4J_ADDR" -u "$NEO4J_USERNAME" -p "$NEO4J_PASSWORD" -f /init/import.cypher
touch "$INIT_FLAG"
echo "ATT&CK data import complete."
