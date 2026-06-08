# PhotoEditorSample

사진 편집 샘플 앱 (JIRA RIL-11, [R&D] Innovation Lab). 손가락으로 칠하는 모자이크·블러·브러시·지우개 + Undo + 갤러리 저장. 독립 iOS UIKit 앱, 외부 의존성 0.

@/Users/Shared/Source/SharedDocs/rules/apple-swift.md
@/Users/Shared/Source/SharedDocs/rules/git-write-allowed.md
@/Users/Shared/Source/SharedDocs/rules/vibe-coding.md

> 지식·계획 hub: `/Users/Shared/Source/SharedDocs/knowledge/photo-editor-sample/` (STATE.md 세션 시작 시 우선 읽기).

## 환경

| 항목 | 값 |
|:---|:---|
| 최소 지원 | iOS 12.0 |
| 빌드 | Xcode 26.3 (iPhoneOS 26.2 SDK) |
| UI | UIKit, 코드 기반 (Storyboard/SwiftUI 미사용) |
| 렌더링 | Core Image (`CIPixellate`/`CIGaussianBlur`/`CIBlendWithMask`) |
| 외부 의존성 | 없음 (순수 Apple SDK) |
| Bundle ID | `com.dearu.bubble.fork` |
| Repo | `https://github.com/CLT-fefire/PhotoEditorSample` (private) |
| 프로젝트 형식 | objectVersion 77 + `PBXFileSystemSynchronizedRootGroup` (파일 추가 시 pbxproj 수정 불필요) |

## 아키텍처

- **스트로크 스택 + 지연 합성** ([Model/EditDocument](PhotoEditorSample/Model/EditDocument.swift)): 편집을 `Stroke` 배열로 보관, 표시 시 합성. Undo·지우개를 단일 모델로 해결.
- **통일 합성 공식** ([Rendering/ImageCompositor](PhotoEditorSample/Rendering/ImageCompositor.swift)): 모든 도구 = `CIBlendWithMask(source, 현재결과, mask)`. source만 다름 (모자이크/블러/원본/단색). 지우개 = 원본 드러내기.
- **정규화 좌표(0...1)** ([Rendering/CoordinateMapper](PhotoEditorSample/Rendering/CoordinateMapper.swift)): 작업 해상도(2048) 편집 + 원본 해상도(≤4096) 저장.
- **라이브 미리보기** ([Editor/CanvasView](PhotoEditorSample/Editor/CanvasView.swift)): 진행 스트로크는 `CAShapeLayer` 마스크로 즉시 표시(CI 미호출), 터치 업에 1회 합성.
- **iOS 13+ SceneDelegate / iOS 12 AppDelegate window** 버전 분기 ([App/](PhotoEditorSample/App/)).

## 주의 (iOS 12 제약)

- `UIColor.label`/`.systemBackground` 등 **iOS 13+ semantic 색상 금지** → `.darkText`/`.white` 등 사용.
- `UIImage(systemName:)` (SF Symbols), PencilKit, SwiftUI **전부 iOS 13+ → 사용 불가**.
- iOS 13+ 전용 API는 `@available(iOS 13.0, *)` + `if #available` 게이팅 필수.
- `.swift` 수정 후 `swift_validate_file` 또는 시뮬레이터 빌드로 검증.

## 빌드 검증

```bash
xcodebuild build -project PhotoEditorSample.xcodeproj -scheme PhotoEditorSample \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PES_DD CODE_SIGNING_ALLOWED=NO
```
