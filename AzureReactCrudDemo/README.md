# AzureReactCrudDemo

A deliberately small, working CRUD sample: React/Vite calls a .NET 8 isolated Azure Function REST API, which reads and writes PostgreSQL using parameterized Npgsql SQL.

## Architecture

```text
React SPA (Vite / Azure Storage static website)
        | HTTPS REST (/api/products)
Azure Function App (.NET 8 isolated worker)
        | SSL PostgreSQL connection
Azure Database for PostgreSQL Flexible Server
```

## Prerequisites

- Node.js 20+ and npm
- .NET 8 SDK
- Azure Functions Core Tools v4
- PostgreSQL 15+ (and `psql`) for local database work
- Azure CLI and an authenticated Azure subscription for deployment

## Project structure

```text
AzureReactCrudDemo/
├── frontend/                         # React TypeScript SPA
│   ├── src/components/ProductForm.tsx # Add/edit form and client validation
│   ├── src/components/ProductTable.tsx# Product list/actions
│   ├── src/services/productService.ts # Axios REST client
│   └── src/types/product.ts           # Shared UI data types
├── backend/AzureReactCrudFunction/
│   ├── Functions/ProductFunctions.cs  # HTTP REST endpoints
│   ├── Data/ProductRepository.cs      # Parameterized Npgsql CRUD queries
│   ├── Models/Product.cs               # API models
│   └── Program.cs                      # Functions DI setup
├── database/schema.sql                # Table and seed data
├── infrastructure/deploy.ps1          # Windows PowerShell deployment
├── infrastructure/deploy.sh           # Bash deployment
└── README.md
```

## Local setup

From this project directory:

```powershell
# 1. Start PostgreSQL (Docker alternative)
docker run --name crud-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=cruddb -p 5432:5432 -d postgres:16
psql -h localhost -U postgres -d cruddb -f .\database\schema.sql

# 2. Configure and start the Function API (new terminal)
Copy-Item .\backend\AzureReactCrudFunction\local.settings.json.example .\backend\AzureReactCrudFunction\local.settings.json
Set-Location .\backend\AzureReactCrudFunction
dotnet restore
dotnet build
func start

# 3. Configure and start React (another terminal)
Set-Location .\frontend
Copy-Item .env.example .env
npm install
npm run dev
```

Open `http://localhost:5173`. The Vite frontend calls `http://localhost:7071/api` (from `.env`). For a non-Docker PostgreSQL server, create database `cruddb`, update the copied `local.settings.json`, then run `psql -f database/schema.sql`.

## API

| Method | URL | Result |
| --- | --- | --- |
| GET | `/api/products` | List products |
| GET | `/api/products/{id}` | One product or 404 |
| POST | `/api/products` | Create (201) |
| PUT | `/api/products/{id}` | Update or 404 |
| DELETE | `/api/products/{id}` | Delete (204) or 404 |

```powershell
curl http://localhost:7071/api/products
curl http://localhost:7071/api/products/1
curl -X POST http://localhost:7071/api/products -H "Content-Type: application/json" -d '{\"name\":\"Laptop\",\"description\":\"Development laptop\",\"price\":75000}'
curl -X PUT http://localhost:7071/api/products/1 -H "Content-Type: application/json" -d '{\"name\":\"Updated Laptop\",\"description\":\"Updated description\",\"price\":80000}'
curl -X DELETE http://localhost:7071/api/products/1
```

Requests are validated. The repository exclusively uses Npgsql parameters; it does not concatenate user input into SQL. The Function produces JSON status responses and structured logs.

## Configuration

| Location | Variable | Purpose |
| --- | --- | --- |
| `frontend/.env` | `VITE_API_BASE_URL` | Function API base URL |
| Function settings | `ConnectionStrings__Postgres` | PostgreSQL Npgsql connection string |

Never commit `.env`, `local.settings.json`, or deployment passwords. Local connections can use `SSL Mode=Disable`; Azure connections must use `SSL Mode=Require`.

## Deploy to Azure

Choose globally unique lowercase names for the storage account, Function app, and PostgreSQL server. Sign in first: `az login`.

```powershell
Set-Location .\infrastructure
.\deploy.ps1 -ResourceGroup rg-azure-react-crud -Location eastus -StorageAccount azreactcrud12345 -FunctionApp azreactcrud-api-12345 -PostgresServer azreactcrud-pg-12345 -PostgresUser pgadmin -PostgresPassword 'Use-A-Strong-Password!'
```

The PowerShell script creates the resource group, Storage account/static website, PostgreSQL Flexible Server/database, Function app, PostgreSQL connection setting, CORS rule, builds both applications, deploys the Function ZIP, uploads `frontend/dist` to `$web`, and prints the website/API URLs. If `psql` is unavailable, it clearly warns; run `database/schema.sql` against the Azure database before using the API.

Bash equivalent:

```bash
export RESOURCE_GROUP=rg-azure-react-crud LOCATION=eastus STORAGE_ACCOUNT=azreactcrud12345 FUNCTION_APP=azreactcrud-api-12345 POSTGRES_SERVER=azreactcrud-pg-12345 POSTGRES_USER=pgadmin POSTGRES_PASSWORD='Use-A-Strong-Password!'
./infrastructure/deploy.sh
```

The script limits Function CORS to the exact Storage static website endpoint. Local CORS permits only `http://localhost:5173`; neither configuration uses `*`.

## Testing

Run the API commands above and use the browser UI to add, edit, and delete a product. Confirm changes persist by refreshing the page or calling GET again. Build checks:

```powershell
Set-Location .\frontend; npm run build
Set-Location ..\backend\AzureReactCrudFunction; dotnet build
```

## Troubleshooting

- **Browser CORS error:** confirm the frontend `.env` URL and Function CORS origin; restart Vite after changing `.env`.
- **Database connection fails:** ensure PostgreSQL is running locally and `ConnectionStrings__Postgres` matches it. For Azure use port 5432 and `SSL Mode=Require`.
- **Function does not start:** install .NET 8 and Functions Core Tools v4, then copy `local.settings.json.example`.
- **Azure schema missing:** run `database/schema.sql` through `psql` or Azure Cloud Shell after allowing that client IP in the PostgreSQL firewall.

## Cleanup

```powershell
az group delete --name rg-azure-react-crud --yes --no-wait
docker rm -f crud-postgres
```

## Production improvements

This intentionally excludes authentication, Key Vault, VNet/private endpoints, API Management, Front Door, WAF, CDN, Redis, Service Bus, and Event Grid. Before production, add managed identity/secret management, authentication and authorization, private networking, least-privilege database roles, migrations, monitoring/alerts, automated tests and CI/CD. Public PostgreSQL access is acceptable only for this first development deployment; use VNet integration and private endpoints in production.
