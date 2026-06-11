## [Unreleased]

## [0.1.14] - 2026-06-11

### Added
- RSpec tests for all URL normalization cases in `Output#initialize`: scheme suffix in `protocol`, uppercase `protocol`, scheme prefix in `host`, port preservation in `host`, leading/trailing slashes in `basePath`, internal slashes in `basePath`, leading slash in `testid`, empty `basePath`, and a combined "all messy inputs" scenario

## [0.1.13] - 2026-06-11

### Fixed
- `Output#initialize`: replaced aggressive `gsub(%r{[:/]}, "")` stripping on `protocol`, `host`, and `basePath` with holistic URL component normalization — strips scheme prefix from `host`, extracts only the scheme name from `protocol` (downcased), strips leading/trailing slashes from `basePath` while preserving internal path separators, and strips leading slashes from `testid` in `softwareid` construction; previously, a `basePath` like `/path/to/test` would be corrupted to `pathtotest` and port numbers in `host` would be destroyed

## [0.1.12] - 2026-05-27

### Fixed
- `Output#createEvaluationResponse`: `score = "fail"` inside the `rescue` block and `summary = ...` inside the `if` block both introduced local variables that shadowed the `attr_accessor` methods for the entire method scope; replaced all references with `@score` and `@summary` to read and write the instance variables directly — this was causing `prov:value` to always be serialized as `nil` regardless of what callers set on `output.score`

## [0.1.11] - 2026-05-26

### Changed
- `TestInfra#get_tests_metrics` now fetches all test metrics in parallel using Ruby threads, significantly reducing latency when querying 40+ tests
- Refactored `TestInfra` internals into focused private helpers (`fetch_metric`, `fetch_metric_url`, `load_metric_graph`, `query_metric_graph`)
- `test_infrastructure.rb` now explicitly requires `jsonpath` rather than relying on transitive loading

### Added
- RSpec tests for `TestInfra#get_tests_metrics` and `#fetch_metric_url` covering happy path, missing metadata, RDF load failures, and empty input

## [0.1.0] - 2026-03-28

- Initial release
