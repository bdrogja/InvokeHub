using System;
using System.Collections.Concurrent;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace InvokeHub.Security
{
    public interface IRateLimiter
    {
        Task<bool> CheckRateLimitAsync(string clientId, int? customWindowSeconds = null);
    }

    public class RateLimiter : IRateLimiter
    {
        private readonly ILogger<RateLimiter> _logger;
        private readonly ConcurrentDictionary<string, DateTime> _lastRequestTime = new();
        private const int DEFAULT_WINDOW_SECONDS = 1;
        private const int MAX_ENTRIES = 1000;

        public RateLimiter(ILogger<RateLimiter> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public Task<bool> CheckRateLimitAsync(string clientId, int? customWindowSeconds = null)
        {
            var window = TimeSpan.FromSeconds(customWindowSeconds ?? DEFAULT_WINDOW_SECONDS);
            var now = DateTime.UtcNow;
            
            if (_lastRequestTime.TryGetValue(clientId, out var lastRequest))
            {
                if (now - lastRequest < window)
                {
                    _logger.LogWarning("Rate limit exceeded for {ClientId}", clientId);
                    return Task.FromResult(false);
                }
            }
            
            _lastRequestTime[clientId] = now;
            CleanupOldEntries(now);
            
            return Task.FromResult(true);
        }

        private void CleanupOldEntries(DateTime now)
        {
            if (_lastRequestTime.Count > MAX_ENTRIES)
            {
                var cutoff = now.AddMinutes(-5);
                var toRemove = _lastRequestTime
                    .Where(kvp => kvp.Value < cutoff)
                    .Select(kvp => kvp.Key)
                    .ToList();
                    
                foreach (var key in toRemove)
                {
                    _lastRequestTime.TryRemove(key, out _);
                }
            }
        }
    }
}