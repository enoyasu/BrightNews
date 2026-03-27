import SwiftUI

// MARK: - 起動アニメーション画面
// シーン構成：
//   ① 夜明けの空（グラデーション）
//   ② 太陽が水平線から昇る
//   ③ 海の波（横スクロール）
//   ④ 白い鳥が羽ばたきながら飛ぶ
//   ⑤ 白くフェードアウト → BrightNewsアイコンが出現 → アプリ起動

struct LaunchScreenView: View {

    /// アニメーション完了時に呼ばれるコールバック
    let onComplete: () -> Void

    // ── 空・背景 ──
    @State private var skyProgress: Double = 0      // 0=薄暗い夜明け前  → 1=明るい朝

    // ── 太陽 ──
    @State private var sunRise: Double    = 0      // 0=水平線下  → 1=空中
    @State private var sunGlow: Double    = 0      // 光芒の強さ

    // ── 海 ──
    @State private var wavePhase: Double  = 0      // 波の位相（連続アニメ）

    // ── 鳥 ──
    @State private var birdX: Double      = -0.18  // 画面幅比（−=画面外左）
    @State private var birdArc: Double    = 0      // 飛行弧 0→1
    @State private var wingFlap: Double   = 0      // 翼の角度 -1〜+1
    @State private var birdOpacity: Double = 0

    // ── 終了遷移 ──
    @State private var whiteAlpha: Double = 0      // 白フェード
    @State private var logoAlpha: Double  = 0      // ロゴ出現
    @State private var logoScale: Double  = 0.4    // ロゴスケール

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizonY = h * 0.60   // 水平線のY座標

