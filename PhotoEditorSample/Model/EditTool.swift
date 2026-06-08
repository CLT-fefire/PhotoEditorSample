import UIKit

/// 편집 도구 종류. 모든 도구는 "칠한 영역에만 적용"되는 마스크 방식으로 동작한다.
enum EditTool: Int, CaseIterable {
    case mosaic   // 모자이크 (픽셀 크기 + 굵기)
    case blur     // 블러     (강도 + 굵기)
    case brush    // 브러시   (색상 + 투명도 + 굵기)
    case eraser   // 지우개   (굵기) — 칠한 영역의 편집을 제거 = 원본 복원

    var title: String {
        switch self {
        case .mosaic: return "모자이크"
        case .blur:   return "블러"
        case .brush:  return "브러시"
        case .eraser: return "지우개"
        }
    }

    /// 상단(파라미터1) 슬라이더 라벨. eraser는 파라미터1이 없다.
    var primaryParamTitle: String? {
        switch self {
        case .mosaic: return "픽셀 크기"
        case .blur:   return "흐림 강도"
        case .brush:  return "투명도"
        case .eraser: return nil
        }
    }

    /// 색상 선택을 사용하는 도구인지 여부.
    var usesColor: Bool { self == .brush }
}

/// 브러시 색상 (요구사항: 빨강/초록/파랑).
enum BrushColor: Int, CaseIterable {
    case red
    case green
    case blue

    var title: String {
        switch self {
        case .red:   return "빨강"
        case .green: return "초록"
        case .blue:  return "파랑"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .red:   return UIColor(red: 1.0,  green: 0.23, blue: 0.19, alpha: 1)
        case .green: return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .blue:  return UIColor(red: 0.0,  green: 0.48, blue: 1.0,  alpha: 1)
        }
    }
}

/// 한 번의 드로잉(터치 시작~끝)에 대한 도구 설정 스냅샷.
/// CanvasView가 터치 시작 시점에 EditorViewController로부터 받아 Stroke로 굳힌다.
struct StrokeConfig {
    var tool: EditTool
    /// 이미지 최단변 대비 비율 (해상도 독립).
    var brushRadius: CGFloat
    /// 모자이크 픽셀 블록 크기 (이미지 최단변 대비 비율).
    var mosaicScale: CGFloat
    /// 블러 반경 (이미지 최단변 대비 비율).
    var blurSigma: CGFloat
    /// 브러시 색상.
    var color: UIColor
    /// 브러시 투명도 (0...1).
    var opacity: CGFloat
}
