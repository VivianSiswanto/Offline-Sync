using System.Text.Json;
using OfflineSync.Api.Models;

namespace OfflineSync.Api.Data;

public class JsonFileItemRepository : IItemRepository
{
    private readonly string _path;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly Dictionary<Guid, Item> _rows;
    private long _version;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    // Constructor 
    public JsonFileItemRepository(string path)
    {
        _path = path;
        _rows = File.Exists(path)
            ? (JsonSerializer.Deserialize<List<Item>>(File.ReadAllText(path)) ?? new()).ToDictionary(i => i.Id)
            : new();
        _version = _rows.Count == 0 ? 0 : _rows.Values.Max(i => i.ServerVersion);

    }

    public async Task<Item?> GetAsync(Guid id)
    {
        await _lock.WaitAsync();
        try
        {
            return _rows.TryGetValue(id, out var i) ? i : null;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<List<Item>> GetChangedSinceAsync(long version, int limit)
    {
        await _lock.WaitAsync();
        try
        {
            return _rows.Values
                .Where(i => i.ServerVersion > version)
                .OrderBy(i => i.ServerVersion)
                .Take(limit)
                .ToList();
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<long> GetCurrentVersionAsync()
    {
        await _lock.WaitAsync();
        try
        {
            return _version;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<T> InTransactionAsync<T>(Func<ITransactionScope, T> work)
    {
        await _lock.WaitAsync();
        try
        {
            var scope = new Scope(this);
            var result = work(scope);
            scope.Commit();
            return result;
        }
        finally
        {
            _lock.Release();
        }
    }

    private sealed class Scope : ITransactionScope
    {
        private readonly JsonFileItemRepository _repo;
        private readonly Dictionary<Guid, Item> _pending = new();
        private long _version;

        public Scope(JsonFileItemRepository repo)
        {
            _repo = repo;
            _version = repo._version;
        }

        public Item? Find(Guid id) =>
            _pending.TryGetValue(id, out var p) ? p : _repo._rows.TryGetValue(id, out var i) ? i : null;

        public long NextVersion() => ++_version;

        public void Upsert(Item item)
        {
            _pending[item.Id] = item;
        }

        public void Commit()
        {
            if (_pending.Count == 0) return;
            foreach (var i in _pending.Values)
            {
                _repo._rows[i.Id] = i;
            }
            _repo._version = _version;

            var tmp = _repo._path + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(_repo._rows.Values.ToList(), JsonOptions));
            File.Move(tmp, _repo._path, overwrite: true);
        }
    }
}