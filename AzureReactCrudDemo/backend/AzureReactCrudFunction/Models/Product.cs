namespace AzureReactCrudFunction.Models;

public sealed record Product(int Id, string Name, string? Description, decimal Price, DateTime CreatedAt, DateTime UpdatedAt);
public sealed record ProductInput(string? Name, string? Description, decimal Price);
