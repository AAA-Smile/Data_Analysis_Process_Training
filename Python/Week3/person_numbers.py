from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

p1, p2 = 0.10, 0.12
h = proportion_effectsize(p2, p1)
n = NormalIndPower().solve_power(effect_size=h, alpha=0.05, power=0.8, ratio=1)
print(f"每组需要约 {n:.0f} 人")