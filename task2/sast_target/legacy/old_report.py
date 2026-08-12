def legacy_report_query(conn, region: str):
    """Same string-built-query pattern as app/db.py (would trip B608), but
    this file lives under sast_target/legacy/, which config/bandit.yaml
    excludes via exclude_dirs. Frozen, unmaintained reporting code slated
    for deletion - not worth carrying findings for until it's actually
    touched again.
    """
    cursor = conn.cursor()
    query = "SELECT * FROM sales_report WHERE region = '%s'" % region
    cursor.execute(query)
    return cursor.fetchall()