            ZStack {
                // ── ① 空 ──
                skyView(bright: skyProgress)
                    .ignoresSafeArea()

                // ── ② 太陽の光芒（グロー） ──
                sunGlowView(
                    cx: w * 0.50,
                    cy: sunCenterY(horizonY: horizonY, h: h),
                    glow: sunGlow,
                    radius: w * 0.14
                )

                // ── ② 太陽本体 ──
                sunBodyView(
                    cx: w * 0.50,
                    cy: sunCenterY(horizonY: horizonY, h: h),
                    radius: w * 0.14
                )
                // 水平線より下はマスク（海で隠す前に太陽をクリップ）
                .mask(
                    Rectangle()
                        .frame(height: horizonY * 2)
                        .offset(y: -(h - horizonY))
                )

                // ── ③ 海 ──
                seaView(horizonY: horizonY, phase: wavePhase, w: w, h: h)

                // ── ④ 鳥 ──
                BirdShape(wingFlap: wingFlap)
                    .opacity(birdOpacity)
                    .position(
                        x: w * birdX,
                        y: horizonY - h * 0.20 - sin(birdArc * .pi) * h * 0.06
                    )
                    .scaleEffect(0.85 + birdArc * 0.15) // 近づくにつれ少し大きく

                // ── ⑤ 白フェード ──
                Color.white
                    .opacity(whiteAlpha)
                    .ignoresSafeArea()

                // ── ⑤ ロゴ ──
                AppIconMiniView()
                    .scaleEffect(logoScale)
                    .opacity(logoAlpha)
            }
        }
        .onAppear(perform: runAnimation)
    }

    // MARK: - 太陽の中心Y座標

    /// 水平線下から上昇する太陽のY座標を計算
    private func sunCenterY(horizonY: CGFloat, h: CGFloat) -> CGFloat {
        // sunRise=0 → 水平線ちょうど（見えない）
        // sunRise=1 → 水平線からh*0.30上の位置
        let riseOffset = CGFloat(sunRise) * h * 0.30
        return horizonY - riseOffset
    }

    // MARK: - サブビュー

    /// 空グラデーション
    @ViewBuilder
    private func skyView(bright: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: Color(hue: 0.60, saturation: 0.55 - bright * 0.30, brightness: 0.35 + bright * 0.50), location: 0.0),
                .init(color: Color(hue: 0.55, saturation: 0.45 - bright * 0.25, brightness: 0.60 + bright * 0.35), location: 0.45),
                .init(color: Color(hue: 0.09, saturation: 0.40 + bright * 0.30, brightness: 0.75 + bright * 0.20), location: 0.75),
                .init(color: Color(hue: 0.08, saturation: 0.50 + bright * 0.25, brightness: 0.85 + bright * 0.10), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 太陽グロー（放射状光芒）
    @ViewBuilder
    private func sunGlowView(cx: CGFloat, cy: CGFloat, glow: Double, radius: CGFloat) -> some View {
        ZStack {
            // 外側のソフトグロー
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.11, saturation: 0.70, brightness: 1.0).opacity(0.45 * glow),
                            Color(hue: 0.09, saturation: 0.60, brightness: 1.0).opacity(0.15 * glow),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: radius * 0.5,
                        endRadius: radius * 2.6
                    )
                )
                .frame(width: radius * 5.2, height: radius * 5.2)
                .blur(radius: 18)

            // 光線（8本・短い棒状）
            ForEach(0..<8) { i in
                let angle = Double(i) * 45 - 90
                let radians = angle * .pi / 180
                let innerR = radius * 1.25
                let outerR = radius * 1.68
                Rectangle()
                    .fill(Color(hue: 0.11, saturation: 0.55, brightness: 1.0).opacity(0.75 * glow))
                    .frame(width: radius * 0.12, height: radius * 0.43)
                    .cornerRadius(radius * 0.06)
                    .offset(y: -(innerR + (outerR - innerR) / 2))
                    .rotationEffect(.degrees(angle + 90))
            }
        }
        .position(x: cx, y: cy)
    }

    /// 太陽本体
    @ViewBuilder
    private func sunBodyView(cx: CGFloat, cy: CGFloat, radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: 0.13, saturation: 0.55, brightness: 1.0),
                        Color(hue: 0.08, saturation: 0.80, brightness: 0.95),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: Color(hue: 0.09, saturation: 0.70, brightness: 1.0).opacity(0.6), radius: 20)
            .position(x: cx, y: cy)
    }

    /// 海と波
    @ViewBuilder
    private func seaView(horizonY: CGFloat, phase: Double, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // 海面グラデーション
            LinearGradient(
                colors: [
                    Color(hue: 0.57, saturation: 0.65, brightness: 0.70),
                    Color(hue: 0.56, saturation: 0.70, brightness: 0.50),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(seaShape(y: horizonY, phase: phase, amplitude: 6, w: w, h: h))

            // 波の白い泡（手前）
            seaShape(y: horizonY + 5, phase: phase + 0.8, amplitude: 4, w: w, h: h)
                .fill(Color.white.opacity(0.18))

            // 水面の光反射
            seaReflection(horizonY: horizonY, phase: phase, w: w)
        }
    }

    /// 波形Path
    private func seaShape(y: CGFloat, phase: Double, amplitude: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        let steps = Int(w / 3)
        path.move(to: CGPoint(x: 0, y: y + amplitude * CGFloat(sin(phase))))
        for i in 1...steps {
            let x = CGFloat(i) * w / CGFloat(steps)
            let waveY = y + amplitude * CGFloat(sin(phase + Double(i) / Double(steps) * 4 * .pi))
            path.addLine(to: CGPoint(x: x, y: waveY))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0,  y: h))
        path.closeSubpath()
        return path
    }

    /// 水面の光反射（水平線付近の輝き）
    @ViewBuilder
    private func seaReflection(horizonY: CGFloat, phase: Double, w: CGFloat) -> some View {
        ForEach(0..<5) { i in
            let xBase = CGFloat(i) * w * 0.22 + CGFloat(sin(phase + Double(i))) * 15
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: CGFloat(20 + i * 8), height: 3)
                .position(x: xBase + w * 0.08, y: horizonY + 12 + CGFloat(i * 5))
        }
    }

    // MARK: - アニメーション実行

    private func runAnimation() {

        // ── ① 空が明るくなる（0→0.8秒）──
        withAnimation(.easeIn(duration: 0.8)) {
            skyProgress = 1.0
        }

        // ── ② 太陽が昇る（0.4→1.5秒）──
        withAnimation(.easeOut(duration: 1.1).delay(0.4)) {
            sunRise = 1.0
        }
        withAnimation(.easeIn(duration: 1.0).delay(0.6)) {
            sunGlow = 1.0
        }

        // ── ③ 波を動かす（連続ループ）──
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }

        // ── ④ 鳥が登場（1.2秒後）──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            birdOpacity = 1.0

            // 翼の羽ばたき（ループ）
            withAnimation(.easeInOut(duration: 0.30).repeatForever(autoreverses: true)) {
                wingFlap = 1.0
            }

            // 画面を横切る飛行（1.2→3.2秒）
            withAnimation(.easeInOut(duration: 2.0)) {
                birdX   = 1.22    // 画面右端の外へ
                birdArc = 1.0
            }
        }

        // ── ⑤ 白フェード（3.0→3.7秒）──
        withAnimation(.easeIn(duration: 0.7).delay(3.0)) {
            whiteAlpha = 1.0
        }

        // ── ⑤ ロゴ出現（3.4→4.2秒）──
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                logoAlpha = 1.0
                logoScale = 1.0
            }
        }

        // ── 完了コールバック（4.5秒後）──
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            onComplete()
        }
    }
}

