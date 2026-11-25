using OfflineSync.Api.Data;
using OfflineSync.Api.Models;

namespace OfflineSync.Api.Services;

public class SyncService
{
    public const int MaxBatchSize = 100;
    public const int PullPageSize = 200;

    private readonly IItemRepository _repo;
    public SyncService(IItemRepository repo) => _repo = repo;
    public async Task<PushResponse> PushAsync(PushRequest request)
    {
        var accepted = new List<Guid>();
        await _repo.InTransactionAsync(tx =>
        {
            foreach (var dto in request.Changes)
            {
                var existing = tx.Find(dto.Id);
                var incomingIsNewer = existing is null || dto.UpdatedAt > existing.UpdatedAt;

                if (incomingIsNewer)
                {
                    tx.Upsert(new Item
                    {
                        Id = dto.Id,
                        Title = dto.Title.Trim(),
                        Notes = dto.Notes.Trim(),
                        UpdatedAt = dto.UpdatedAt.ToUniversalTime(),
                        IsDeleted = dto.IsDeleted,
                        ServerVersion = tx.NextVersion(),
                    });
                }
                else if (dto.UpdatedAt < existing!.UpdatedAt)
                {
                    tx.Upsert(new Item
                    {
                        Id = existing.Id,
                        Title = existing.Title,
                        Notes = existing.Notes,
                        UpdatedAt = existing.UpdatedAt,
                        IsDeleted = existing.IsDeleted,
                        ServerVersion = tx.NextVersion(),
                    });
                }
                accepted.Add(dto.Id);
            }
            return 0;
        });
        return new PushResponse(accepted, await _repo.GetCurrentVersionAsync());
    }

    public async Task<PullResponse> PullAsync(long since)
    {
        var changes = await _repo.GetChangedSinceAsync(since, PullPageSize);
        var cursor = changes.Count == 0 ? since : changes[^1].ServerVersion;
        return new PullResponse(changes.Select(ToDto).ToList(), cursor);
    }

    public static List<string> Validate(PushRequest? request)
    {
        var errors = new List<string>();
        if (request?.Changes is null)
        {
            errors.Add("Missing changes");
            return errors;
        }
        if (request.Changes.Count > MaxBatchSize)
        {
            errors.Add($"Too many changes, max batch size is {MaxBatchSize}");
        }

        foreach (var c in request.Changes)
        {
            if (c.Id == Guid.Empty)
            {
                errors.Add("Missing Id");
            }

            if (!c.IsDeleted && string.IsNullOrWhiteSpace(c.Title))
            {
                errors.Add($"Missing title for item {c.Id}");
            }
        }
        return errors;
    }

    private static ItemDto ToDto(Item i) => new(i.Id, i.Title, i.Notes, i.UpdatedAt, i.IsDeleted);
}