# attack-data-local-agent

Start with:

```bash
docker compose up -d
```

Stop with 

```bash
docker compose down
```

Stop and remove volumns with 
```bash 
docker compose down -v
```

Check you memory and adjust with `df -h .` in your project directory. 
The example below shows Avail with 23 Gibibyes which is ~24 GBs. 
```bash
 % df -h .
Filesystem      Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1   228Gi   165Gi    23Gi    88%    2.0M  237M    1%   /System/Volumes/Data
```

check the healthcheck logs running the below in the project directory [1]:
```bash 
docker inspect attack-neo4j --format='{{json .State.Health}}' | jq
```
e.g. 
```bash
 % docker inspect attack-neo4j --format='{{json .State.Health}}' | jq

{
  "Status": "healthy",
  "FailingStreak": 0,
  "Log": [...]
  ...
}
```

We use apoc to to load json directly. 
I am applying to docker compose what is recommended in the docs on docker run in the APOC docs. [2]

Note that i found in APOC 5.x we must explicitly allowlist remote URL prefixes. [3]

In the Neo4j UI, run the following to use apoc.periodic.iterate to batch-process in the UI. This dynamically adds typed labels like :AttackPattern, :IntrusionSet, :Malware alongside the base :STIXObject label.

```
CALL apoc.periodic.iterate(
  'CALL apoc.load.json("https://raw.githubusercontent.com/mitre-attack/attack-stix-data/master/enterprise-attack/enterprise-attack.json")
   YIELD value
   UNWIND value.objects AS obj
   WITH obj WHERE obj.type <> "relationship" AND obj.id IS NOT NULL
   RETURN obj',
  'MERGE (n:STIXObject {stix_id: obj.id})
   SET n.type        = obj.type,
       n.name        = obj.name,
       n.description = obj.description,
       n.created     = obj.created,
       n.modified    = obj.modified
   WITH n, obj
   CALL apoc.create.addLabels(n, [apoc.text.capitalize(replace(obj.type, "-", "_"))]) YIELD node
   RETURN node',
  {batchSize: 500, iterateList: true}
)
```
apoc.text.join([part IN split(obj.type, '-') | apoc.text.capitalize(part)], '')

This command creaetes labels. 
Bedlow is the ASCII copied from the Neo4j UI when calling `CALL db.labels()`:
╒════════════════════════════╕
│label                       │
╞════════════════════════════╡
│"STIXObject"                │
├────────────────────────────┤
│"X_mitre_collection"        │
├────────────────────────────┤
│"X_mitre_matrix"            │
├────────────────────────────┤
│"Course_of_action"          │
├────────────────────────────┤
│"Malware"                   │
├────────────────────────────┤
│"Tool"                      │
├────────────────────────────┤
│"X_mitre_tactic"            │
├────────────────────────────┤
│"Attack_pattern"            │
├────────────────────────────┤
│"X_mitre_analytic"          │
├────────────────────────────┤
│"X_mitre_data_component"    │
├────────────────────────────┤
│"X_mitre_data_source"       │
├────────────────────────────┤
│"Intrusion_set"             │
├────────────────────────────┤
│"Campaign"                  │
├────────────────────────────┤
│"X_mitre_detection_strategy"│
├────────────────────────────┤
│"Identity"                  │
├────────────────────────────┤
│"Marking_definition"        │
└────────────────────────────┘

We can now look up by label:
e.g. 
```bash
MATCH (n:Attack_pattern) 
RETURN n.name, n.stix_id 
ORDER BY n.name 
LIMIT 20
```

Next we need to also import the relationships 

```bash
CALL apoc.periodic.iterate(
  'CALL apoc.load.json("https://raw.githubusercontent.com/mitre-attack/attack-stix-data/master/enterprise-attack/enterprise-attack.json")
   YIELD value
   UNWIND value.objects AS obj
   WITH obj WHERE obj.type = "relationship"
   RETURN obj',
  'MATCH (src:STIXObject {stix_id: obj.source_ref})
   MATCH (tgt:STIXObject {stix_id: obj.target_ref})
   MERGE (src)-[r:STIX_REL {stix_id: obj.id}]->(tgt)
   SET r.relationship_type = obj.relationship_type',
  {batchSize: 500, iterateList: true}
)
```

== References ==
[1] https://jqlang.org/
[2] https://github.com/neo4j/apoc
[3] https://stackoverflow.com/questions/79332692/setting-the-apoc-import-file-enabled-true-in-the-neo4j-conf
[4] https://community.neo4j.com/t/how-to-batch-json-records-using-apoc-library-for-better-importing/45928/2
