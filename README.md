# Appcircle _BrowserStack App Automate - Espresso_ component

Run your Espresso tests on BrowserStack App Automate

## Required Inputs

- `AC_BROWSERSTACK_USERNAME`: BrowserStack username. Username of the BrowserStack account.
- `AC_BROWSERSTACK_ACCESS_KEY`: BrowserStack access key. Access key for the BrowserStack account.
- `AC_APK_PATH`: Path of the apk. Full path of the apk file
- `AC_TEST_APK_PATH`: Path of the test apk. Path for the generated *androidTest.apk file
- `AC_BROWSERSTACK_TIMEOUT`: Timeout. BrowserStack plan timeout in seconds

## Optional Inputs

- `AC_BROWSERSTACK_PAYLOAD`: Build Payload. `AC_BROWSERSTACK_APP_URL` and `AC_BROWSERSTACK_TEST_URL` will be auto generated. Please check [documentation](https://www.browserstack.com/docs/app-automate/api-reference/espresso/builds#execute-a-build) for more details about the payload.
