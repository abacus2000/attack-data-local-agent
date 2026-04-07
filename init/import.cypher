// Uniqueness constraint — makes reruns safe even if the sentinel is deleted.
CREATE CONSTRAINT stix_id_unique IF NOT EXISTS
FOR (n:STIXObject) REQUIRE n.stix_id IS UNIQUE;

// Import all ATT&CK objects as nodes.
// Each node gets a :STIXObject label, plus we add a camel case convenience label (e.g., AttackPattern, ...)
CALL apoc.periodic.iterate(
  'CALL apoc.load.json("https://raw.githubusercontent.com/mitre-attack/attack-stix-data/master/enterprise-attack/enterprise-attack.json")
   YIELD value
   UNWIND value.objects AS obj
   WITH obj
   WHERE obj.type <> "relationship"
     AND obj.id IS NOT NULL
   RETURN obj',
  'MERGE (n:STIXObject {stix_id: obj.id})
   SET n.type        = obj.type,
       n.name        = obj.name,
       n.description = obj.description,
       n.created     = obj.created,
       n.modified    = obj.modified
   WITH n, obj
   CALL apoc.create.addLabels(n, [
     apoc.text.join(
       [part IN split(obj.type, "-") | apoc.text.capitalize(part)],
       ""
     )
   ]) YIELD node
   RETURN node',
  {batchSize: 500, iterateList: true}
);

// import STIX relationship objects as edges
// this only creates edges when both source and target nodes exist in the graph...
CALL apoc.periodic.iterate(
  'CALL apoc.load.json("https://raw.githubusercontent.com/mitre-attack/attack-stix-data/master/enterprise-attack/enterprise-attack.json")
   YIELD value
   UNWIND value.objects AS obj
   WITH obj
   WHERE obj.type = "relationship"
     AND obj.id IS NOT NULL
     AND obj.source_ref IS NOT NULL
     AND obj.target_ref IS NOT NULL
   RETURN obj',
  'OPTIONAL MATCH (src:STIXObject {stix_id: obj.source_ref})
   OPTIONAL MATCH (tgt:STIXObject {stix_id: obj.target_ref})
   WITH src, tgt, obj
   WHERE src IS NOT NULL AND tgt IS NOT NULL
   MERGE (src)-[r:STIX_REL {stix_id: obj.id}]->(tgt)
   SET r.relationship_type = obj.relationship_type',
  {batchSize: 500, iterateList: true}
);
