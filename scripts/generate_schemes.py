#!/usr/bin/env python3
"""
不忘课表 图标方案生成器
理念："忘"字解构为抽象图形
- 透明背景、扁平设计、数学曲线
- 清新活力配色
"""
from PIL import Image, ImageDraw
import math
import os
import sys

SIZE = 1024
CENTER = SIZE // 2

def lerp(a, b, t):
    return a + (b - a) * t

def bezier(p0, p1, p2, p3, t):
    """三次贝塞尔曲线"""
    u = 1 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
    )

def draw_bezier(draw, p0, p1, p2, p3, color, width):
    """绘制贝塞尔曲线"""
    points = []
    for i in range(101):
        t = i / 100
        points.append(bezier(p0, p1, p2, p3, t))
    for i in range(len(points) - 1):
        draw.line([points[i], points[i+1]], fill=color, width=width, joint='curve')

def draw_smooth_curve(draw, points, color, width):
    """绘制平滑曲线（多段贝塞尔）"""
    for i in range(len(points) - 1):
        p0 = points[i]
        p3 = points[i + 1]
        # 控制点：让曲线平滑
        dx = (p3[0] - p0[0]) * 0.4
        dy = (p3[1] - p0[1]) * 0.4
        p1 = (p0[0] + dx, p0[1])
        p2 = (p3[0] - dx, p3[1])
        draw_bezier(draw, p0, p1, p2, p3, color, width)

# ═══════════════════════════════════════
# 方案 A："忘"字解构 — 亡+心
# 亡：上方折线（失去、消散）
# 心：下方三点/曲线（记忆、情感）
# ═══════════════════════════════════════
def scheme_a(output_dir):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 配色：珊瑚粉 + 暖橙 + 薰衣草紫（清新活力）
    coral = (255, 107, 129)      # #FF6B81
    orange = (255, 165, 2)       # #FFA502
    lavender = (116, 185, 255)   # #74B9FF
    mint = (0, 206, 209)         # #00CED1
    
    # ── "亡"：上方抽象折线 ──
    # 从左上到右下，再折回，代表"失去"
    # 用粗线条，渐变色
    y_top = 180
    y_mid = 420
    x_left = 200
    x_right = 820
    x_mid = 512
    
    # 第一笔：横（从左到右）
    for w in range(20):
        t = w / 20
        color = (
            int(lerp(coral[0], orange[0], t)),
            int(lerp(coral[1], orange[1], t)),
            int(lerp(coral[2], orange[2], t)),
            220
        )
        draw.line([(x_left, y_top + w), (x_right, y_top + w)], fill=color)
    
    # 第二笔：竖折（从横的右端向下，再折向左下）
    # 竖段
    for w in range(18):
        t = w / 18
        color = (
            int(lerp(orange[0], coral[0], t)),
            int(lerp(orange[1], coral[1], t)),
            int(lerp(orange[2], coral[2], t)),
            220
        )
        draw.line([(x_right + w, y_top), (x_right + w, y_mid)], fill=color)
    
    # 折段（斜向左下）
    for w in range(16):
        t = w / 16
        x_start = x_right + w
        y_start = y_mid
        x_end = x_mid
        y_end = y_mid + 200
        # 画斜线
        steps = 50
        for s in range(steps):
            st = s / steps
            px = lerp(x_start, x_end, st)
            py = lerp(y_start, y_end, st)
            draw.rectangle([px, py, px + 2, py + 2], fill=color)
    
    # ── "心"：下方三点 + 弧线 ──
    # 三点代表：记忆、情感、坚持
    dot_y = 700
    dot_r = 45
    
    # 左点（记忆）— 薰衣草蓝
    draw.ellipse([280 - dot_r, dot_y - dot_r, 280 + dot_r, dot_y + dot_r],
                 fill=lavender)
    
    # 中点（情感）— 珊瑚粉（最大，是核心）
    draw.ellipse([512 - dot_r * 1.3, dot_y - dot_r * 1.3, 
                  512 + dot_r * 1.3, dot_y + dot_r * 1.3],
                 fill=coral)
    
    # 右点（坚持）— 薄荷绿
    draw.ellipse([744 - dot_r, dot_y - dot_r, 744 + dot_r, dot_y + dot_r],
                 fill=mint)
    
    # 连接三点的弧线（用贝塞尔）
    draw_bezier(draw, (280, dot_y), (350, dot_y + 80), (440, dot_y + 80), (512, dot_y),
                coral + (120,), 6)
    draw_bezier(draw, (512, dot_y), (580, dot_y + 80), (670, dot_y + 80), (744, dot_y),
                orange + (120,), 6)
    
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, 'scheme_a.png')
    img.save(path, 'PNG')
    print(f'✅ 方案A "亡+心" 解构: {path}')
    return path

