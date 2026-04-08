from strands import tool
from attack_db.helpers import run_query, safe_response


@tool
def technique_detail(technique_id: str) -> str:
    """Return detection strategies and mitigations for one technique.
    Use an ATT&CK ID like T1059.001.
    """
    base = run_query("""
        MATCH (tech:AttackPattern)
        WHERE tech.attack_id = $t
        RETURN tech.attack_id AS id, tech.name AS name,
               tech.x_mitre_platforms AS platforms
    """, t=technique_id)
    if not base:
        return f"No technique found for {technique_id}."
    info = base[0]
    det = run_query("""
        MATCH (tech:AttackPattern {attack_id: $t})
        MATCH (ds:XMitreDetectionStrategy)-[:STIX_REL {relationship_type: 'detects'}]->(tech)
        RETURN ds.name AS name
    """, t=technique_id)
    mit = run_query("""
        MATCH (tech:AttackPattern {attack_id: $t})
        MATCH (m:CourseOfAction)-[:STIX_REL {relationship_type: 'mitigates'}]->(tech)
        RETURN m.name AS name
    """, t=technique_id)
    det_names = [d["name"] for d in det]
    mit_names = [m["name"] for m in mit]
    parts = [
        f"{info['id']} {info['name']}",
        f"Platforms: {', '.join(info['platforms'] or [])}",
        f"Detections ({len(det_names)}): {', '.join(det_names) if det_names else 'NONE'}",
        f"Mitigations ({len(mit_names)}): {', '.join(mit_names) if mit_names else 'NONE'}",
    ]
    return safe_response("\n".join(parts))
