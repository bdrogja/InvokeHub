using System;
using System.Security.Cryptography;
using System.Text;

namespace InvokeHub.Utilities
{
    /// <summary>
    /// Utility-Klasse für Hash-Berechnungen
    /// </summary>
    public static class HashingUtilities
    {
        /// <summary>
        /// Berechnet einen SHA256 Hash für den gegebenen Inhalt
        /// </summary>
        public static string ComputeHash(string content)
        {
            if (string.IsNullOrEmpty(content))
                return string.Empty;

            using var sha256 = SHA256.Create();
            var bytes = Encoding.UTF8.GetBytes(content);
            var hash = sha256.ComputeHash(bytes);
            return Convert.ToBase64String(hash);
        }

        /// <summary>
        /// Berechnet einen SHA256 Hash für Bytes
        /// </summary>
        public static string ComputeHash(byte[] bytes)
        {
            if (bytes == null || bytes.Length == 0)
                return string.Empty;

            using var sha256 = SHA256.Create();
            var hash = sha256.ComputeHash(bytes);
            return Convert.ToBase64String(hash);
        }

        /// <summary>
        /// Verifiziert einen Hash
        /// </summary>
        public static bool VerifyHash(string content, string expectedHash)
        {
            var actualHash = ComputeHash(content);
            return string.Equals(actualHash, expectedHash, StringComparison.Ordinal);
        }
    }
}