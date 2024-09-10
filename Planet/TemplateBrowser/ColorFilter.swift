//
//  ColorFilter.swift
//  Planet
//
//  Created by Xin Liu on 9/1/24.
//

import Foundation

// Color filter logic adapted from https://codepen.io/sosuke/pen/Pjoqqp

class CustomColor {
    var r: Double
    var g: Double
    var b: Double

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            self.r = Double((rgb & 0xFF0000) >> 16)
            self.g = Double((rgb & 0x00FF00) >> 8)
            self.b = Double(rgb & 0x0000FF)
        }
        else {
            self.r = 0
            self.g = 0
            self.b = 0
        }
    }

    init(r: Double, g: Double, b: Double) {
        self.r = 0
        self.g = 0
        self.b = 0
        set(r: r, g: g, b: b)
    }

    func toString() -> String {
        return "rgb(\(round(r)), \(round(g)), \(round(b)))"
    }

    func set(r: Double, g: Double, b: Double) {
        self.r = clamp(value: r)
        self.g = clamp(value: g)
        self.b = clamp(value: b)
    }

    func hueRotate(angle: Double = 0) {
        let radian = angle / 180 * Double.pi
        let sinValue = sin(radian)
        let cosValue = cos(radian)

        multiply(matrix: [
            0.213 + cosValue * 0.787 - sinValue * 0.213,
            0.715 - cosValue * 0.715 - sinValue * 0.715,
            0.072 - cosValue * 0.072 + sinValue * 0.928,
            0.213 - cosValue * 0.213 + sinValue * 0.143,
            0.715 + cosValue * 0.285 + sinValue * 0.140,
            0.072 - cosValue * 0.072 - sinValue * 0.283,
            0.213 - cosValue * 0.213 - sinValue * 0.787,
            0.715 - cosValue * 0.715 + sinValue * 0.715,
            0.072 + cosValue * 0.928 + sinValue * 0.072,
        ])
    }

    func grayscale(value: Double = 1) {
        multiply(matrix: [
            0.2126 + 0.7874 * (1 - value),
            0.7152 - 0.7152 * (1 - value),
            0.0722 - 0.0722 * (1 - value),
            0.2126 - 0.2126 * (1 - value),
            0.7152 + 0.2848 * (1 - value),
            0.0722 - 0.0722 * (1 - value),
            0.2126 - 0.2126 * (1 - value),
            0.7152 - 0.7152 * (1 - value),
            0.0722 + 0.9278 * (1 - value),
        ])
    }

    func sepia(value: Double = 1) {
        multiply(matrix: [
            0.393 + 0.607 * (1 - value),
            0.769 - 0.769 * (1 - value),
            0.189 - 0.189 * (1 - value),
            0.349 - 0.349 * (1 - value),
            0.686 + 0.314 * (1 - value),
            0.168 - 0.168 * (1 - value),
            0.272 - 0.272 * (1 - value),
            0.534 - 0.534 * (1 - value),
            0.131 + 0.869 * (1 - value),
        ])
    }

    func saturate(value: Double = 1) {
        multiply(matrix: [
            0.213 + 0.787 * value,
            0.715 - 0.715 * value,
            0.072 - 0.072 * value,
            0.213 - 0.213 * value,
            0.715 + 0.285 * value,
            0.072 - 0.072 * value,
            0.213 - 0.213 * value,
            0.715 - 0.715 * value,
            0.072 + 0.928 * value,
        ])
    }

    func multiply(matrix: [Double]) {
        let newR = clamp(value: r * matrix[0] + g * matrix[1] + b * matrix[2])
        let newG = clamp(value: r * matrix[3] + g * matrix[4] + b * matrix[5])
        let newB = clamp(value: r * matrix[6] + g * matrix[7] + b * matrix[8])
        r = newR
        g = newG
        b = newB
    }

    func brightness(value: Double = 1) {
        linear(slope: value)
    }

    func contrast(value: Double = 1) {
        linear(slope: value, intercept: -(0.5 * value) + 0.5)
    }

    func linear(slope: Double = 1, intercept: Double = 0) {
        r = clamp(value: r * slope + intercept * 255)
        g = clamp(value: g * slope + intercept * 255)
        b = clamp(value: b * slope + intercept * 255)
    }

    func invert(value: Double = 1) {
        r = clamp(value: (value + r / 255 * (1 - 2 * value)) * 255)
        g = clamp(value: (value + g / 255 * (1 - 2 * value)) * 255)
        b = clamp(value: (value + b / 255 * (1 - 2 * value)) * 255)
    }

    func hsl() -> (h: Double, s: Double, l: Double) {
        let r = self.r / 255
        let g = self.g / 255
        let b = self.b / 255
        let max = max(r, g, b)
        let min = min(r, g, b)
        var h: Double
        var s: Double
        var l: Double
        l = (max + min) / 2

        if max == min {
            h = 0
            s = 0
        }
        else {
            let d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            switch max {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            case b: h = (r - g) / d + 4
            default: h = 0
            }
            h /= 6
        }

        return (h: h * 100, s: s * 100, l: l * 100)
    }

    func clamp(value: Double) -> Double {
        return min(max(value, 0), 255)
    }
}

class Solver {
    var target: CustomColor
    var targetHSL: (h: Double, s: Double, l: Double)
    var reusedColor: CustomColor

    init(target: CustomColor, baseColor: CustomColor) {
        self.target = target
        self.targetHSL = target.hsl()
        self.reusedColor = CustomColor(r: 0, g: 0, b: 0)
    }

    func solve() -> (values: [Double], loss: Double, filter: String) {
        let result = solveNarrow(wide: solveWide())
        return (values: result.values, loss: result.loss, filter: css(filters: result.values))
    }

    func solveWide() -> (values: [Double], loss: Double) {
        let A = 5.0
        let c = 15.0
        let a: [Double] = [60, 180, 18000, 600, 1.2, 1.2]

        var best: (values: [Double], loss: Double) = (values: [], loss: Double.infinity)
        for _ in 0..<3 where best.loss > 25 {
            let initial: [Double] = [50, 20, 3750, 50, 100, 100]
            let result = spsa(A: A, a: a, c: c, values: initial, iters: 1000)
            if result.loss < best.loss {
                best = result
            }
        }
        return best
    }

    func solveNarrow(wide: (values: [Double], loss: Double)) -> (values: [Double], loss: Double) {
        let A = wide.loss
        let c = 2.0
        let A1 = A + 1
        let a: [Double] = [0.25 * A1, 0.25 * A1, A1, 0.25 * A1, 0.2 * A1, 0.2 * A1]
        return spsa(A: A, a: a, c: c, values: wide.values, iters: 500)
    }

    func spsa(A: Double, a: [Double], c: Double, values: [Double], iters: Int) -> (
        values: [Double], loss: Double
    ) {
        let alpha = 1.0
        let gamma = 0.16666666666666666

        var best: [Double]? = nil
        var bestLoss = Double.infinity
        var deltas = [Double](repeating: 0, count: 6)
        var highArgs = [Double](repeating: 0, count: 6)
        var lowArgs = [Double](repeating: 0, count: 6)

        var values = values
        for k in 0..<iters {
            let ck = c / pow(Double(k + 1), gamma)
            for i in 0..<6 {
                deltas[i] = Bool.random() ? 1 : -1
                highArgs[i] = values[i] + ck * deltas[i]
                lowArgs[i] = values[i] - ck * deltas[i]
            }

            let lossDiff = loss(filters: highArgs) - loss(filters: lowArgs)
            for i in 0..<6 {
                let g = lossDiff / (2 * ck) * deltas[i]
                let ak = a[i] / pow(A + Double(k + 1), alpha)
                values[i] = fix(value: values[i] - ak * g, idx: i)
            }

            let lossValue = loss(filters: values)
            if lossValue < bestLoss {
                best = values
                bestLoss = lossValue
            }
        }

        return (values: best ?? values, loss: bestLoss)
    }

    func fix(value: Double, idx: Int) -> Double {
        var max = 100.0
        if idx == 2 {
            max = 7500
        }
        else if idx == 4 || idx == 5 {
            max = 200
        }

        if idx == 3 {
            if value > max {
                return value.truncatingRemainder(dividingBy: max)
            }
            else if value < 0 {
                return max + value.truncatingRemainder(dividingBy: max)
            }
        }
        else if value < 0 {
            return 0
        }
        else if value > max {
            return max
        }

        return value
    }

    func loss(filters: [Double]) -> Double {
        let color = reusedColor
        color.set(r: 0, g: 0, b: 0)

        color.invert(value: filters[0] / 100)
        color.sepia(value: filters[1] / 100)
        color.saturate(value: filters[2] / 100)
        color.hueRotate(angle: filters[3] * 3.6)
        color.brightness(value: filters[4] / 100)
        color.contrast(value: filters[5] / 100)

        let colorHSL = color.hsl()
        return abs(color.r - target.r) + abs(color.g - target.g) + abs(color.b - target.b)
            + abs(colorHSL.h - targetHSL.h) + abs(colorHSL.s - targetHSL.s)
            + abs(colorHSL.l - targetHSL.l)
    }

    func css(filters: [Double]) -> String {
        func fmt(idx: Int, multiplier: Double = 1) -> String {
            return "\(round(filters[idx] * multiplier))"
        }
        return
            "invert(\(fmt(idx: 0))%) sepia(\(fmt(idx: 1))%) saturate(\(fmt(idx: 2))%) hue-rotate(\(fmt(idx: 3, multiplier: 3.6))deg) brightness(\(fmt(idx: 4))%) contrast(\(fmt(idx: 5))%)"
    }
}
