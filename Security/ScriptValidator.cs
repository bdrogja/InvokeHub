using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace InvokeHub.Security
{
    public interface IScriptValidator
    {
        bool IsValidScript(string content);
    }

    public class ScriptValidator : IScriptValidator
    {
        private readonly ILogger<ScriptValidator> _logger;
        
        private static readonly string[] DangerousPatterns = new[]
        {
            @"rm\s+-rf\s+/",
            @"format\s+c:",
            @"del\s+/s\s+/q\s+c:\\",
            @"invoke-expression.*downloadstring",
            @"remove-item.*-recurse.*-force",
            @"cmd.*\/c.*rd.*\/s.*\/q",
            @"\$env:windir.*delete",
            @"stop-computer.*-force",
            @"restart-computer.*-force"
        };

        public ScriptValidator(ILogger<ScriptValidator> logger)
        {
            _logger = logger ?? throw new System.ArgumentNullException(nameof(logger));
        }

        public bool IsValidScript(string content)
        {
            if (string.IsNullOrWhiteSpace(content))
            {
                _logger.LogWarning("Script validation failed: Empty content");
                return false;
            }

            // Check for dangerous commands
            foreach (var pattern in DangerousPatterns)
            {
                if (Regex.IsMatch(content, pattern, RegexOptions.IgnoreCase))
                {
                    _logger.LogWarning("Script validation failed: Dangerous pattern detected: {Pattern}", pattern);
                    return false;
                }
            }

            // Check for maximum script size (1MB)
            if (content.Length > 1024 * 1024)
            {
                _logger.LogWarning("Script validation failed: Script too large ({Size} bytes)", content.Length);
                return false;
            }

            return true;
        }
    }
}