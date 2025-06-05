using System;
using System.IO;
using System.Threading.Tasks;
using System.Linq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using InvokeHub.Services;
using InvokeHub.Security;
using InvokeHub.Utilities;

namespace InvokeHub.Api
{
    /// <summary>
    /// Azure Functions HTTP Endpoints für InvokeHub
    /// </summary>
    public class InvokeHubApi
    {
        private readonly IAuthenticationService _authService;
        private readonly IScriptService _scriptService;
        private readonly IMenuService _menuService;
        private readonly IRateLimiter _rateLimiter;
        private readonly ILogger<InvokeHubApi> _logger;

        public InvokeHubApi(
            IAuthenticationService authService,
            IScriptService scriptService,
            IMenuService menuService,
            IRateLimiter rateLimiter,
            ILogger<InvokeHubApi> logger)
        {
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _scriptService = scriptService ?? throw new ArgumentNullException(nameof(scriptService));
            _menuService = menuService ?? throw new ArgumentNullException(nameof(menuService));
            _rateLimiter = rateLimiter ?? throw new ArgumentNullException(nameof(rateLimiter));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        [FunctionName("GetMenu")]
        public async Task<IActionResult> GetMenu(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "menu")] HttpRequest req)
        {
            return await ExecuteAuthenticatedRequest(req, async () =>
            {
                var menu = await _menuService.GetMenuStructureAsync();
                SecurityHeaders.AddCacheHeaders(req, 300);
                return new OkObjectResult(menu);
            });
        }

        [FunctionName("GetScript")]
        public async Task<IActionResult> GetScript(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "script")] HttpRequest req)
        {
            return await ExecuteAuthenticatedRequest(req, async () =>
            {
                var scriptPath = req.Query["path"];
                if (string.IsNullOrWhiteSpace(scriptPath))
                {
                    return new BadRequestObjectResult(new { error = "Script path is required" });
                }

                try
                {
                    var script = await _scriptService.GetScriptAsync(scriptPath);
                    _logger.LogInformation("Script accessed: {Path} by {IP}", 
                        scriptPath, SecurityHeaders.GetClientIp(req));
                    return new OkObjectResult(script);
                }
                catch (ArgumentException ex)
                {
                    _logger.LogWarning(ex, "Invalid script path: {Path}", scriptPath);
                    return new BadRequestObjectResult(new { error = ex.Message });
                }
                catch (FileNotFoundException)
                {
                    return new NotFoundObjectResult(new { error = "Script not found" });
                }
            });
        }

        [FunctionName("Authenticate")]
        public async Task<IActionResult> Authenticate(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "auth")] HttpRequest req)
        {
            if (!await _rateLimiter.CheckRateLimitAsync(SecurityHeaders.GetClientIp(req), 5))
            {
                return new StatusCodeResult(StatusCodes.Status429TooManyRequests);
            }

            SecurityHeaders.AddSecurityHeaders(req);

            var authHeader = req.Headers["X-API-Key"].FirstOrDefault();
            var result = await _authService.AuthenticateAsync(authHeader);
            
            if (result.Success)
            {
                _logger.LogInformation("Successful authentication from {IP}", 
                    SecurityHeaders.GetClientIp(req));
                return new OkObjectResult(result.Response);
            }
            
            _logger.LogWarning("Failed authentication attempt from {IP}", 
                SecurityHeaders.GetClientIp(req));
            return new UnauthorizedObjectResult(new { error = "Invalid credentials" });
        }

        [FunctionName("GetLoader")]
        public IActionResult GetLoader(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "loader")] HttpRequest req)
        {
            try
            {
                SecurityHeaders.AddSecurityHeaders(req);
                
                var functionUrl = $"https://{req.Host.Value}";
                var providedKey = req.Query["key"].FirstOrDefault() ?? "";
                
                var loaderScript = _scriptService.GetLoaderScript(functionUrl, providedKey);
                
                return new ContentResult
                {
                    Content = loaderScript,
                    ContentType = "text/plain; charset=utf-8"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in GetLoader");
                return new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }
        }

        [FunctionName("GetClient")]
        public IActionResult GetClient(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "client")] HttpRequest req)
        {
            try
            {
                SecurityHeaders.AddSecurityHeaders(req);
                SecurityHeaders.AddCacheHeaders(req, 3600);
                
                var clientScript = _scriptService.GetClientScript();
                
                return new ContentResult
                {
                    Content = clientScript,
                    ContentType = "text/plain; charset=utf-8"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in GetClient");
                return new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }
        }

        [FunctionName("HealthCheck")]
        public IActionResult HealthCheck(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req)
        {
            try
            {
                SecurityHeaders.AddSecurityHeaders(req);
                
                var health = new
                {
                    status = "healthy",
                    timestamp = DateTime.UtcNow,
                    version = Configuration.Version,
                    platform = "InvokeHub",
                    authMode = _authService.GetAuthMode(),
                    containerName = Configuration.ContainerName,
                    environment = Environment.GetEnvironmentVariable("AZURE_FUNCTIONS_ENVIRONMENT") ?? "Development"
                };
                
                return new OkObjectResult(health);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in HealthCheck");
                return new ObjectResult(new { status = "unhealthy", error = ex.Message }) 
                { 
                    StatusCode = StatusCodes.Status503ServiceUnavailable 
                };
            }
        }

        private async Task<IActionResult> ExecuteAuthenticatedRequest(
            HttpRequest req, 
            Func<Task<IActionResult>> action)
        {
            try
            {
                if (!await _rateLimiter.CheckRateLimitAsync(SecurityHeaders.GetClientIp(req)))
                {
                    return new StatusCodeResult(StatusCodes.Status429TooManyRequests);
                }
                
                var authHeader = req.Headers["X-API-Key"].FirstOrDefault();
                if (!await _authService.IsAuthenticatedAsync(authHeader))
                {
                    _logger.LogWarning("Unauthorized access attempt from {IP}", 
                        SecurityHeaders.GetClientIp(req));
                    return new UnauthorizedResult();
                }

                SecurityHeaders.AddSecurityHeaders(req);
                return await action();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing request");
                return new ObjectResult(new { error = "Internal server error" }) 
                { 
                    StatusCode = StatusCodes.Status500InternalServerError 
                };
            }
        }
    }
}