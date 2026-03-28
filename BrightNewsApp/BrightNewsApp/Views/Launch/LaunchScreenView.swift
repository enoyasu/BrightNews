import SwiftUI

// MARK: - 起動アニメーション画面
// ① 夜明けの空 → ② 太陽が昇る → ③ 海の波 → ④ 白い鳥が羽ばたく → ⑤ BrightNewsロゴへ遷移

struct LaunchScreenView: View {

    let onComplete: () -> Void

    // ── 空 ──
    @State private var skyProgress: Double = 0

    // ── 太陽 ──
    @State private var sunRise: Double = 0
    @State private var sunGlow: Double = 0

    // ── 海 ──
    @State private var wavePhase: Double = 0

    // ── 鳥（位置・表示） ──
    @State private var birdX: Double    = -0.18
    @State private var birdArc: Double  = 0
    @State private var birdOpacity: Double = 0

    // ── 遷移 ──
    @State private var whiteAlpha: Double = 0
    @State private var logoAlpha: Double  = 0
    @State private var logoScale: Double  = 0.4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizonY = h * 0.60

            ZStack {
                // ① 空
                skyView(bright: skyProgress).ignoresSafeArea()

                // ② 太陽グロー
                sunGlowView(cx: w * 0.50,
                            cy: sunCenterY(horizonY: horizonY, h: h),
                            glow: sunGlow, radius: w * 0.14)

                // ② 太陽本体（水平線以下をマスク）
                sunBodyView(cx: w * 0.50,
                            cy: sunCenterY(horizonY: horizonY, h: h),
                            radius: w * 0.14)
                .mask(
                    Rectangle()
                        .frame(height: horizonY * 2)
                        .offset(y: -(h - horizonY))
                )

                // ③ 海
                seaView(horizonY: horizonY, phase: wavePhase, w: w, h: h)

                // ④ 鳥（TimelineViewで翼をリアルタイム更新）
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let elapsed = tl.date.timeIntervalSinceReferenceDate
                    // 0.55秒周期でフラップ（sin: -1→+1→-1 の滑らかな繰り返し）
                    let flap = sin(elapsed * .pi * 2.0 / 0.55)
                    BirdShape(wingFlap: flap)
                }
                .opacity(birdOpacity)
                .position(
                    x: w * birdX,
                    y: horizonY - h * 0.20 - sin(birdArc * .pi) * h * 0.06
                )
                .scaleEffect(0.85 + birdArc * 0.15)

                // ⑤ 白フェード
                Color.white.opacity(whiteAlpha).ignoresSafeArea()

                // ⑤ ロゴ
                AppIconMiniView()
                    .scaleEffect(logoScale)
                    .opacity(logoAlpha)
            }
        }
        .onAppear(perform: runAnimation)
    }

    // MARK: - 太陽Y座標

    private func sunCenterY(horizonY: CGFloat, h: CGFloat) -> CGFloat {
        horizonY - CGFloat(sunRise) * h * 0.30
    }

    // MARK: - サブビュー

    @ViewBuilder
    private func skyView(bright: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: Color(hue: 0.60, saturation: 0.55 - bright * 0.30, brightness: 0.35 + bright * 0.50), location: 0.0),
                .init(color: Color(hue: 0.55, saturation: 0.45 - bright * 0.25, brightness: 0.60 + bright * 0.35), location: 0.45),
                .init(color: Color(hue: 0.09, saturation: 0.40 + bright * 0.30, brightness: 0.75 + bright * 0.20), location: 0.75),
                .init(color: Color(hue: 0.08, saturation: 0.50 + bright * 0.25, brightness: 0.85 + bright * 0.10), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    @ViewBuilder
    private func sunGlowView(cx: CGFloat, cy: CGFloat, glow: Double, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(hue: 0.11, saturation: 0.70, brightness: 1.0).opacity(0.45 * glow),
                        Color(hue: 0.09, saturation: 0.60, brightness: 1.0).opacity(0.15 * glow),
                        Color.clear,
                    ],
                    center: .center, startRadius: radius * 0.5, endRadius: radius * 2.6
                ))
                .frame(width: radius * 5.2, height: radius * 5.2)
                .blur(radius: 18)
            ForEach(0..<8) { i in
                let angle = Double(i) * 45 - 90
                let innerR = radius * 1.25; let outerR = radius * 1.68
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

    @ViewBuilder
    private func sunBodyView(cx: CGFloat, cy: CGFloat, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color(hue: 0.13, saturation: 0.55, brightness: 1.0),
                    Color(hue: 0.08, saturation: 0.80, brightness: 0.95),
                ],
                center: .center, startRadius: 0, endRadius: radius
            ))
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: Color(hue: 0.09, saturation: 0.70, brightness: 1.0).opacity(0.6), radius: 20)
            .position(x: cx, y: cy)
    }

    @ViewBuilder
    private func seaView(horizonY: CGFloat, phase: Double, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.57, saturation: 0.65, brightness: 0.70),
                         Color(hue: 0.56, saturation: 0.70, brightness: 0.50)],
                startPoint: .top, endPoint: .bottom
            )
            .mask(seaShape(y: horizonY, phase: phase, amplitude: 6, w: w, h: h))
            seaShape(y: horizonY + 5, phase: phase + 0.8, amplitude: 4, w: w, h: h)
                .fill(Color.white.opacity(0.18))
            seaReflection(horizonY: horizonY, phase: phase, w: w)
        }
    }

    private func seaShape(y: CGFloat, phase: Double, amplitude: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        let steps = Int(w / 3)
        path.move(to: CGPoint(x: 0, y: y + amplitude * CGFloat(sin(phase))))
        for i in 1...steps {
            let x = CGFloat(i) * w / CGFloat(steps)
            let wY = y + amplitude * CGFloat(sin(phase + Double(i) / Double(steps) * 4 * .pi))
            path.addLine(to: CGPoint(x: x, y: wY))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }

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

    // MARK: - アニメーション

    private func runAnimation() {
        // ① 空が明るくなる
        withAnimation(.easeIn(duration: 0.8)) { skyProgress = 1.0 }

        // ② 太陽が昇る
        withAnimation(.easeOut(duration: 1.1).delay(0.4)) { sunRise = 1.0 }
        withAnimation(.easeIn(duration: 1.0).delay(0.6)) { sunGlow = 1.0 }

        // ③ 波（連続ループ）
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }

        // ④ 鳥が登場して横断（1.2秒後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.25)) { birdOpacity = 1.0 }
            withAnimation(.easeInOut(duration: 2.0)) {
                birdX   = 1.22
                birdArc = 1.0
            }
        }

        // ⑤ 白フェード（3.0→3.7秒）
        withAnimation(.easeIn(duration: 0.7).delay(3.0)) { whiteAlpha = 1.0 }

        // ⑤ ロゴ出現（3.4秒後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                logoAlpha = 1.0
                logoScale = 1.0
            }
        }

        // 完了（4.5秒後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { onComplete() }
    }
}

