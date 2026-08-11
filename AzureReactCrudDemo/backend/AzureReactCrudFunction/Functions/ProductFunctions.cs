using System.Net;
using System.Text.Json;
using AzureReactCrudFunction.Data;
using AzureReactCrudFunction.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace AzureReactCrudFunction.Functions;

public sealed class ProductFunctions(ProductRepository repository, ILogger<ProductFunctions> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Function("GetProducts")]
    public async Task<HttpResponseData> GetProducts([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "products")] HttpRequestData request, CancellationToken ct)
    {
        try { return await JsonAsync(request, HttpStatusCode.OK, await repository.GetAllAsync(ct)); }
        catch (Exception ex) { logger.LogError(ex, "Unable to list products."); return await ErrorAsync(request, HttpStatusCode.InternalServerError, "Unable to retrieve products."); }
    }

    [Function("GetProduct")]
    public async Task<HttpResponseData> GetProduct([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "products/{id:int}")] HttpRequestData request, int id, CancellationToken ct)
    {
        try { var product = await repository.GetByIdAsync(id, ct); return product is null ? await ErrorAsync(request, HttpStatusCode.NotFound, "Product not found.") : await JsonAsync(request, HttpStatusCode.OK, product); }
        catch (Exception ex) { logger.LogError(ex, "Unable to retrieve product {ProductId}.", id); return await ErrorAsync(request, HttpStatusCode.InternalServerError, "Unable to retrieve product."); }
    }

    [Function("CreateProduct")]
    public async Task<HttpResponseData> CreateProduct([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "products")] HttpRequestData request, CancellationToken ct)
    {
        var input = await ReadInputAsync(request); var validation = Validate(input); if (validation is not null) return await ErrorAsync(request, HttpStatusCode.BadRequest, validation);
        try { var product = await repository.CreateAsync(input!, ct); logger.LogInformation("Created product {ProductId}.", product!.Id); return await JsonAsync(request, HttpStatusCode.Created, product); }
        catch (Exception ex) { logger.LogError(ex, "Unable to create product."); return await ErrorAsync(request, HttpStatusCode.InternalServerError, "Unable to create product."); }
    }

    [Function("UpdateProduct")]
    public async Task<HttpResponseData> UpdateProduct([HttpTrigger(AuthorizationLevel.Anonymous, "put", Route = "products/{id:int}")] HttpRequestData request, int id, CancellationToken ct)
    {
        var input = await ReadInputAsync(request); var validation = Validate(input); if (validation is not null) return await ErrorAsync(request, HttpStatusCode.BadRequest, validation);
        try { var product = await repository.UpdateAsync(id, input!, ct); if (product is null) return await ErrorAsync(request, HttpStatusCode.NotFound, "Product not found."); logger.LogInformation("Updated product {ProductId}.", id); return await JsonAsync(request, HttpStatusCode.OK, product); }
        catch (Exception ex) { logger.LogError(ex, "Unable to update product {ProductId}.", id); return await ErrorAsync(request, HttpStatusCode.InternalServerError, "Unable to update product."); }
    }

    [Function("DeleteProduct")]
    public async Task<HttpResponseData> DeleteProduct([HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "products/{id:int}")] HttpRequestData request, int id, CancellationToken ct)
    {
        try { if (!await repository.DeleteAsync(id, ct)) return await ErrorAsync(request, HttpStatusCode.NotFound, "Product not found."); logger.LogInformation("Deleted product {ProductId}.", id); return request.CreateResponse(HttpStatusCode.NoContent); }
        catch (Exception ex) { logger.LogError(ex, "Unable to delete product {ProductId}.", id); return await ErrorAsync(request, HttpStatusCode.InternalServerError, "Unable to delete product."); }
    }

    private static async Task<ProductInput?> ReadInputAsync(HttpRequestData request) { try { return await JsonSerializer.DeserializeAsync<ProductInput>(request.Body, JsonOptions); } catch (JsonException) { return null; } }
    private static string? Validate(ProductInput? input) => input is null ? "Request body must be valid JSON." : string.IsNullOrWhiteSpace(input.Name) ? "Name is required." : input.Name.Trim().Length > 100 ? "Name must be 100 characters or fewer." : input.Description?.Length > 500 ? "Description must be 500 characters or fewer." : input.Price < 0 ? "Price must be non-negative." : null;
    private static async Task<HttpResponseData> JsonAsync(HttpRequestData request, HttpStatusCode status, object body) { var response = request.CreateResponse(status); await response.WriteAsJsonAsync(body, JsonOptions); return response; }
    private static Task<HttpResponseData> ErrorAsync(HttpRequestData request, HttpStatusCode status, string message) => JsonAsync(request, status, new { message });
}
