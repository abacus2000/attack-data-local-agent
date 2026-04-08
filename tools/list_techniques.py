from strands import tool
from attack_db.helpers import run_query, safe_response


@tool
def list_techniques(tactic: str, platform: str,
                    detection_gap: bool = False,
                    min_group_usage: int = 0) -> str:
    """Return techniques for a tactic+platform. If result is too large,
    set detection_gap=true or min_group_usage to narrow down.
    """
    rows = run_query("""
        MATCH (tech:AttackPattern)-[:IN_TACTIC]->(tac:XMitreTactic {x_mitre_shortname: $tactic})
        WHERE coalesce(tech.revoked, false) = false
          AND coalesce(tech.x_mitre_deprecated, false) = false
          AND any(p IN coalesce(tech.x_mitre_platforms, []) WHERE p IN $platforms)
        OPTIONAL MATCH (g:IntrusionSet)-[:STIX_REL {relationship_type: 'uses'}]->(tech)
        OPTIONAL MATCH (ds:XMitreDetectionStrategy)-[:STIX_REL {relationship_type: 'detects'}]->(tech)
        WITH tech, count(DISTINCT g) AS groups, count(DISTINCT ds) AS detections
        WHERE groups >= $min_groups
          AND ($gap = false OR detections = 0)
        RETURN tech.attack_id AS id, tech.name AS name, groups, detections
        ORDER BY groups DESC
    """, tactic=tactic, platforms=[platform], min_groups=min_group_usage, gap=detection_gap)
    lines = [f"{r['id']} {r['name']} g:{r['groups']} d:{r['detections']}" for r in rows]
    header = f"{len(rows)} techniques [{tactic}, {platform}]"
    if detection_gap:
        header += " no-detection"
    if min_group_usage > 0:
        header += f" {min_group_usage}+groups"
    body = header + ":\n" + "\n".join(lines)
    if len(body) <= 500:
        return body
    # Too large — return filter options instead of raw list
    no_det = sum(1 for r in rows if r["detections"] == 0)
    thresholds = [3, 5, 10]
    buckets = [f"{t}+ groups: {sum(1 for r in rows if r['groups'] >= t)}" for t in thresholds]
    return (
        f"{header} — too many to display.\n"
        f"Filter options:\n"
        f"- detection_gap=true → {no_det} techniques with no detection\n"
        f"- min_group_usage: {', '.join(buckets)}"
    )
