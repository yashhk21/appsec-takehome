import subprocess


def run_user_command(cmd: str) -> str:
    """Runs an operator-supplied shell command. Flagged by B602
    (subprocess_popen_with_shell_equals_true) at HIGH severity - shell=True
    with a caller-controlled string is a genuine command-injection risk.
    """
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout


def list_tmp_dir() -> str:
    """Also flagged by B602, but at LOW severity - the shell string here is
    a hardcoded literal, not attacker-influenced, so bandit's own
    confidence/severity heuristic for this rule rates it far less risky
    than run_user_command() above despite being the same rule ID.
    """
    result = subprocess.run("ls -la /tmp", shell=True, capture_output=True, text=True)
    return result.stdout


def evaluate_expression(expr: str):
    """Flagged by B307 (eval used) - arbitrary code execution risk if
    `expr` is ever attacker-influenced.
    """
    return eval(expr)


def evaluate_trusted_constant():
    """Also calls eval(), but only ever on a hardcoded literal we control -
    not attacker-reachable. Suppressed inline with `# nosec B307` rather
    than disabling the B307 rule globally, so real eval() usage elsewhere
    (evaluate_expression above) still gets caught.
    """
    return eval("2 ** 10")  # nosec B307
