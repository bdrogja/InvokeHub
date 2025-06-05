using System;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace InvokeHub.Services
{
    public interface IAuthenticationService
    {
        Task<bool> IsAuthenticatedAsync(string authHeader);
        Task<(bool Success, object Response)> AuthenticateAsync(string authHeader);
        string GetAuthMode();
    }

    public class AuthenticationService : IAuthenticationService
    {
        private readonly ILogger<AuthenticationService> _logger;
        private readonly string _apiKey;
        private readonly string _apiPassword;
        private readonly bool _usePassword;

        public AuthenticationService(ILogger<AuthenticationService> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            
            _apiKey = Configuration.ApiKey;
            _apiPassword = Configuration.ApiPassword;
            _usePassword = Configuration.UsePassword;
        }

        public Task<bool> IsAuthenticatedAsync(string authHeader)
        {
            return Task.FromResult(IsValidAuth(authHeader));
        }

        public Task<(bool Success, object Response)> AuthenticateAsync(string authHeader)
        {
            if (IsValidAuth(authHeader))
            {
                var response = new
                {
                    authenticated = true,
                    sessionToken = GenerateSecureToken(),
                    expiresIn = 3600,
                    authMode = GetAuthMode()
                };
                
                return Task.FromResult((true, (object)response));
            }

            return Task.FromResult((false, (object)null));
        }

        public string GetAuthMode()
        {
            return _usePassword ? "password" : "apikey";
        }

        private bool IsValidAuth(string authValue)
        {
            if (string.IsNullOrEmpty(authValue))
                return false;

            var expectedValue = _usePassword ? _apiPassword : _apiKey;
            return SecureCompare(authValue, expectedValue);
        }

        private static bool SecureCompare(string a, string b)
        {
            if (a == null || b == null || a.Length != b.Length)
                return false;

            uint diff = 0;
            for (int i = 0; i < a.Length; i++)
            {
                diff |= (uint)(a[i] ^ b[i]);
            }
            return diff == 0;
        }

        private static string GenerateSecureToken()
        {
            var bytes = new byte[32];
            using var rng = RandomNumberGenerator.Create();
            rng.GetBytes(bytes);
            return Convert.ToBase64String(bytes);
        }
    }
}