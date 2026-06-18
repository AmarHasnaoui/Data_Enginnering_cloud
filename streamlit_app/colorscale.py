def value_to_rgba(value, vmin: float, vmax: float):
    if value is None or vmin is None or vmax is None or vmin == vmax:
        return [190, 190, 190, 160]
    t = max(0.0, min(1.0, (value - vmin) / (vmax - vmin)))
    r = int(40 + 200 * t)
    g = int(200 - 160 * t)
    b = 60
    return [r, g, b, 180]