# ═══════════════════════════════════════
# 方案 B："不"字解构 — 抽象几何
# "不"：一横 + 一撇 + 一竖 + 一点
# 四笔解构成四个几何色块
# ═══════════════════════════════════════
def scheme_b(output_dir):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 配色：活力渐变
    colors = [
        (255, 107, 129, 230),   # 珊瑚粉
        (255, 165, 2, 230),     # 暖橙
        (116, 185, 255, 230),   # 天蓝
        (0, 206, 209, 230),     # 薄荷
    ]
    
    # ── 横：圆角矩形 ──
    draw.rounded_rectangle([180, 300, 844, 380], radius=40, fill=colors[0])
    
    # ── 撇：三角形渐变（从粗到细）──
    # 用多边形模拟
    pie_points = [
        (512, 380),   # 起点（横的中点）
        (480, 400),   # 左宽
        (200, 780),   # 左下终点
        (240, 780),   # 右下终点（窄）
        (544, 400),   # 右宽
    ]
    draw.polygon(pie_points, fill=colors[1])
    
    # ── 竖：圆角矩形 ──
    draw.rounded_rectangle([482, 380, 542, 820], radius=30, fill=colors[2])
    
    # ── 点：圆形 ──
    draw.ellipse([700, 580, 800, 680], fill=colors[3])
    
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, 'scheme_b.png')
    img.save(path, 'PNG')
    print(f'✅ 方案B "不"字解构: {path}')
    return path

# ═══════════════════════════════════════
# 方案 C：莫比乌斯环 + 时钟
# "不忘" = 记忆的循环，永不终止
# 用 ∞ 符号 + 时钟刻度
# ═══════════════════════════════════════
def scheme_c(output_dir):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 配色
    coral = (255, 107, 129)
    lavender = (116, 185, 255)
    
    # ── 莫比乌斯环 / ∞ 符号 ──
    # 用贝塞尔曲线画 ∞
    cx, cy = CENTER, CENTER
    
    # 左环
    r = 180
    draw_bezier(draw,
        (cx, cy),
        (cx - r * 1.8, cy - r * 1.2),
        (cx - r * 1.8, cy + r * 1.2),
        (cx, cy),
        coral + (200,), 28)
    
    # 右环
    draw_bezier(draw,
        (cx, cy),
        (cx + r * 1.8, cy - r * 1.2),
        (cx + r * 1.8, cy + r * 1.2),
        (cx, cy),
        lavender + (200,), 28)
    
    # ── 中心交汇处加粗 ──
    draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40],
                 fill=(255, 165, 2, 230))  # 橙色中心点
    
    # ── 12个刻度点（时钟概念）──
    for i in range(12):
        angle = math.radians(i * 30 - 90)
        r_outer = 340
        r_inner = 310
        x1 = cx + r_inner * math.cos(angle)
        y1 = cy + r_inner * math.sin(angle)
        x2 = cx + r_outer * math.cos(angle)
        y2 = cy + r_outer * math.sin(angle)
        w = 6 if i % 3 == 0 else 3
        draw.line([(x1, y1), (x2, y2)], fill=(200, 200, 210, 150), width=w)
    
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, 'scheme_c.png')
    img.save(path, 'PNG')
    print(f'✅ 方案C "莫比乌斯环": {path}')
    return path

# ═══════════════════════════════════════
# 方案 D：流体曲线 — "忘"的笔画化为流动的线
# 三条流动的彩色曲线交织
# ═══════════════════════════════════════
def scheme_d(output_dir):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 三条曲线代表"忘"的三笔
    colors = [
        (255, 107, 129, 200),   # 珊瑚粉
        (116, 185, 255, 200),   # 天蓝
        (0, 206, 209, 200),     # 薄荷
    ]
    
    # 曲线1：从左上到右下（横）
    curve1 = [(150, 250), (350, 200), (650, 350), (870, 300)]
    draw_smooth_curve(draw, curve1, colors[0], 24)
    
    # 曲线2：从中间向下（竖）
    curve2 = [(512, 300), (480, 500), (520, 650), (512, 850)]
    draw_smooth_curve(draw, curve2, colors[1], 24)
    
    # 曲线3：从右上到左下（撇）
    curve3 = [(700, 350), (600, 500), (400, 650), (250, 800)]
    draw_smooth_curve(draw, curve3, colors[2], 24)
    
    # 交汇处的圆点
    draw.ellipse([490, 280, 534, 324], fill=(255, 165, 2, 230))
    
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, 'scheme_d.png')
    img.save(path, 'PNG')
    print(f'✅ 方案D "流体曲线": {path}')
    return path

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else './icon_schemes'
    scheme_a(out)
    scheme_b(out)
    scheme_c(out)
    scheme_d(out)
    print(f'\n🎨 四个方案已生成到: {out}/')
