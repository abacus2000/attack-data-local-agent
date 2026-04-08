from strands import tool
from attack_db.helpers import run_query, safe_response


@tool
def list_platforms() -> str:
    """Return all platforms in the ATT&CK knowledge base.
    Call this first to find out what platforms are available.
    """
    rows = run_query("""
        MATCH (n:AttackPattern)
        WHERE coalesce(n.revoked, false) = false
          AND coalesce(n.x_mitre_deprecated, false) = false
        UNWIND coalesce(n.x_mitre_platforms, []) AS p
        RETURN DISTINCT p AS platform ORDER BY p
    """)
    platforms = [r["platform"] for r in rows]
    return safe_response("Available platforms: " + ", ".join(platforms))
