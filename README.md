# SSH Tunnel Manager Documentation (English)

This directory contains the English documentation for SSH Tunnel Manager, built with MkDocs.

## Building Locally

### Prerequisites

- Python 3.8+
- pip

### Setup

1. Create a virtual environment:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Serve locally:
   ```bash
   mkdocs serve
   ```

4. Open http://127.0.0.1:8000 in your browser

### Building

To build the static site:

```bash
mkdocs build
```

The built site will be in the `site/` directory.

## Documentation Structure

```
docs/
├── index.md                  # Home page
├── getting-started.md        # Quick start guide
├── ssh-config.md             # SSH configuration guide
├── web-panel.md              # Web panel usage
├── troubleshooting.md        # Troubleshooting guide
├── api/
│   ├── index.md              # API overview
│   ├── cli-reference.md      # CLI command reference
│   ├── http-api.md           # HTTP API reference
│   └── tunnel-lifecycle.md   # Tunnel lifecycle management
└── development/
    ├── contributing.md       # Contributing guide
    └── i18n.md               # Internationalization guide
```

## ReadTheDocs

This documentation is hosted on ReadTheDocs. The configuration is in `.readthedocs.yaml`.

## Contributing

See [Contributing Guide](docs/development/contributing.md) for details on how to contribute to the documentation.

## License

MIT License