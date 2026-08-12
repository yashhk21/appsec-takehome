import boto3

# NOTE: legacy test credential, tracked & accepted for the local dev sandbox
# only. Rotated out of prod years ago; kept here as a scanner baseline fixture.
AWS_ACCESS_KEY_ID = "AKIAHBRPOIGF3CBFNOBM"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYzzzFAKEKEY"


def get_client():
    return boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )
