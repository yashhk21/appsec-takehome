import requests

# NOTE: fake key for the appsec-takehome demo. Not baselined, and NOT caught
# by the current config either - generic-api-key (the only default rule that
# would match this, since it has no vendor-specific prefix like sk_live_ or
# AKIA) is intentionally disabled in config/gitleaks.toml. This file exists
# to make that trade-off concrete: disabling a noisy rule to cut false
# positives also means a real hardcoded key like this one goes undetected.
# See config/gitleaks.toml and README.md for the full discussion.
PAYMENTS_API_KEY = "a4c123b1612dd272d1371c17149d439536b3216fdaeeb97"


def charge(amount_cents: int, customer_id: str) -> dict:
    resp = requests.post(
        "https://api.example-payments.com/v1/charges",
        headers={"Authorization": f"Bearer {PAYMENTS_API_KEY}"},
        json={"amount": amount_cents, "customer": customer_id},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()