// MARK: - 鳥（Canvas描画）

/// wingFlap: -1.0（翼下）〜 +1.0（翼上）で羽ばたきを表現
private struct BirdShape: View {

    var wingFlap: Double

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let up = CGFloat(wingFlap) * 14   // 上下変位（最大±14px）

            // 体
            var body = Path()
            body.addEllipse(in: CGRect(x: cx - 13, y: cy - 5, width: 28, height: 10))
            ctx.fill(body, with: .color(.white))

            // 頭
            var head = Path()
            head.addEllipse(in: CGRect(x: cx + 9, y: cy - 9, width: 13, height: 11))
            ctx.fill(head, with: .color(.white))

            // くちばし
            var beak = Path()
            beak.move(to:    CGPoint(x: cx + 22, y: cy - 5))
            beak.addLine(to: CGPoint(x: cx + 30, y: cy - 3))
            beak.addLine(to: CGPoint(x: cx + 22, y: cy - 1))
            beak.closeSubpath()
            ctx.fill(beak, with: .color(Color(hue: 0.10, saturation: 0.70, brightness: 1.0)))

            // 左翼（up が大きいほど上に動く）
            var lWing = Path()
            lWing.move(to: CGPoint(x: cx - 2, y: cy - 1))
            lWing.addQuadCurve(
                to:      CGPoint(x: cx - 38, y: cy - up - 3),
                control: CGPoint(x: cx - 22, y: cy - up - 14)
            )
            lWing.addQuadCurve(
                to:      CGPoint(x: cx - 2, y: cy + 4),
                control: CGPoint(x: cx - 22, y: cy + 4)
            )
            ctx.fill(lWing, with: .color(.white))

            // 右翼（左翼の鏡像）
            var rWing = Path()
            rWing.move(to: CGPoint(x: cx + 2, y: cy - 1))
            rWing.addQuadCurve(
                to:      CGPoint(x: cx + 38, y: cy - up - 3),
                control: CGPoint(x: cx + 22, y: cy - up - 14)
            )
            rWing.addQuadCurve(
                to:      CGPoint(x: cx + 2, y: cy + 4),
                control: CGPoint(x: cx + 22, y: cy + 4)
            )
            ctx.fill(rWing, with: .color(.white))

            // 尾羽
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

// MARK: - ミニアイコン（遷移ラスト）

private struct AppIconMiniView: View {

    private let s: CGFloat = 140    // アイコンサイズ
    private let r: CGFloat = 30     // 角丸半径
    // 青バンドは下部40%（= 56pt）、白エリアは上部60%（= 84pt）
    private var bandH: CGFloat   { s * 0.40 }
    private var bandTopY: CGFloat { s * 0.60 }
    // 太陽中心：s*0.35（上下に余白を均等確保）
    private var sunCY: CGFloat   { s * 0.35 }
    private var sunR: CGFloat    { s * 0.145 }  // 20.3pt

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── 白背景 ──
            Color.white
                .frame(width: s, height: s)

            // ── 太陽（光線は青バンドで隠れる） ──
            ZStack {
                // 光線8本
                ForEach(0..<8) { i in
                    let angle  = Double(i) * 45 - 90
                    let innerR = sunR * 1.30
                    let outerR = sunR * 1.72
                    let midR   = (innerR + outerR) / 2
                    Rectangle()
                        .fill(Color(hue: 0.11, saturation: 0.65, brightness: 1.0))
                        .frame(width: max(2, s * 0.034), height: outerR - innerR)
                        .cornerRadius(s * 0.017)
                        .offset(y: -midR)
                        .rotationEffect(.degrees(angle + 90))
                }
                // 太陽本体
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hue: 0.13, saturation: 0.55, brightness: 1.0),
                                 Color(hue: 0.07, saturation: 0.85, brightness: 0.95)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: sunR * 2, height: sunR * 2)
            }
            .position(x: s * 0.5, y: sunCY)

            // ── 青バンド（太陽下の光線を隠す） ──
            Color(hue: 0.55, saturation: 0.62, brightness: 0.90)
                .frame(width: s, height: bandH)
                .offset(y: bandTopY)

            // ── BrightNews テキスト（青バンド内中央） ──
            Text("BrightNews")
                .font(.system(size: s * 0.118, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: s, height: bandH)
                .offset(y: bandTopY)
        }
        .frame(width: s, height: s)
        .clipShape(RoundedRectangle(cornerRadius: r))
        .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
    }
}

#Preview { LaunchScreenView(onComplete: {}) }
