# Azure Function API

Copy `local.settings.json.example` to `local.settings.json`, set a local PostgreSQL connection string, then run `func start` from this directory. The API is available at `http://localhost:7071/api/products`.

The Function uses parameterized Npgsql commands and gets its connection string from `ConnectionStrings__Postgres`. Azure PostgreSQL requires SSL: use `Ssl Mode=Require` in the deployed app setting.
