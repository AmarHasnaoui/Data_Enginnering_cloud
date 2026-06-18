import os
import boto3
from botocore.config import Config
from botocore import UNSIGNED

REGION    = os.environ.get("AWS_REGION", "eu-west-3")
CLIENT_ID = os.environ["COGNITO_CLIENT_ID"]

# Signature UNSIGNED : InitiateAuth est une API publique d'app client Cognito
# (pas de secret, pas de clés AWS nécessaires côté Streamlit).
_client = boto3.client(
    "cognito-idp",
    region_name=REGION,
    config=Config(signature_version=UNSIGNED),
)


def login(username: str, password: str) -> str:
    response = _client.initiate_auth(
        ClientId=CLIENT_ID,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={"USERNAME": username, "PASSWORD": password},
    )
    return response["AuthenticationResult"]["IdToken"]
