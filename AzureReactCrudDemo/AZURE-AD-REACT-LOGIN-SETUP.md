https://chatgpt.com/c/6a83dec7-0084-83ee-8a98-a3061a532ba8

# Microsoft Entra ID login setup for the React app

The React app is configured for your Microsoft Entra ID application:

- Application (client) ID: `77c11595-d7fd-40b4-ad35-8428c30716ec`
- Directory (tenant) ID: `88889b90-2697-4176-ab38-c9a2b27a470e`
- Account type: **Accounts in this organizational directory only**

The client and tenant IDs are public identifiers. Do not create or put a client secret in this React app; a browser-based SPA cannot keep a secret safe.

`frontend/.env.production` explicitly configures the deployed redirect URL as `https://ashy-rock-03137bd00.7.azurestaticapps.net`. Vite includes this value whenever you run `npm run build`.

## 1. Add the local redirect URI

1. Open [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Go to **App registrations** -> **All applications** -> **My React Application**.
3. Select **Authentication** from the left menu.
4. Select **Add a platform** -> **Single-page application**.
5. Add this redirect URI exactly:

   ```text
   http://localhost:5173
   ```

6. Select **Configure** or **Save**.

## 2. Add the production redirect URI

1. In the same **Authentication** page, select **Add URI** under the **Single-page application** platform.
2. Add the production Azure Static Web Apps URL exactly:

   ```text
   https://ashy-rock-03137bd00.7.azurestaticapps.net
   ```

3. Select **Save**.

The app uses this URL automatically as its redirect and post-logout URL. Do not use a `blob.core.windows.net` URL, because it is not the React website origin.

## 3. Confirm the Entra application configuration

1. On **Authentication**, confirm both redirect URIs are listed under **Single-page application**.
2. On **Overview**, confirm **Supported account types** remains **My organization only**.
3. On **API permissions**, no extra permission is required for basic sign-in. The app only requests the standard OpenID Connect scopes: `openid`, `profile`, and `email`.
4. Do **not** add a client secret. Client secrets are for server-side confidential applications, not React SPAs.

## 4. Configure and run React locally

1. In `frontend`, copy the example configuration:

   ```powershell
   Set-Location E:\Project\ezest\AzureReactCrudDemo\frontend
   Copy-Item .env.example .env
   ```

2. Edit `.env` and set `VITE_API_BASE_URL` to the deployed Function API URL.
3. Install dependencies and start Vite:

   ```powershell
   npm ci
   npm run dev
   ```

4. Open `http://localhost:5173`.
5. Select **Sign in with Microsoft** and sign in with an account from tenant `88889b90-2697-4176-ab38-c9a2b27a470e`.

**Check:** After sign-in, the Products page is displayed and the header shows the signed-in account name. Select **Sign out** to return to the sign-in page.

## 5. Deploy the authenticated React build to Blob Storage

1. From the repository root, set the API URL and build the app:

   ```powershell
   Set-Location E:\Project\ezest\AzureReactCrudDemo
   $env:VITE_API_BASE_URL = 'https://YOUR-FUNCTION-APP.azurewebsites.net/api'
   Push-Location .\frontend
   npm ci
   npm run build
   Pop-Location
   ```

2. Upload `frontend/dist` using Step 6 of [the Blob Storage deployment guide](REACT-AZURE-BLOB-STORAGE-DEPLOYMENT.md).
3. Open the Blob Storage static website URL and select **Sign in with Microsoft**.

**Check:** Entra ID redirects back to `https://ashy-rock-03137bd00.7.azurestaticapps.net`, where the Products page is shown.

## Important API security note

This change protects the React screen, but the current Azure Function API does not yet validate Entra access tokens. Someone who knows the API URL can still call it directly.

Before treating the application as secure, configure the Function App to validate Microsoft Entra tokens (for example, with App Service Authentication / Easy Auth or API-side JWT validation) and require a bearer token on the API endpoints. The API must be registered separately as an API and its scope requested by React.

## Troubleshooting

| Error | Fix |
| --- | --- |
| `AADSTS50011` redirect URI mismatch | Add the exact URL shown in the error to **Authentication -> Single-page application**. The protocol, hostname, port, and trailing path must match. |
| User cannot sign in | The registration is single-tenant, so sign in with an account in the configured tenant only. |
| The old site appears after deployment | Rebuild after setting `VITE_API_BASE_URL`, upload `frontend/dist`, then hard-refresh with `Ctrl+F5`. |
| Sign-in works but product calls fail | Confirm the API URL, Function App CORS settings, database configuration, and API availability. |
