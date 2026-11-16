"""SONAR FINANCE - Referans hesaplama (docs/04-islem-akislari.md §2 ve §3).
Tam sayi aritmetigi; float yok. Dart ve TypeScript uygulamalari bu ciktilarla ayni sonucu vermeli.
Kullanim: python3 invoice_calc.py  -> ../test-vectors/invoice-calc.json uretir.
"""
import json
import os
import random


def rhu(a: int, b: int) -> int:
    """roundHalfUp(a / b); negatiflerde isaret ayri islenir (sifirdan uzaga yuvarlama)."""
    assert b > 0
    if a < 0:
        return -rhu(-a, b)
    return (2 * a + b) // (2 * b)


def calc_line(qty_milli: int, unit_price: int, discount_bp: int, vat_bp: int, includes_vat: bool) -> dict:
    if not includes_vat:
        net = rhu(qty_milli * unit_price, 1000)
        discount = rhu(net * discount_bp, 10000)
        taxable = net - discount
        vat = rhu(taxable * vat_bp, 10000)
        total = taxable + vat
    else:
        gross_before = rhu(qty_milli * unit_price, 1000)
        disc_incl = rhu(gross_before * discount_bp, 10000)
        total = gross_before - disc_incl
        taxable = rhu(total * 10000, 10000 + vat_bp)
        vat = total - taxable
        net = rhu(gross_before * 10000, 10000 + vat_bp)   # KDV haric, iskonto oncesi
        discount = net - taxable                           # KDV haric iskonto
    return {"netMinor": net, "discountMinor": discount, "vatMinor": vat, "totalMinor": total, "taxableMinor": taxable}


def calc_invoice(lines: list, includes_vat: bool) -> dict:
    out_lines = [calc_line(l["qtyMilli"], l["unitPriceMinor"], l["discountBp"], l["vatBp"], includes_vat) for l in lines]
    return {
        "lines": [{k: v for k, v in o.items() if k != "taxableMinor"} for o in out_lines],
        "subtotalMinor": sum(o["netMinor"] for o in out_lines),
        "discountMinor": sum(o["discountMinor"] for o in out_lines),
        "vatMinor": sum(o["vatMinor"] for o in out_lines),
        "totalMinor": sum(o["totalMinor"] for o in out_lines),
        "taxableMinor": sum(o["taxableMinor"] for o in out_lines),
    }


def new_avg_cost(old_qty_milli: int, old_avg: int, in_qty_milli: int, unit_cost: int) -> int:
    tot = old_qty_milli + in_qty_milli
    if tot <= 0:
        return unit_cost
    return rhu(old_qty_milli * old_avg + in_qty_milli * unit_cost, tot)


def unit_cost_from_line(taxable: int, qty_milli: int) -> int:
    """Alis satirinin KDV haric birim maliyeti (kurus)."""
    return rhu(taxable * 1000, qty_milli)


def recv(b: int) -> int:
    return max(b, 0)


def pay(b: int) -> int:
    return max(-b, 0)


def summary_delta(old_bal: int, new_bal: int) -> dict:
    return {"receivableDelta": recv(new_bal) - recv(old_bal), "payableDelta": pay(new_bal) - pay(old_bal)}


def build_vectors() -> dict:
    rnd = random.Random(20261116)
    invoices = []
    # Belgedeki sabit ornek
    fixed = [
        ([{"qtyMilli": 3000, "unitPriceMinor": 125000, "discountBp": 1000, "vatBp": 2000}], False),
        ([{"qtyMilli": 3000, "unitPriceMinor": 125000, "discountBp": 1000, "vatBp": 2000}], True),
        ([{"qtyMilli": 1000, "unitPriceMinor": 10000, "discountBp": 0, "vatBp": 2000}], False),
        ([{"qtyMilli": 1000, "unitPriceMinor": 12000, "discountBp": 0, "vatBp": 2000}], True),
        ([{"qtyMilli": 333, "unitPriceMinor": 1999, "discountBp": 0, "vatBp": 1000}], False),
        ([{"qtyMilli": 2500, "unitPriceMinor": 4500, "discountBp": 250, "vatBp": 100}], True),
        ([{"qtyMilli": 1, "unitPriceMinor": 1, "discountBp": 0, "vatBp": 2000}], False),
        ([{"qtyMilli": 1000, "unitPriceMinor": 0, "discountBp": 0, "vatBp": 2000}], False),
        ([{"qtyMilli": 1500, "unitPriceMinor": 1000, "discountBp": 0, "vatBp": 0}], False),
        ([{"qtyMilli": 1000, "unitPriceMinor": 100000, "discountBp": 10000, "vatBp": 2000}], False),
        ([
            {"qtyMilli": 40000, "unitPriceMinor": 85000, "discountBp": 0, "vatBp": 2000},
            {"qtyMilli": 500000, "unitPriceMinor": 4500, "discountBp": 500, "vatBp": 2000},
            {"qtyMilli": 6000, "unitPriceMinor": 1250000, "discountBp": 0, "vatBp": 1000},
        ], False),
    ]
    for lines, inc in fixed:
        invoices.append({"priceIncludesVat": inc, "lines": lines, "expected": calc_invoice(lines, inc)})
    vats = [0, 100, 1000, 2000]
    for _ in range(40):
        n = rnd.randint(1, 4)
        lines = [{
            "qtyMilli": rnd.choice([1, 250, 333, 500, 1000, 1500, 2500, 7000, 12345, 100000]),
            "unitPriceMinor": rnd.choice([1, 99, 1999, 4500, 12345, 85000, 1250000]),
            "discountBp": rnd.choice([0, 0, 100, 250, 500, 1000, 1250, 3333]),
            "vatBp": rnd.choice(vats),
        } for _ in range(n)]
        inc = rnd.random() < 0.5
        invoices.append({"priceIncludesVat": inc, "lines": lines, "expected": calc_invoice(lines, inc)})

    rounding = [{"a": a, "b": b, "expected": rhu(a, b)} for a, b in [(1, 2), (3, 2), (5, 10), (4, 10), (-1, 2), (-3, 2), (0, 7), (7, 3), (-7, 3), (25, 50), (10001, 10000)]]

    avg = []
    for old_q, old_a, in_q, uc in [(0, 0, 10000, 85000), (40000, 85000, 10000, 90000), (500000, 4500, 100000, 4700), (1000, 3333, 1000, 3334), (6000, 1250000, 0, 1300000)]:
        avg.append({"oldQtyMilli": old_q, "oldAvgMinor": old_a, "inQtyMilli": in_q, "unitCostMinor": uc, "expectedAvgMinor": new_avg_cost(old_q, old_a, in_q, uc)})

    unit_cost = [{"taxableMinor": t, "qtyMilli": q, "expectedUnitCostMinor": unit_cost_from_line(t, q)} for t, q in [(337500, 3000), (100, 3), (85000, 1000), (999, 1000)]]

    summ = [{"oldBalanceMinor": o, "newBalanceMinor": n, **summary_delta(o, n)} for o, n in [(0, 100000), (100000, -50000), (-30000, 0), (-30000, -10000), (50000, 50000)]]

    return {
        "version": "1.0.0",
        "doc": "Uretici: shared/reference/invoice_calc.py. docs/04 §2-§3,§8 ile birebir.",
        "roundHalfUp": rounding,
        "invoiceCalc": invoices,
        "averageCost": avg,
        "unitCostFromLine": unit_cost,
        "summaryDelta": summ,
    }


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test-vectors", "invoice-calc.json")
    data = build_vectors()
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("yazildi:", os.path.normpath(out), "| fatura vektoru:", len(data["invoiceCalc"]))
