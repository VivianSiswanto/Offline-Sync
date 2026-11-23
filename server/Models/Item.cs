namespace OfflineSync.Api.Models;

public class Item
{
    public Guid Id { get; set; }
    public string Title { get; set; } = "";
    public string Notes { get; set; } = "";
    public DateTime UpdatedAt { get; set; }

    // Soft Delete
    public bool IsDeleted { get; set; }

    // Number increases after every changes, used as a counter
    public long ServerVersion { get; set; }
}