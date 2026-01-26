# Contributing Guide

Thank you for your interest in contributing to SSH Tunnel Manager! This guide will help you get started.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Basic knowledge of SSH and shell scripting
- Go (for web panel development)

### Setting Up Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
   cd autossh-tunnel-dockerized
   ```

2. Build the development containers:
   ```bash
   docker compose -f compose.dev.yaml build
   ```

3. Run the development environment:
   ```bash
   docker compose -f compose.dev.yaml up -d
   ```

## Project Structure

```
autossh-tunnel-dockerized/
├── compose.yaml          # Production Docker Compose
├── compose.dev.yaml      # Development Docker Compose
├── Dockerfile            # Autossh container
├── Dockerfile.web        # Web panel container
├── entrypoint.sh         # Main entrypoint script
├── autossh-cli           # CLI tool
├── scripts/
│   ├── api_server.sh     # HTTP API server
│   ├── config_parser.sh  # Configuration parser
│   ├── logger.sh         # Logging utilities
│   ├── start_autossh.sh  # Tunnel starter
│   └── state_manager.sh  # State management
├── web/
│   ├── main.go           # Web server
│   ├── templates/        # HTML templates
│   └── static/           # CSS, JS, locales
└── config/
    └── config.yaml.sample
```

## Development Workflow

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes

3. Test your changes:
   ```bash
   docker compose -f compose.dev.yaml up --build
   ```

4. Commit your changes:
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

5. Push and create a pull request

### Code Style

#### Shell Scripts

- Use `shfmt` for formatting:
  ```bash
  shfmt -w scripts/*.sh
  ```

- Follow POSIX shell conventions where possible

- Use meaningful variable names

- Add comments for complex logic

#### Go Code

- Use `gofmt` for formatting:
  ```bash
  gofmt -w web/*.go
  ```

- Follow Go best practices

- Add documentation comments for exported functions

#### Documentation

- Use clear, concise language

- Include code examples where helpful

- Keep documentation up to date with code changes

## Testing

### Manual Testing

1. Start the development environment:
   ```bash
   docker compose -f compose.dev.yaml up -d
   ```

2. Test CLI commands:
   ```bash
   docker exec -it <container> autossh-cli list
   docker exec -it <container> autossh-cli status
   ```

3. Test web panel at http://localhost:5000

4. Test API endpoints:
   ```bash
   curl http://localhost:8080/list
   curl http://localhost:8080/status
   ```

### Testing Checklist

- [ ] Tunnel creation works
- [ ] Tunnel deletion works
- [ ] Start/stop individual tunnels
- [ ] Start/stop all tunnels
- [ ] Configuration changes apply correctly
- [ ] Web panel displays correctly
- [ ] Language switching works
- [ ] API endpoints respond correctly

## Submitting Changes

### Pull Request Guidelines

1. **Title**: Use a clear, descriptive title

2. **Description**: Include:
   - What changes were made
   - Why the changes were made
   - How to test the changes

3. **Size**: Keep PRs focused and reasonably sized

4. **Tests**: Ensure all functionality works

### Commit Messages

Use clear, descriptive commit messages:

```
Add individual tunnel control API

- Add start-tunnel and stop-tunnel CLI commands
- Implement HTTP API endpoints /start/<hash> and /stop/<hash>
- Update state management for individual tunnel control
```

## Reporting Issues

When reporting issues, please include:

1. **Description**: Clear description of the problem

2. **Steps to Reproduce**: How to reproduce the issue

3. **Expected Behavior**: What should happen

4. **Actual Behavior**: What actually happens

5. **Environment**:
   - OS and version
   - Docker version
   - Browser (for web panel issues)

6. **Logs**: Relevant log output (with sensitive data removed)

## Feature Requests

For feature requests:

1. Check existing issues first

2. Describe the feature clearly

3. Explain the use case

4. Consider implementation complexity

## Questions

If you have questions:

1. Check the documentation first

2. Search existing issues

3. Open a new issue with the "question" label

## License

By contributing, you agree that your contributions will be licensed under the MIT License.