using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection;
using InvokeHub.Services;
using InvokeHub.Security;

[assembly: FunctionsStartup(typeof(InvokeHub.Startup))]

namespace InvokeHub
{
    /// <summary>
    /// Startup-Klasse für Dependency Injection Configuration
    /// </summary>
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
            // Services
            builder.Services.AddSingleton<IAuthenticationService, AuthenticationService>();
            builder.Services.AddSingleton<IScriptService, ScriptService>();
            builder.Services.AddSingleton<IMenuService, MenuService>();
            
            // Security
            builder.Services.AddSingleton<IRateLimiter, RateLimiter>();
            builder.Services.AddSingleton<IPathValidator, PathValidator>();
            builder.Services.AddSingleton<IScriptValidator, ScriptValidator>();
            
            // Logging ist bereits von Azure Functions bereitgestellt
        }
    }
}