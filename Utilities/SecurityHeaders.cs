using System.Linq;
using Microsoft.AspNetCore.Http;

namespace InvokeHub.Utilities
{
    /// <summary>
    /// Utility-Klasse für Security Headers
    /// </summary>
    public static class SecurityHeaders
    {
        public static void AddSecurityHeaders(HttpRequest req)
        {
            var headers = req.HttpContext.Response.Headers;
            headers["X-Content-Type-Options"] = "nosniff";
            headers["X-Frame-Options"] = "DENY";
            headers["X-XSS-Protection"] = "1; mode=block";
            headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
            headers["Content-Security-Policy"] = "default-src 'self'";
            headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()";
        }

        public static void AddCacheHeaders(HttpRequest req, int seconds)
        {
            req.HttpContext.Response.Headers.Add("Cache-Control", $"private, max-age={seconds}");
        }

        public static string GetClientIp(HttpRequest req)
        {
            // Check for forwarded IP (Azure Functions behind proxy)
            var forwardedFor = req.Headers["X-Forwarded-For"].FirstOrDefault();
            if (!string.IsNullOrEmpty(forwardedFor))
            {
                // Take the first IP if multiple are present
                return forwardedFor.Split(',').FirstOrDefault()?.Trim() ?? "unknown";
            }

            // Fallback to direct connection IP
            return req.HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        }
    }
}