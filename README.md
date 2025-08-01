# appcircle-lambdatest-espresso-app-automate-component

Run your Espresso tests on LambdaTest App Automate

## Required Inputs

- `AC_LT_USERNAME`: LambdaTest username. Username of the LambdaTest account.
- `AC_LT_ACCESS_KEY`: LambdaTest access key. Access key for the LambdaTest account.
- `AC_APK_PATH`: Path of the apk. Full path of the apk file
- `AC_TEST_APK_PATH`: Path of the test apk. Path for the generated *androidTest.apk file
- `AC_LT_TIMEOUT`: Timeout. LambdaTest plan timeout in seconds


## Optional Inputs

- `AC_LT_PAYLOAD`: Build Payload. `AC_LT_APP_URL` and `AC_LT_TEST_URL` will be auto generated. Please check [documentation](https://www.lambdatest.com/support/docs/getting-started-with-espresso-testing) for more details about the payload.

## Outputs

- `AC_LT_TEST_RESULT_PATH`: Path to save test results from LambdaTest. It should be a writable directory, by default under `AC_OUTPUT_DIR`."