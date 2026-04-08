
from attack_db.connection import driver


def run_query(cypher, **params):
    with driver.session() as s:
        return s.run(cypher, parameters=params).data()


def safe_response(text, MAX_CHARS=500):

    # this truncate responses that exceed MAX_CHARS with a filter hint
    if len(text) > MAX_CHARS:
        return (
            f"Response too large ({len(text)} chars). "
            "Narrow your query with filters (detection_gap=true, min_group_usage, or pick a specific tactic)."
        )
    return text
