using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Logging;
using InvokeHub.Models;
using InvokeHub.Security;

namespace InvokeHub.Services
{
    public interface IMenuService
    {
        Task<MenuStructure> GetMenuStructureAsync();
    }

    public class MenuService : IMenuService
    {
        private readonly ILogger<MenuService> _logger;
        private readonly IPathValidator _pathValidator;
        private readonly BlobServiceClient _blobServiceClient;
        private readonly string _containerName;

        private const string POWERSHELL_EXTENSION = ".ps1";
        private const string SYSTEM_FILE_PREFIX = "_";
        private const string HIDDEN_FILE_PREFIX = ".";

        public MenuService(ILogger<MenuService> logger, IPathValidator pathValidator)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _pathValidator = pathValidator ?? throw new ArgumentNullException(nameof(pathValidator));
            
            _blobServiceClient = new BlobServiceClient(Configuration.StorageConnectionString);
            _containerName = Configuration.ContainerName;
        }

        public async Task<MenuStructure> GetMenuStructureAsync()
        {
            var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
            
            if (!await containerClient.ExistsAsync())
            {
                _logger.LogError("Container '{ContainerName}' does not exist", _containerName);
                throw new InvalidOperationException("Storage container not found");
            }

            return await BuildMenuStructureAsync(containerClient);
        }

        private async Task<MenuStructure> BuildMenuStructureAsync(BlobContainerClient containerClient)
        {
            var root = new MenuStructure 
            { 
                Name = "Root", 
                Type = "folder", 
                Path = "",
                Children = new List<MenuStructure>() 
            };
            
            var folders = new Dictionary<string, MenuStructure>();
            var scriptCount = 0;

            try
            {
                await foreach (var blobItem in containerClient.GetBlobsAsync())
                {
                    if (ShouldSkipBlob(blobItem.Name))
                        continue;
                    
                    if (!_pathValidator.IsValidPath(blobItem.Name))
                    {
                        _logger.LogWarning("Skipping invalid blob path: {Path}", blobItem.Name);
                        continue;
                    }
                    
                    BuildHierarchy(blobItem, root, folders, ref scriptCount);
                }
                
                _logger.LogInformation("Menu built with {ScriptCount} scripts", scriptCount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error building menu structure");
                throw;
            }

            SortMenuStructure(root);
            return root;
        }

        private static bool ShouldSkipBlob(string name)
        {
            return name.StartsWith(SYSTEM_FILE_PREFIX) || name.StartsWith(HIDDEN_FILE_PREFIX);
        }

        private static void BuildHierarchy(
            Azure.Storage.Blobs.Models.BlobItem blobItem,
            MenuStructure root,
            Dictionary<string, MenuStructure> folders,
            ref int scriptCount)
        {
            var parts = blobItem.Name.Split('/');
            var currentLevel = root;

            // Build folder hierarchy
            for (int i = 0; i < parts.Length - 1; i++)
            {
                var folderPath = string.Join("/", parts.Take(i + 1));
                
                if (!folders.ContainsKey(folderPath))
                {
                    var newFolder = new MenuStructure
                    {
                        Name = parts[i],
                        Type = "folder",
                        Path = folderPath,
                        Children = new List<MenuStructure>()
                    };
                    
                    currentLevel.Children.Add(newFolder);
                    folders[folderPath] = newFolder;
                    currentLevel = newFolder;
                }
                else
                {
                    currentLevel = folders[folderPath];
                }
            }

            // Add PowerShell scripts only
            if (blobItem.Name.EndsWith(POWERSHELL_EXTENSION, StringComparison.OrdinalIgnoreCase))
            {
                currentLevel.Children.Add(new MenuStructure
                {
                    Name = parts.Last(),
                    Type = "script",
                    Path = blobItem.Name,
                    Size = blobItem.Properties.ContentLength ?? 0,
                    LastModified = blobItem.Properties.LastModified?.DateTime,
                    Metadata = blobItem.Metadata ?? new Dictionary<string, string>()
                });
                scriptCount++;
            }
        }

        private static void SortMenuStructure(MenuStructure node)
        {
            if (node.Children?.Any() == true)
            {
                node.Children = node.Children
                    .OrderBy(c => c.Type == "folder" ? 0 : 1)
                    .ThenBy(c => c.Name, StringComparer.OrdinalIgnoreCase)
                    .ToList();
                    
                foreach (var folder in node.Children.Where(c => c.Type == "folder"))
                {
                    SortMenuStructure(folder);
                }
            }
        }
    }
}