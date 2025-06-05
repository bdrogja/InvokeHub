using System;

namespace InvokeHub
{
    /// <summary>
    /// Zentrale Konfigurationsklasse
    /// </summary>
    public static class Configuration
    {
        // Storage
        public static string StorageConnectionString => 
            GetEnvironmentVariable("AzureWebJobsStorage", required: true);
        
        public static string ContainerName => 
            GetEnvironmentVariable("BlobContainerName", "powershell-scripts");

        // Authentication
        public static string ApiKey => 
            GetEnvironmentVariable("API_KEY");
        
        public static string ApiPassword => 
            GetEnvironmentVariable("API_PASSWORD");
        
        public static bool UsePassword => 
            !string.IsNullOrEmpty(ApiPassword);

        // Features
        public static bool RequireSignedScripts => 
            GetEnvironmentVariable("REQUIRE_SIGNED_SCRIPTS", "false").ToLower() == "true";
        
        public static int MaxScriptSizeKb => 
            int.Parse(GetEnvironmentVariable("MAX_SCRIPT_SIZE_KB", "1024"));
        
        public static int RateLimitSeconds => 
            int.Parse(GetEnvironmentVariable("RATE_LIMIT_SECONDS", "1"));
        
        public static int CacheControlSeconds => 
            int.Parse(GetEnvironmentVariable("CACHE_CONTROL_SECONDS", "300"));

        // Version
        public static string Version => "1.0.0";

        static Configuration()
        {
            // Validate configuration on startup
            ValidateConfiguration();
        }

        private static void ValidateConfiguration()
        {
            if (string.IsNullOrEmpty(StorageConnectionString))
            {
                throw new InvalidOperationException("AzureWebJobsStorage must be configured");
            }

            if (!UsePassword && string.IsNullOrEmpty(ApiKey))
            {
                throw new InvalidOperationException("Either API_KEY or API_PASSWORD must be configured");
            }
        }

        private static string GetEnvironmentVariable(string name, string defaultValue = null, bool required = false)
        {
            var value = Environment.GetEnvironmentVariable(name);
            
            if (string.IsNullOrEmpty(value))
            {
                if (required)
                    throw new InvalidOperationException($"Required environment variable '{name}' is not set");
                
                return defaultValue;
            }
            
            return value;
        }
    }
}