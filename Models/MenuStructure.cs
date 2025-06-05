using System;
using System.Collections.Generic;

namespace InvokeHub.Models
{
    /// <summary>
    /// Repräsentiert die Menüstruktur für PowerShell Scripts
    /// </summary>
    public class MenuStructure
    {
        public string Name { get; set; } = string.Empty;
        
        public string Type { get; set; } = string.Empty;
        
        public string Path { get; set; } = string.Empty;
        
        public List<MenuStructure> Children { get; set; } = new List<MenuStructure>();
        
        public long Size { get; set; }
        
        public DateTime? LastModified { get; set; }
        
        public IDictionary<string, string> Metadata { get; set; } = new Dictionary<string, string>();
    }
}