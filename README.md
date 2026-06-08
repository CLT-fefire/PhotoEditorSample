# PhotoEditorSample

사진 편집 샘플 앱 (JIRA [RIL-11](https://everysing.atlassian.net/browse/RIL-11), [R&D] Innovation Lab).
손가락으로 칠하는 방식의 **모자이크 · 블러 · 브러시 · 지우개** 편집 + **Undo/Redo** + **갤러리 저장**.

## 환경

| 항목 | 값 |
|:---|:---|
| 최소 지원 | iOS 12.0 |
| 빌드 | Xcode 26.3 |
| UI | UIKit (코드 기반, Storyboard 미사용) |
| 렌더링 | Core Image (`CIPixellate` / `CIGaussianBlur` / `CIBlendWithMask`) |
| 외부 의존성 | **없음** (순수 Apple SDK) |
| Bundle ID | `com.dearu.bubble.fork` |

## 설계 개요

- **스트로크 스택 + 지연 합성**: 편집을 픽셀에 즉시 굽지 않고 `Stroke` 배열로 보관, 표시 시 합성. Undo/Redo·지우개를 단일 모델로 해결 (Undo = strokes→redo 스택 이동, 새 편집 시 redo 무효화).
- **통일 합성 공식**: 모든 도구 = `CIBlendWithMask(source, 현재결과, mask)`. source만 다름 (모자이크/블러/원본/단색).
- **지우개 = 원본 드러내기**: 별도 분기 없이 "선택구간 제거" 시맨틱 성립.
- **정규화 좌표(0...1)**: 작업 해상도(2048px)에서 편집하고 원본 해상도(최대 4096px)에서 동일 스트로크 재렌더하여 저장.
- **라이브 미리보기**: 진행 중 스트로크는 `CAShapeLayer` 마스크로 즉시 표시(CI 미호출), 터치 업에 1회만 합성.
- **iOS 13+ SceneDelegate / iOS 12 AppDelegate window** 버전 분기.

## 구조

```
PhotoEditorSample/
├── App/        AppDelegate · SceneDelegate(iOS13+) · Info.plist · LaunchScreen
├── Model/      EditTool · Stroke · EditDocument(스택+Undo)
├── Rendering/  ImageCompositor · MaskRenderer · CoordinateMapper
├── Editor/     EditorViewController · CanvasView · ToolbarView · ParameterSliderView
└── Photos/     PhotoSaver (PHPhotoLibrary)
```

## 사용

1. **불러오기** → 사진 선택
2. 하단 도구 선택 (모자이크/블러/브러시/지우개)
3. 슬라이더로 파라미터 조절 (픽셀 크기·강도·투명도 / 굵기), 브러시는 색상(빨강/초록/파랑)
4. 사진 위를 문질러 편집
5. **되돌리기**로 직전 동작 취소, **다시실행**으로 복원
6. **저장** → 사진 앨범
