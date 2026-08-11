# End-to-end local setup

This guide installs and runs the React frontend, .NET 8 Azure Function backend, and PostgreSQL database locally. Commands are for Windows PowerShell.

## 1. Install prerequisites

Run these installation commands in PowerShell **as Administrator**, then close and reopen PowerShell before verifying each tool.

### Node.js (React frontend)

```powershell
winget install OpenJS.NodeJS.LTS
node --version
npm --version
```

### .NET 8 SDK (Function backend)

```powershell
winget install Microsoft.DotNet.SDK.8
dotnet --version
```

The SDK version must start with `8.`.

### Azure Functions Core Tools v4

```powershell
winget install Microsoft.AzureFunctionsCoreTools
func --version
```

### Docker Desktop (recommended for local PostgreSQL)

```powershell
winget install Docker.DockerDesktop
docker --version
```

Open Docker Desktop and wait until Docker is running. If it requests a restart, restart Windows first.

### Optional: Azure CLI (only for Azure deployment)

```powershell
winget install Microsoft.AzureCLI
az login
az version
```

## 2. Go to the project

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo
```

## 3. Start PostgreSQL and create its table

Start a local PostgreSQL 16 container:

```powershell
docker run --name crud-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=cruddb -p 5432:5432 -d postgres:16
```

Load the products table and seed records:

```powershell
Get-Content .\database\schema.sql -Raw | docker exec -i crud-postgres psql -U postgres -d cruddb
docker exec crud-postgres psql -U postgres -d cruddb -c "SELECT id, name, price FROM products;"
```

The output should contain Laptop, Mouse, and Keyboard. To resume the database later, use `docker start crud-postgres`.

## 4. Configure and run the .NET backend

Open a **new PowerShell window** and run:

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo\backend\AzureReactCrudFunction
Copy-Item local.settings.json.example local.settings.json
dotnet restore
dotnet build
func start
```

Keep this window open. The Function API listens at `http://localhost:7071`; test it in another terminal:

```powershell
curl http://localhost:7071/api/products
```

`local.settings.json` is preconfigured for the Docker database. Do not commit this file if you change its password.

## 5. Configure and run the React frontend

Open a **second new PowerShell window** and run:

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo\frontend
Copy-Item .env.example .env
npm install
npm run dev
```

Open Vite's displayed URL, normally `http://localhost:5173`. The `.env` value below makes React call the local Function API:

```text
VITE_API_BASE_URL=http://localhost:7071/api
```

## 6. Test the full application

In the browser, use **Add product**, **Edit**, and **Delete**. Refresh the page afterward; PostgreSQL persists the changes.

You can also test each API operation:

```powershell
curl http://localhost:7071/api/products
curl -X POST http://localhost:7071/api/products -H "Content-Type: application/json" -d '{\"name\":\"Monitor\",\"description\":\"27 inch display\",\"price\":22000}'
curl -X PUT http://localhost:7071/api/products/1 -H "Content-Type: application/json" -d '{\"name\":\"Updated Laptop\",\"description\":\"Updated description\",\"price\":80000}'
curl -X DELETE http://localhost:7071/api/products/1
```

## 7. Stop or reset the local environment

Use `Ctrl+C` to stop the frontend and Function. To stop PostgreSQL while retaining its data:

```powershell
docker stop crud-postgres
```

To delete the local PostgreSQL container and its data entirely:

```powershell
docker rm -f crud-postgres
```

## Troubleshooting

- **Command not recognized:** reopen PowerShell after installing Node, .NET, Core Tools, or Docker. Restart Windows if needed.
- **Docker is not running:** start Docker Desktop, then run `docker start crud-postgres`.
- **Port 5432 in use:** stop the other PostgreSQL service or change the Docker port and `local.settings.json` connection string.
- **Port 7071 in use:** stop the already-running Function process.
- **CORS error in browser:** ensure `.env` says `http://localhost:7071/api`, then restart Vite.
- **Function database error:** ensure `docker ps` shows `crud-postgres`, and rerun the schema command in step 3.

For Azure deployment, see [README.md](README.md).
