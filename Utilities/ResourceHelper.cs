using System.IO;
using System.Reflection;

namespace InvokeHub.Utilities
{
    /// <summary>
    /// Helper für das Laden von eingebetteten Resourcen
    /// </summary>
    public static class ResourceHelper
    {
        private static readonly Assembly Assembly = Assembly.GetExecutingAssembly();
        private static readonly string AssemblyName = Assembly.GetName().Name;

        /// <summary>
        /// Lädt eine eingebettete Resource als String
        /// </summary>
        public static string LoadEmbeddedResource(string resourceName)
        {
            var fullResourceName = $"{AssemblyName}.{resourceName}";
            
            using var stream = Assembly.GetManifestResourceStream(fullResourceName);
            if (stream == null)
            {
                throw new FileNotFoundException(
                    $"Embedded resource not found: {fullResourceName}. " +
                    $"Available resources: {string.Join(", ", Assembly.GetManifestResourceNames())}");
            }
            
            using var reader = new StreamReader(stream);
            return reader.ReadToEnd();
        }

        /// <summary>
        /// Prüft ob eine eingebettete Resource existiert
        /// </summary>
        public static bool ResourceExists(string resourceName)
        {
            var fullResourceName = $"{AssemblyName}.{resourceName}";
            using var stream = Assembly.GetManifestResourceStream(fullResourceName);
            return stream != null;
        }

        /// <summary>
        /// Lädt eine eingebettete Resource als Byte-Array
        /// </summary>
        public static byte[] LoadEmbeddedResourceBytes(string resourceName)
        {
            var fullResourceName = $"{AssemblyName}.{resourceName}";
            
            using var stream = Assembly.GetManifestResourceStream(fullResourceName);
            if (stream == null)
            {
                throw new FileNotFoundException(
                    $"Embedded resource not found: {fullResourceName}");
            }
            
            using var memoryStream = new MemoryStream();
            stream.CopyTo(memoryStream);
            return memoryStream.ToArray();
        }
    }
}