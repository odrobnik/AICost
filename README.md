# OpenAI Cost CLI

A Swift command-line tool for querying OpenAI usage costs using the [OpenAI Costs API](https://platform.openai.com/docs/api-reference/usage/costs).

## Features

- ✅ Query OpenAI organization costs
- ✅ Automatic pagination support
- ✅ Flexible date input (Unix timestamps or days ago)
- ✅ JSON and formatted output
- ✅ Filter by project IDs and line items
- ✅ Async/await throughout
- ✅ Proper Unix timestamp to Date conversion
- ✅ Snake_case to camelCase automatic conversion

## Installation

### Prerequisites

- Swift 5.9 or later
- macOS 13.0 or later
- OpenAI Admin API key

### Build from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd OpenAICost
   ```

2. Build the project:
   ```bash
   swift build -c release
   ```

3. Copy the executable to your PATH:
   ```bash
   cp .build/release/openai-cost /usr/local/bin/
   ```

## Configuration

Set your OpenAI Admin API key as an environment variable:

```bash
export OPENAI_ADMIN_KEY="your-admin-api-key-here"
```

You can add this to your shell profile (`.bashrc`, `.zshrc`, etc.) to make it persistent.

## Usage

### Basic Usage

Get costs for the last 7 days:
```bash
openai-cost --start-time 7
```

Get costs for a specific Unix timestamp:
```bash
openai-cost --start-time 1730419200
```

### Advanced Options

Get costs with specific parameters:
```bash
openai-cost \
  --start-time 7 \
  --end-time 1730505600 \
  --limit 10 \
  --bucket-width 1d \
  --verbose
```

Filter by project IDs:
```bash
openai-cost --start-time 7 --project-ids "proj_123,proj_456"
```

Group by fields:
```bash
openai-cost --start-time 7 --group-by "project_id,line_item"
```

Fetch all pages automatically:
```bash
openai-cost --start-time 30 --fetch-all
```

Output as JSON:
```bash
openai-cost --start-time 7 --json
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--start-time` | `-s` | Start time as Unix timestamp or days ago (required) |
| `--end-time` | `-e` | End time as Unix timestamp (optional) |
| `--bucket-width` | `-b` | Bucket width (default: 1d) |
| `--limit` | `-l` | Maximum buckets per page (1-180, default: 7) |
| `--group-by` | | Group by fields: project_id, line_item (comma-separated) |
| `--project-ids` | | Filter by project IDs (comma-separated) |
| `--fetch-all` | | Fetch all pages automatically |
| `--verbose` | | Show detailed output |
| `--json` | | Output as JSON |
| `--help` | `-h` | Show help |

## API Response Structure

The tool handles the following OpenAI API response structure:

```json
{
  "object": "page",
  "data": [
    {
      "object": "bucket",
      "start_time": 1730419200,
      "end_time": 1730505600,
      "results": [
        {
          "object": "organization.costs.result",
          "amount": {
            "value": 0.06,
            "currency": "usd"
          },
          "line_item": null,
          "project_id": null
        }
      ]
    }
  ],
  "has_more": false,
  "next_page": null
}
```

## Development

### Running Tests

```bash
swift test
```

### Project Structure

```
OpenAICost/
├── Package.swift
├── Sources/
│   ├── OpenAICost/
│   │   ├── Models.swift          # Data models
│   │   ├── OpenAIClient.swift    # API client
│   │   └── Extensions.swift      # Utility extensions
│   └── OpenAICostCLI/
│       └── main.swift            # CLI interface
└── Tests/
    └── OpenAICostTests/
        └── OpenAICostTests.swift
```

### Key Features

- **Automatic Snake Case Conversion**: Uses `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
- **Date Handling**: Unix timestamps automatically converted to `Date` objects
- **Pagination**: Automatic handling of paginated responses with `--fetch-all`
- **Error Handling**: Comprehensive error handling with descriptive messages
- **Async/Await**: Modern Swift concurrency throughout

## Examples

### Get last week's costs with details:
```bash
openai-cost --start-time 7 --verbose
```

Output:
```
OpenAI Cost Report
==================

Total Cost: $1.2345 USD
Time Buckets: 7

Bucket 1:
  Period: Nov 1, 2024 at 12:00 AM - Nov 2, 2024 at 12:00 AM
  Cost: $0.1234 USD

Bucket 2:
  Period: Nov 2, 2024 at 12:00 AM - Nov 3, 2024 at 12:00 AM
  Cost: $0.2345 USD
...
```

### Get costs as JSON for processing:
```bash
openai-cost --start-time 7 --json | jq '.data[].results[].amount.value' | awk '{sum+=$1} END {print "Total: $"sum}'
```

## Error Handling

The tool provides clear error messages for common issues:

- Missing API key: "Missing API key. Set OPENAI_ADMIN_KEY environment variable"
- Invalid timestamps: "Invalid start time format. Use Unix timestamp or number of days ago."
- API errors: HTTP status codes and error details
- Network issues: Connection and timeout errors

## License

[Add your license here] 