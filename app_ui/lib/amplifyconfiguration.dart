const amplifyconfig = '''{
  "api": {
    "plugins": {
      "awsAPIPlugin": {
        "graphQlApi": {
          "endpointType": "GraphQL",
          "endpoint": "https://m3mbjmb3vbcupo4emyrmhlzyza.appsync-api.us-east-1.amazonaws.com/graphql",
          "region": "us-east-1",
          "authorizationType": "AMAZON_COGNITO_USER_POOLS"
        },
        "restApi": {
          "endpointType": "REST",
          "endpoint": "https://q696oo06yh.execute-api.us-east-1.amazonaws.com/dev",
          "region": "us-east-1",
          "authorizationType": "AMAZON_COGNITO_USER_POOLS"
        }
      }
    }
  },
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/2.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_7ntr5IC2g",
            "AppClientId": "35akpb6r62eht7n58eu3to2dt0",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [
              "GOOGLE"
            ],
            "usernameAttributes": [
              "EMAIL"
            ],
            "signupAttributes": [
              "EMAIL"
            ],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": []
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": [
              "SMS"
            ],
            "verificationMechanisms": [
              "EMAIL"
            ]
          }
        }
      }
    }
  },
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "mobile-scheduler-dev-voice-files-779846822280",
        "region": "us-east-1",
        "defaultAccessLevel": "private"
      }
    }
  }
}''';
