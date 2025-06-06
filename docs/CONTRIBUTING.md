# Contributing to InvokeHub

Thank you for your interest in contributing to InvokeHub! We welcome contributions from the community.

## 📋 Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit bug fixes
- ✨ Add new features
- 🧪 Write tests

## 🚀 Getting Started

### 1. Fork the Repository

Click the "Fork" button on GitHub to create your own copy.

### 2. Clone Your Fork

```bash
git clone https://github.com/yourusername/invokehub.git
cd invokehub
```

### 3. Setup Development Environment

```powershell
./scripts/setup-dev.ps1
```

### 4. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

## 💻 Development Guidelines

### Code Style

- Follow C# coding conventions
- Use meaningful variable and method names
- Keep methods focused and small

### PowerShell Scripts

- Use approved verbs (Get-, Set-, New-, etc.)
- Include comment-based help
- Handle errors gracefully
- Test on both Windows PowerShell and PowerShell Core

### Commit Messages

Use clear, descriptive commit messages:

```
Add script validation for dangerous commands

- Added new validation rules to ScriptValidator
- Blocks Format-Volume and similar commands
- Includes unit tests
```

### Testing

- Write unit tests for new features
- Ensure all tests pass before submitting
- Test manually on local environment

```bash
# Run tests
dotnet test

# Test deployment
./scripts/test-deployment.ps1 -ApiUrl http://localhost:7071/api -ApiKey test
```

## 📝 Pull Request Process

### 1. Update Documentation

- Update README.md if needed
- Add/update docs in the docs/ folder
- Update inline code documentation

### 2. Test Your Changes

- [ ] All unit tests pass
- [ ] Manual testing completed
- [ ] No breaking changes (or documented if necessary)

### 3. Submit Pull Request

- Clear title and description
- Reference any related issues
- Include screenshots for UI changes
- List testing performed

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Unit tests pass
- [ ] Manual testing completed
- [ ] Tested on PowerShell 5.1
- [ ] Tested on PowerShell Core

## Related Issues
Fixes #123
```

## 🐛 Reporting Issues

### Before Submitting

1. Search existing issues
2. Check the [FAQ](docs/faq.md)
3. Try the [Troubleshooting Guide](docs/troubleshooting.md)

### Issue Template

```markdown
## Description
Clear description of the issue

## Steps to Reproduce
1. Step one
2. Step two
3. ...

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- InvokeHub version:
- PowerShell version:
- OS:
- Azure region:

## Additional Context
Any other relevant information
```

## 🏗️ Project Structure

```
InvokeHub/
├── Api/              # HTTP endpoints
├── Services/         # Business logic
├── Security/         # Security components
├── Models/           # Data models
├── Utilities/        # Helper classes
├── PowerShell/       # Embedded PS scripts
├── tests/            # Unit tests
├── docs/             # Documentation
└── scripts/          # Deployment scripts
```

## 🔧 Areas Needing Help

### High Priority

- 🧪 More unit tests
- 📱 PowerShell Core testing on macOS/Linux
- 🌍 Internationalization support
- 📊 Performance optimizations

### Features We'd Love

- 📝 Script metadata editor
- 🔍 Advanced search capabilities
- 📊 Usage analytics dashboard
- 🔐 Azure AD integration

## 📜 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Public or private harassment
- Publishing private information

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be recognized in:
- GitHub contributors page
- Release notes
- Special thanks in README

## 💬 Questions?

- 💬 [GitHub Discussions](https://github.com/bdrogja/InvokeHub/discussions)

Thank you for helping make InvokeHub better! 🚀