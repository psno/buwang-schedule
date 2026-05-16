#!/usr/bin/env python3
"""
不忘课表 iOS 风格图标生成器 v4（最终版）
Apple Calendar aesthetic: 极简、微妙深度、精致排版
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os
import sys

SIZE = 1024

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_color(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(min(len(c1), len(c2))))

def ease(t):
    return t * t * (3 - 2 * t)

def generate_icon(output_dir):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # ═══════════════════════════════════════
    # 1. 背景：柔和蓝渐变（去饱和，更 Apple）
    # ═══════════════════════════════════════
    top_bg = (55, 145, 240)    # 柔和蓝
    bot_bg = (25, 70, 175)     # 深蓝
    for y in range(SIZE):
        t = ease(y / SIZE)
        c = lerp_color(top_bg, bot_bg, t)
        draw.line([(0, y), (SIZE, y)], fill=c + (255,))
    
    # ═══════════════════════════════════════
    # 2. 微妙光晕（极淡，不抢主体）
    # ═══════════════════════════════════════
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(450, 0, -5):
        t = (r / 450) ** 2
        a = int(12 * (1 - t))
        glow_draw.ellipse([200 - r, 120 - r, 200 + r, 120 + r],
                          fill=(160, 210, 255, a))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)
    
    # ═══════════════════════════════════════
    # 3. 日历卡片
    # ═══════════════════════════════════════
    cal_w, cal_h = 530, 590
    cal_x = (SIZE - cal_w) // 2
    cal_y = (SIZE - cal_h) // 2 + 65
    
    # 极淡阴影（Apple 风格：几乎看不见但营造浮起感）
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        [cal_x + 4, cal_y + 8, cal_x + cal_w + 4, cal_y + cal_h + 8],
        radius=30, fill=(0, 0, 0, 35)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)
    
    # 白色卡片
    draw.rounded_rectangle(
        [cal_x, cal_y, cal_x + cal_w, cal_y + cal_h],
        radius=30, fill=(255, 255, 255, 238)
    )
    
    # ═══════════════════════════════════════
    # 4. 顶部红色条（Apple Calendar 去饱和红）
    # ═══════════════════════════════════════
    bar_h = 100
    # Apple Calendar 红：#FF3B30 → 去饱和后约 #E8453C
    apple_red_top = (235, 65, 55)
    apple_red_bot = (195, 45, 38)
    
    for y in range(bar_h):
        t = ease(y / bar_h)
        c = lerp_color(apple_red_top, apple_red_bot, t)
        draw.line([(cal_x + 1, cal_y + y), (cal_x + cal_w - 1, cal_y + y)],
                  fill=c + (240,))
    
    # 圆角覆盖
    draw.rounded_rectangle(
        [cal_x, cal_y, cal_x + cal_w, cal_y + bar_h],
        radius=30, fill=apple_red_top + (240,)
    )
    draw.rectangle([cal_x, cal_y + bar_h - 30, cal_x + cal_w, cal_y + bar_h],
                   fill=apple_red_bot + (240,))
    
    # 红色条顶部微高光
    for y in range(25):
        t = 1 - y / 25
        a = int(18 * t * t)
        draw.line([(cal_x + 15, cal_y + y), (cal_x + cal_w - 15, cal_y + y)],
                  fill=(255, 255, 255, a))
    
    # ═══════════════════════════════════════
    # 5. 排版（Apple 风格：层次分明）
    # ═══════════════════════════════════════
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    fp = next((p for p in font_paths if os.path.exists(p)), None)
    
    if fp:
        font_num = ImageFont.truetype(fp, 210)
        font_day = ImageFont.truetype(fp.replace("-Bold", ""), 36)
        font_month = ImageFont.truetype(fp.replace("-Bold", ""), 30)
    else:
        font_num = font_day = font_month = ImageFont.load_default()
    
    # 大日期（深灰，不是纯黑——更柔和）
    date_y = cal_y + bar_h + 185
    draw.text((SIZE // 2, date_y), "16",
              fill=(45, 45, 55), font=font_num, anchor='mm')
    
    # 星期（浅灰，轻量感）
    draw.text((SIZE // 2, date_y + 120), "Saturday",
              fill=(120, 125, 135), font=font_day, anchor='mm')
    
    # 月份（更浅灰）
    draw.text((SIZE // 2, date_y + 165), "May",
              fill=(165, 170, 178), font=font_month, anchor='mm')
    
    # ═══════════════════════════════════════
    # 6. 底部指示线（极简装饰）
    # ═══════════════════════════════════════
    line_y = cal_y + cal_h - 45
    draw.rounded_rectangle(
        [SIZE // 2 - 50, line_y - 2, SIZE // 2 + 50, line_y + 2],
        radius=2, fill=(210, 215, 222, 100)
    )
    
    # ═══════════════════════════════════════
    # 7. 卡片顶部内高光（最后的深度感）
    # ═══════════════════════════════════════
    for y in range(40):
        t = 1 - y / 40
        a = int(8 * t * t)
        draw.line([(cal_x + 25, cal_y + y), (cal_x + cal_w - 25, cal_y + y)],
                  fill=(255, 255, 255, a))
    
    # ═══════════════════════════════════════
    # 8. 保存
    # ═══════════════════════════════════════
    os.makedirs(output_dir, exist_ok=True)
    
    icon_1024 = os.path.join(output_dir, 'icon_1024.png')
    img.save(icon_1024, 'PNG')
    print(f'✅ 1024x1024: {icon_1024}')
    
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, size in android_sizes.items():
        resized = img.resize((size, size), Image.LANCZOS)
        path = os.path.join(output_dir, f'ic_launcher_{size}.png')
        resized.save(path, 'PNG')
        print(f'✅ {size}x{size}: {path}')
    
    print(f'\n🎨 图标生成完成！输出目录: {output_dir}')
    return icon_1024

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else './icons'
    generate_icon(out)
