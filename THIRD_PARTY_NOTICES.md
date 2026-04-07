# Third-Party Notices

This project redistributes or links against third-party open source
dependencies. Preserve the applicable upstream license and notice files when
redistributing source or binary builds.

## Direct SwiftPM dependencies

### Sparkle

- Repository: <https://github.com/sparkle-project/Sparkle>
- License: MIT
- Notes: The upstream `LICENSE` file also contains additional embedded
  third-party license notices that should be preserved when applicable.

### Mixpanel Swift

- Repository: <https://github.com/mixpanel/mixpanel-swift>
- License: Apache-2.0
- Notes: Mixpanel Swift depends on `json-logic-swift` for feature-flag
  evaluation in newer releases.

### Swift Markdown

- Repository: <https://github.com/swiftlang/swift-markdown>
- License: Apache-2.0
- Notes: The upstream repository includes a `NOTICE.txt`. Preserve applicable
  notices for downstream redistribution.

## Transitive dependency identified in the resolved package graph

### json-logic-swift

- Repository: <https://github.com/advantagefse/json-logic-swift>
- License: MIT

### swift-cmark

- Repository: <https://github.com/swiftlang/swift-cmark>
- License: BSD-2-Clause
- Notes: Included transitively through `swift-markdown`.

## Verification sources

- `ClaudeIsland.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Upstream repository license metadata and license files
