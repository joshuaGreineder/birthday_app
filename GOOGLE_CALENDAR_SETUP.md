# Google Calendar Integration Setup

## Overview
Calendar sync code is in the project and hidden for v1 (`kCalendarSyncEnabled` is false). Startup does not call Google sign-in. The steps below are for a later release that turns the flag on. Do not register the example application id.

## Setup Steps

1. **Create a Google Cloud Project**
   - Go to https://console.cloud.google.com/
   - Create a new project or select an existing one

2. **Enable Google Calendar API**
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click "Enable"

3. **Configure OAuth 2.0 Credentials**
   - Go to "APIs & Services" > "Credentials"
   - If you haven't set up OAuth consent screen, you'll need to do that first:
     * Click "Configure Consent Screen"
     * Choose "External" (unless you have a Google Workspace account)
     * Fill in the required information (App name, User support email, Developer contact)
     * Add scopes: `https://www.googleapis.com/auth/calendar` and `https://www.googleapis.com/auth/calendar.events`
     * Save and continue through the steps
   - Click "Create Credentials" > "OAuth client ID"
   - Choose application type:
     * **For Web**: Select "Web application"
       - Name it (e.g., "Happaroo Web")
       - Add authorized JavaScript origins: `http://localhost:port` (for local testing) or your domain
       - Add authorized redirect URIs: `http://localhost:port` (for local testing) or your domain
       - Click "Create"
       - **Copy the Client ID** (it looks like: `123456789-abcdefghijklmnop.apps.googleusercontent.com`)
   - **For Android**: Select "Android"
     - Add your package name: `com.greinederlabs.happaroo`
     - Add SHA-1 fingerprint (get it using: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`)
     - Click "Create"

4. **Add Configuration to App**
   - **For Web**: 
     * Open `web/index.html`
     * Uncomment the meta tag line: `<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">`
     * Replace `YOUR_CLIENT_ID` with the Client ID you copied (the full value including `.apps.googleusercontent.com`)
   - **For Android**: 
     * The `google_sign_in` package will automatically use the SHA-1 fingerprint configuration
     * No additional code changes needed if credentials are properly configured in Google Cloud Console

## Note on Date API
The `cal.Date` constructor may need adjustment based on your googleapis version. If you encounter errors, check the generated API classes in your `pub cache` or use the Date class constructor with named parameters as shown in the code.

## Contact Import
The contact import feature uses `flutter_contacts` package. Make sure to:
- Request contacts permission in AndroidManifest.xml
- Handle permission requests at runtime

