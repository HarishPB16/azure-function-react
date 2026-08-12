Push / Merge to main
        ↓
Check Branch
        ↓
Is branch = main?
        ↓
       YES
        ↓
Start GitHub Actions
        ↓
Create Temporary Ubuntu Runner
        ↓
Checkout main Branch
        ↓
Setup Node.js v20
        ↓
npm ci
        ↓
Run Lint
        ↓
Run Unit Tests
        ↓
npm run build
        ↓
Generate dist/
        ↓
GitHub Actions 
Connect to the Azure via 
(settings -> secrets and variables -> Action)
(AZURE_STATIC_WEB_APPS_API_TOKEN, )
Ubuntu Runner create dist/ floder and deploy on azure  
        ↓
Authenticate with Azure
        ↓
Connect to Azure Static Web Apps
        ↓
Upload React Build
        ↓
Azure Publishes Application
        ↓
Deployment Successful
        ↓
Production React Application Live

------------------------------------------------------------------


Create Azure resources

For the React-only application, create:

Azure
Azure Subscription
       |
       +-- Resource Group
              |
              +-- Azure Static Web App

For example:

Resource Group:
rg-react-prod

Static Web App:
swa-react-prod

You don't need:

Azure VM
Docker
AKS
ECS
EC2
App Service

for a simple React SPA.

Azure Static Web Apps is specifically intended for this type of frontend deployment.

5. Configure React SPA routing

This is very important.

If your React application has:

/login
/dashboard
/users
/settings

and you refresh:

https://yourapp.com/dashboard

the server needs to return index.html.

Create:

staticwebapp.config.json

with:

{
  "navigationFallback": {
    "rewrite": "/index.html",
    "exclude": [
      "*.{css,scss,js,png,gif,jpg,jpeg,svg,ico,json,woff,woff2,ttf,eot}"
    ]
  }
}

Azure specifically supports navigationFallback for SPA client-side routing.

6. GitHub → Azure authentication

Do not put an Azure password or long-lived secret into your workflow.

Use:

GitHub Actions + Microsoft Entra ID + OIDC

The authentication flow is:

GitHub Actions
      |
      | OIDC token
      v
Microsoft Entra ID
      |
      | Federated Identity
      v
Azure Subscription
      |
      v
Static Web App

Microsoft recommends OpenID Connect for GitHub Actions authentication because it uses short-lived tokens.

You need:

AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID

GitHub/Azure documentation confirms these values are used for OIDC authentication.

7. Configure GitHub secrets/variables

Go to:

GitHub
→ Repository
→ Settings
→ Secrets and variables
→ Actions

For OIDC, configure:

AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID

Also keep application-specific values separate.

For example:

Environment Variables

VITE_API_URL
VITE_APP_ENV

Important: React environment variables are generally visible in the browser after build. Never put:

DB_PASSWORD
AWS_SECRET_ACCESS_KEY
PRIVATE_KEY
API_SECRET

inside React environment variables.

8. Pull Request validation pipeline

Create:

.github/workflows/pr-validation.yml

The purpose is:

Feature branch
     |
     v
Pull Request
     |
     +--> npm ci
     +--> lint
     +--> test
     +--> build
     |
     v
PR can be merged

Example:

name: PR Validation

on:
  pull_request:
    branches:
      - main

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint --if-present

      - name: Unit tests
        run: npm test -- --watchAll=false --if-present

      - name: Build
        run: npm run build

This pipeline does not deploy.

9. Production deployment pipeline

This is the most important part.

Create:

.github/workflows/deploy.yml

The trigger should be:

on:
  push:
    branches:
      - main

That means:

push feature branch
       ↓
NO deployment

PR created
       ↓
NO production deployment

PR approved
       ↓
NO deployment

feature → main merged
       ↓
push to main
       ↓
DEPLOYMENT
10. Recommended deployment workflow

For example:

name: Deploy React to Azure

on:
  push:
    branches:
      - main

permissions:
  contents: read
  id-token: write

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    environment:
      name: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint --if-present

      - name: Unit tests
        run: npm test -- --watchAll=false --if-present

      - name: Build React application
        run: npm run build

      # Azure deployment step goes here

The exact Azure deployment action depends on whether you choose Azure Static Web Apps or Azure App Service.

For your React-only application, I would use Azure Static Web Apps.

11. Very important: don't let feature branches deploy

Your deployment workflow must not have:

on:
  push:
    branches:
      - "**"

❌ Don't do that.

Instead:

on:
  push:
    branches:
      - main

This is your deployment gate.

12. Protect the main branch

This is equally important.

Go to:

GitHub
→ Settings
→ Branches
→ Branch protection rules

Configure main.

Recommended:

☑ Require a pull request before merging

☑ Require approvals

☑ Dismiss stale approvals

☑ Require status checks to pass

☑ Require branches to be up to date

☑ Restrict direct pushes to main

☑ Do not allow force pushes

Then the developer cannot simply do:

git push origin main

Instead:

feature/login
      |
      v
