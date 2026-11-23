using OfflineSync.Api.Models;
using OfflineSync.Api.Services;

namespace OfflineSync.Api.Endpoints;

public static class SyncEndpoints
{
    public static void MapSyncEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api");

        // checks whether the server is up 
        group.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

        // .NET turns the JSON body into a PushRequest automatically
        // Invalid = 400 
        // Valid = 200 with PushResponse
        group.MapPost("/sync/push", async (PushRequest? request, SyncService sync) =>
        {
            var errors = SyncService.Validate(request);
            if (errors.Count > 0) return Results.BadRequest(new { errors });
            return Results.Ok(await sync.PushAsync(request!));
        });

        // .NET reads since from the URL
        group.MapGet("/sync/pull", async (long? since, SyncService sync) =>
        {
            return Results.Ok(await sync.PullAsync(since ?? 0));
        });
    }
}