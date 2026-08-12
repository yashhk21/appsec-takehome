def get_user_by_name(conn, username: str):
    """Flagged by B608 (hardcoded_sql_expressions) - query string is built
    with string interpolation instead of parameter binding, so a crafted
    `username` can alter the query.
    """
    cursor = conn.cursor()
    query = "SELECT * FROM users WHERE username = '%s'" % username
    cursor.execute(query)
    return cursor.fetchone()