Pull Request
      |
      +-- Build
      +-- Test
      +-- Lint
      |
      v
Approval
      |
      v
Merge
      |
      v
main
13. Complete CI/CD flow

This is the flow I recommend for your project:

                 DEVELOPER
                     |
                     v
              feature/login
                     |
                     |
                git push
                     |
                     v
                 GitHub
                     |
                     v
              Pull Request
                     |
                     v
             PR Validation
             ┌─────────────┐
             │ npm ci      │
             │ lint        │
             │ unit tests  │
             │ build       │
             └─────────────┘
                     |
                 PASS?
                /     \
              NO       YES
              |         |
              v         v
           Fix code   Approval
                        |
                        v
               Merge → main
                        |
                        v
                 GitHub Actions
                        |
              ┌─────────┴─────────┐
              |                   |
          npm ci               Security
              |                checks
              v                   |
          npm lint                |
              |                   |
              v                   |
          npm test                |
              |                   |
              v                   |
         npm run build            |
              |                   |
              └─────────┬─────────┘
                        |
                        v
                Azure Authentication
                        |
                        v
                Azure Static Web App
                        |
                        v
                  PRODUCTION
14. Add security scanning

I would also add:

npm audit

and preferably GitHub's security features:

Dependabot
CodeQL
Secret scanning
Dependency scanning

So your pipeline becomes:

Checkout
   ↓
npm ci
   ↓
Dependency/security check
   ↓
Lint
   ↓
Unit tests
   ↓
Build
   ↓
Deploy
15. Add environment separation

If this is going to become a real production project, don't use only:

Production

Use:

Development
     |
     v
Test / QA
     |
     v
Production

For example:

feature/*
     ↓
PR validation
     ↓
main
     ↓
Production deployment

If you later need QA:

feature/*
     ↓
develop
     ↓
QA
     ↓
main
     ↓
Production
16. Environment variables

For Vite:

.env.development
.env.production

Example:

VITE_API_URL=https://api.example.com
VITE_APP_ENV=production

Then:

const apiUrl = import.meta.env.VITE_API_URL;

But remember:

Anything included in a React/Vite frontend build can ultimately be inspected by the browser.

So don't put secrets there.

17. Deployment verification

Don't stop after Azure says "deployment successful."

Add a smoke test:

Deployment
    ↓
Open application URL
    ↓
HTTP 200?
    ↓
Application loaded?
    ↓
SUCCESS

For example:

curl --fail https://your-app.azurestaticapps.net

You can also use Playwright for:

Open application
Check login page
Check main page
Check critical API
18. Rollback

You should also plan for:

Version 105 → deployed
       ↓
Production problem
       ↓
Rollback
       ↓
Version 104

Keep Git history clean:

main

v1.0.0
v1.0.1
v1.0.2

Create Git tags for production releases:

git tag v1.0.0
git push origin v1.0.0
19. Monitoring

For production, include:

Azure
 |
 +-- Application Insights / monitoring where applicable
 |
 +-- Deployment logs
 |
 +-- Availability monitoring
 |
 +-- Error monitoring

For frontend errors, you can also use something like:

Sentry

or another frontend monitoring solution.

20. Final checklist
GitHub
 Create repository
 Create main
 Developers use feature/*
 Configure Pull Requests
 Protect main
 Require PR approval
 Require status checks
 Disable direct production pushes
React
 package.json
 package-lock.json
 ESLint
 Unit tests
 Production build
 Environment configuration
 staticwebapp.config.json
 SPA fallback configuration
Azure
 Azure subscription
 Resource group
 Azure Static Web App
 Production environment
 Custom domain if required
 HTTPS
 Monitoring
Security
 Microsoft Entra application/identity
 Federated credential
 GitHub OIDC
 AZURE_CLIENT_ID
 AZURE_TENANT_ID
 AZURE_SUBSCRIPTION_ID
 Least-privilege Azure RBAC
 GitHub secret scanning
 Dependency scanning
 No secrets in React code
CI
 Checkout
 Node setup
 npm ci
 Lint
 Unit tests
 Build
 Security checks
CD
 Trigger only on main
 Authenticate to Azure
 Deploy React build
 Verify deployment
 Monitor deployment
 Rollback strategy
The key rule for your requirement

Your GitHub Actions workflow should essentially have:

on:
  push:
    branches:
      - main

So this does not deploy:

feature/login → push

This does deploy:

feature/login
      ↓
Pull Request
      ↓
Review + checks
      ↓
Merge
      ↓
main
      ↓
GitHub Actions
      ↓
Build
      ↓
Test
      ↓
Azure Static Web App

Azure's current GitHub integration supports GitHub Actions, and Microsoft recommends OIDC for secure Azure authentication.

Microsoft: Deploy React to Azure Static Web Apps
Microsoft: GitHub Actions + Azure OIDC
Microsoft: Azure Static Web Apps configuration

If you're building this from scratch, the next practical step is to create the React project + Azure Static Web App + GitHub repository and then add the two workflow files above.