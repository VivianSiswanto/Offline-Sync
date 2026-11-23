using OfflineSync.Api.Data;
using OfflineSync.Api.Endpoints;
using OfflineSync.Api.Services;

var builder = WebApplication.CreateBuilder(args);

var dataFile = builder.Configuration["DataFile"] ?? Path.Combine(AppContext.BaseDirectory, "items.json");
builder.Services.AddSingleton<IItemRepository>(_ => new JsonFileItemRepository(dataFile));
builder.Services.AddScoped<SyncService>();

var app = builder.Build();

app.MapSyncEndpoints();

app.Run();
