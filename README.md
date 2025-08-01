# appcircle-lambdatest-espresso-app-automate-component

Run your Espresso tests on LambdaTest App Automate

## Required Inputs

- `LT_USERNAME`: LambdaTest username. Username of the LambdaTest account.
- `LT_ACCESS_KEY`: LambdaTest access key. Access key for the LambdaTest account.
- `APK_PATH`: Path of the apk. Full path of the apk file
- `TEST_APK_PATH`: Path of the test apk. Path for the generated *androidTest.apk file
- `LT_TIMEOUT`: Timeout. LambdaTest plan timeout in seconds


## Optional Inputs

- `LT_PAYLOAD`: Build Payload. `LT_APP_URL` and `LT_TEST_URL` will be auto generated. Please check [documentation](https://www.lambdatest.com/support/docs/getting-started-with-espresso-testing) for more details about the payload.