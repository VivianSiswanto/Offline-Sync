using OfflineSync.Api.Models;

namespace OfflineSync.Api.Data;

public interface IItemRepository
{
    Task<Item?> GetAsync(Guid id);
    Task<List<Item>> GetChangedSinceAsync(long version, int limit);
    Task<long> GetCurrentVersionAsync();
    Task<T> InTransactionAsync<T>(Func<ITransactionScope, T> work);     // runs a whole push batch 
}

public interface ITransactionScope
{
    Item? Find(Guid id);    // Find a record 
    long NextVersion();     // Get the next version number
    void Upsert(Item item); // Save record 
}