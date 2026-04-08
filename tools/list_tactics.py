from strands import tool
from attack_db.helpers import run_query, safe_response


@tool
def list_tactics(platform: str) -> str:
    """Return tactics and technique counts for a platform.
    Use this after list_platforms to see what tactics apply.
    """
    rows = run_query("""
        MATCH (tac:XMitreTactic)
        OPTIONAL MATCH (tech:AttackPattern)-[:IN_TACTIC]->(tac)
        WHERE coalesce(tech.revoked, false) = false
          AND coalesce(tech.x_mitre_deprecated, false) = false
          AND any(p IN coalesce(tech.x_mitre_platforms, []) WHERE p IN $platforms)
        WITH tac, count(tech) AS cnt
        WHERE cnt > 0
        RETURN tac.x_mitre_shortname AS shortname, cnt
        ORDER BY cnt DESC
    """, platforms=[platform])
    lines = [f"{r['shortname']}: {r['cnt']}" for r in rows]
    return safe_response(f"Tactics on {platform} (techniques):\n" + "\n".join(lines))
