namespace OfflineSync.Api.Models;

public record ItemDto
(
    Guid Id,
    string Title,
    string Notes,
    DateTime UpdatedAt,
    bool IsDeleted
);

public record PushRequest(List<ItemDto> Changes);

public record PushResponse(List<Guid> Accepted, long ServerVersion);

public record PullResponse(List<ItemDto> Changes, long Cursor);