# Contributing to Logic App + Data Factory Integration

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or suggest features
- Include detailed reproduction steps for bugs
- Provide Azure region, Logic App plan type, and error messages

### Submitting Changes
1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
   - Follow existing code style
   - Update documentation as needed
   - Test your changes thoroughly
4. **Commit with clear messages**
   ```bash
   git commit -m "Add: Brief description of changes"
   ```
5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
6. **Create a Pull Request**
   - Describe what changed and why
   - Reference any related issues

### Code Standards
- **Bicep**: Follow Azure Bicep best practices
- **PowerShell**: Use approved verbs, proper error handling
- **JSON**: Valid Logic App workflow definitions
- **Documentation**: Clear, concise Markdown

### Testing
- Test deployments in a non-production subscription
- Verify RBAC assignments work correctly
- Ensure no sensitive data is committed

### Documentation
- Update README.md for new features
- Add troubleshooting entries for common issues
- Include examples for new functionality

## Community Guidelines
- Be respectful and constructive
- Help others in discussions
- Share your use cases and experiences

Thank you for contributing! 🙌
