using System.Text.RegularExpressions;

namespace InvokeHub.Security
{
    public interface IPathValidator
    {
        bool IsValidPath(string path);
    }

    public class PathValidator : IPathValidator
    {
        private static readonly Regex SafePathRegex = new Regex(
            @"^[a-zA-Z0-9\-_/]+\.ps1$", 
            RegexOptions.Compiled);

        public bool IsValidPath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return false;

            // Security: Remove dangerous path elements
            path = path.Replace("..", "").Replace("\\", "/").Trim();

            // Check against safe path regex
            if (!SafePathRegex.IsMatch(path))
                return false;

            // Additional security checks
            if (path.StartsWith("/") || 
                path.StartsWith("~") || 
                path.Contains("://") ||
                path.Contains("..") ||
                path.Contains("\\"))
                return false;

            return true;
        }
    }
}