// MARK: - 鳥の形（Canvas描画）

/// 白い鳥を Canvas で描画し、wingFlap で翼の羽ばたきを表現
private struct BirdShape: View {

    /// -1.0（翼下）〜 +1.0（翼上）
    var wingFlap: Double

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let up  = CGFloat(wingFlap) * 14   // 翼の上下変位（px）

            // ── 体 ──
            var body = Path()
            body.addEllipse(in: CGRect(x: cx - 13, y: cy - 5, width: 28, height: 10))
            ctx.fill(body, with: .color(.white))

            // ── 頭 ──
            var head = Path()
            head.addEllipse(in: CGRect(x: cx + 9, y: cy - 9, width: 13, height: 11))
            ctx.fill(head, with: .color(.white))

            // ── くちばし ──
            var beak = Path()
            beak.move(to:          CGPoint(x: cx + 22, y: cy - 5))
            beak.addLine(to:       CGPoint(x: cx + 30, y: cy - 3))
            beak.addLine(to:       CGPoint(x: cx + 22, y: cy - 1))
            beak.closeSubpath()
            ctx.fill(beak, with: .color(Color(hue: 0.10, saturation: 0.70, brightness: 1.0)))

            // ── 左翼 ──
            var lWing = Path()
            lWing.move(to: CGPoint(x: cx - 2, y: cy - 1))
            lWing.addQuadCurve(
                to:      CGPoint(x: cx - 38, y: cy - up - 3),
                control: CGPoint(x: cx - 22, y: cy - up - 14)
            )
            lWing.addQuadCurve(
                to:      CGPoint(x: cx - 2,  y: cy + 4),
                control: CGPoint(x: cx - 22, y: cy + 4)
            )
            ctx.fill(lWing, with: .color(.white))

            // ── 右翼 ──
            var rWing = Path()
            rWing.move(to: CGPoint(x: cx + 2, y: cy - 1))
            rWing.addQuadCurve(
                to:      CGPoint(x: cx + 38, y: cy - up - 3),
                control: CGPoint(x: cx + 22, y: cy - up - 14)
            )
            rWing.addQuadCurve(
                to:      CGPoint(x: cx + 2,  y: cy + 4),
                control: CGPoint(x: cx + 22, y: cy + 4)
            )
            ctx.fill(rWing, with: .color(.white))

            // ── 尾羽 ──
            var tail = Path()
            tail.move(to:    CGPoint(x: cx - 11, y: cy))
            tail.addLine(to: CGPoint(x: cx - 23, y: cy - 6))
            tail.addLine(to: CGPoint(x: cx - 25, y: cy + 1))
            tail.addLine(to: CGPoint(x: cx - 23, y: cy + 6))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(.white))
        }
        .frame(width: 90, height: 50)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 2)
    }
}

// MARK: - 終了時に表示するミニアイコン

/// BrightNewsアプリアイコンのSwiftUI再現（起動画面ラストカット）
private struct AppIconMiniView: View {

    private let iconSize: CGFloat = 140
    private let cornerRadius: CGFloat = 30

    var body: some View {
        ZStack(alignment: .bottom) {

            // 白背景
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)

            // 青バンド（下部44%）
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(hue: 0.55, saturation: 0.62, brightness: 0.90))
                .frame(width: iconSize, height: iconSize * 0.44)

            // テキスト "BrightNews"
            Text("BrightNews")
                .font(.system(size: iconSize * 0.118, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, iconSize * 0.08)

            // 太陽（光線 + 円）
            ZStack {
                // 光線
                ForEach(0..<8) { i in
                    let angle = Double(i) * 45 - 90
                    let r = iconSize * 0.175
                    Rectangle()
                        .fill(Color(hue: 0.11, saturation: 0.65, brightness: 1.0))
                        .frame(width: iconSize * 0.036, height: iconSize * 0.08)
                        .cornerRadius(iconSize * 0.018)
                        .offset(y: -(r * 1.25 + iconSize * 0.04))
                        .rotationEffect(.degrees(angle + 90))
                }
                // 太陽本体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.13, saturation: 0.55, brightness: 1.0),
                                Color(hue: 0.07, saturation: 0.85, brightness: 0.95),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: iconSize * 0.35, height: iconSize * 0.35)
            }
            // アイコン中央より少し上に配置
            .offset(y: -(iconSize * 0.10))
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenView(onComplete: {})
}
