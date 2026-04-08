// Uniqueness constraint — makes reruns safe even if the sentinel is deleted.
CREATE CONSTRAINT stix_id_unique IF NOT EXISTS
FOR (n:STIXObject) REQUIRE n.stix_id IS UNIQUE;

// Import all ATT&CK objects as nodes.
// Each node gets a :STIXObject label, plus a CamelCase convenience label.
// Enriched with ATT&CK-specific fields for operator queries:
//   - attack_id / attack_url from external_references
//   - kill_chain_phases (tactic shortnames) on techniques
//   - x_mitre_platforms, x_mitre_shortname
//   - revoked / x_mitre_deprecated for filtering stale objects
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
       n.modified    = obj.modified,
       n.revoked     = coalesce(obj.revoked, false),
       n.x_mitre_deprecated    = coalesce(obj["x_mitre_deprecated"], false),
       n.x_mitre_platforms     = coalesce(obj["x_mitre_platforms"], []),
       n.x_mitre_shortname     = obj["x_mitre_shortname"],
       n.x_mitre_is_subtechnique = coalesce(obj["x_mitre_is_subtechnique"], false),
       n.kill_chain_phases     = [kc IN coalesce(obj.kill_chain_phases, []) | kc.phase_name],
       n.attack_id  = head([
         ref IN coalesce(obj.external_references, [])
         WHERE ref.source_name = "mitre-attack" | ref.external_id
       ]),
       n.attack_url = head([
         ref IN coalesce(obj.external_references, [])
         WHERE ref.source_name = "mitre-attack" | ref.url
       ])
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

// Import STIX relationship objects as edges.
// Only creates edges when both source and target nodes exist.
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

// Convenience edge: technique -[:IN_TACTIC]-> tactic
// Materializes the kill_chain_phases <-> x_mitre_shortname join.
CALL apoc.periodic.iterate(
  'MATCH (tech:AttackPattern)
   WHERE tech.kill_chain_phases IS NOT NULL
   UNWIND tech.kill_chain_phases AS phase
   RETURN tech, phase',
  'MATCH (tac:XMitreTactic {x_mitre_shortname: phase})
   MERGE (tech)-[:IN_TACTIC]->(tac)',
  {batchSize: 500, iterateList: true}
);

// NOTE: data component -> data source link (x_mitre_data_source_ref) is
// empty in the current bundle — known upstream issue in attack-stix-data.
// Data components also have no STIX relationship objects linking them to
// techniques. Detection strategies (x-mitre-detection-strategy) with
// relationship_type "detects" are the working telemetry layer instead.
