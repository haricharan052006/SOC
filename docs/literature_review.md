# Literature review and parameter validation

Done before Week 3 to check the Week 1–2 modelling choices and to position the
project honestly. Sources were found by web search (abstracts, open-access pages,
datasheets). **Paywalled papers were seen as abstracts only — read the full text
through your college IEEE / Elsevier access before citing.** Items marked
*(unverified)* were not confirmed from a page that was actually opened.

## 1. Where this project sits

- **SOC estimation with an EKF on an equivalent-circuit model is standard.**
  The classic reference is Plett's three-part series (J. Power Sources 134(2),
  2004, pp. 252–292; Part 2 introduces the one-state hysteresis model used here).
- **LFP's flat OCV plateau and hysteresis are the recognised hard part.** Several
  papers state that SOC is only weakly observable from voltage on the plateau.
  Zhao, Duncan & Howey (arXiv 1510.06553) show formally that an ECM is locally
  observable only where dOCV/dSOC ≠ 0 — this is the theory behind our
  "flat-region degradation" result.
- **Reported numbers:** on CALCE A123 LFP data a baseline EKF gave SOC RMSE of
  1.4 % (DST, 25 °C) up to 5.2 % (US06, 0 °C), with max errors above 7 %
  (Guo et al., arXiv 2510.22813). Bias-compensated filters reduce this to < 0.5 %.
- **Indian context already exists:** SAE India 2024 papers simulate EKF and
  particle filters for LFP packs on MIDC (SAE 2024-28-0223 and a related onboard
  EKF-PF paper on a 2.88 kWh LFP pack). So "EKF on LFP with MIDC" is **not new**.
- **Industry practice:** LFP vehicles recalibrate SOC at full charge — e.g. Tesla
  advises charging LFP cars to 100 % regularly, and shipped a 2022 software update
  to calibrate LFP SOC (driveteslacanada.ca, recurrentauto.com). This confirms that
  drift on the plateau is a real field problem.

### What we can honestly claim
Not "a new estimator", but a **quantified study**: how much SOC accuracy coulomb
counting and an EKF lose on an LFP e-scooter pack under Indian conditions —
45 °C, IDC/MIDC traffic, current-sensor offset, 30 % wrong initial SOC, cell
imbalance — with **error broken down by SOC region and linked to dOCV/dSOC
(observability)**.

### Gaps found (conservative) — useful for the capstone
1. Few papers report **error vs SOC** together with an observability measure
   (dOCV/dSOC, Kalman gain, observability Gramian) for LFP under 2W drive cycles.
2. **Recovery time from a wrong initial SOC** is rarely reported for LFP.
3. Combined stress (offset + heat + wrong start) on one consistent pack model.
4. Hybrid EKF + learned correction papers rarely report generalisation to unseen
   cycles/temperatures or how the network interacts with filter observability —
   a natural "observability-aware" capstone direction.

## 2. Changes made to Weeks 1–2 after this review

| Item | Before | Evidence | After |
|---|---|---|---|
| OCV at 100 % rest | 3.42 V | Vendor tables / datasheets: 3.30–3.40 V | **3.40 V** |
| Capacity at 5 °C | 0.95 × | 32700 datasheets guarantee only ≥ 75–80 % at 0–10 °C | **0.90 ×** (15 °C: 0.96 ×) |
| Cell thermal mass | 140 J/K | LFP cp ≈ 1050–1115 J/kg/K, cell 140–145 g | **150 J/K** |
| Group variation (nominal) | σ 1 % Q, 3 % R | 1100 fresh LFP cells: ~0.3–0.5 % Q, ~0.7–1.8 % R (TUM) | **σ 0.5 % Q, 1.5 % R**; old values kept as a stress case |
| ECE R15 shape | 15→0 km/h in one ramp | Regulation table: 15→10 in 2 s, 10→0 in 3 s | split into two ramps |
| Drive cycle | MIDC only | e-2W ranges are certified on **IDC** (AIS-039/040); MIDC is the car cycle | **added IDC**; MIDC kept as the high-speed stress cycle |

Kept unchanged (evidence supports them): hysteresis gap 20 mV (published 5–38 mV;
unchanged at 45 °C), R0 ≈ 12 mΩ DC (datasheet AC-IR ≤ 7.5–15 mΩ), RC time constants
10 s / 200 s (within published 0.5–25 s and 50–500 s bounds), 33 Ω bleed ≈ 100 mA
(Daly 16S LFP BMS: 100 ± 30 mA), cell-to-air 20–28 K/W (natural-convection estimate),
vehicle mass / power / CdA (Indian scooter specs, motorcycle CdA ≈ 0.5 m²).

## 3. Validation result added

| Check | Model | Reference |
|---|---|---|
| IDC distance / avg speed | 0.652 km / 21.75 km/h | 0.658 km / 21.93 km/h (AIS-039) |
| IDC max accel / decel | 0.65 / 0.62 m/s² | 0.65 / 0.63 m/s² |
| IDC efficiency | **48.6 km/kWh** (120 km on 2.46 kWh) | Ather Rizta 2.7 kWh LFP, 123 km IDC → 45.6 km/kWh (+7 %) |
| MIDC energy | 38.5 Wh/km | plausible for a cycle with a 90 km/h segment |

## 4. Still uncertain (stated as assumptions in the README)
- Exact EUDC-low-power breakpoints after 251 s and the IDC tail (85–108 s) — check
  against UNECE R83 Annex 4 / CMVR Annexure II.
- Arrhenius factors for R(T) (32 % lower R0 at 45 °C is plausible, 20–40 % typical,
  but not verified from an HPPC dataset).
- Hysteresis rate γ = 50 has no published LFP value; a sensitivity case is planned.

## 5. References
1. G. L. Plett, "Extended Kalman filtering for battery management systems of LiPB-based
   HEV battery packs", Parts 1–3, *J. Power Sources* 134(2), 2004, pp. 252–292.
   doi:10.1016/j.jpowsour.2004.02.031 (Part 1).
2. S. Zhao, S. R. Duncan, D. A. Howey, "Observability analysis and state estimation of
   lithium-ion batteries in the presence of sensor biases", arXiv:1510.06553.
3. F. Guo, L. D. Couto, K. Trad, G. Hu, M. Safari, "Residual bias compensation filter for
   physics-based SOC estimation in LFP batteries", arXiv:2510.22813.
4. SAE 2024-28-0223, "SoC estimation for LFP battery using extended Kalman filter and
   particle filter with adaptive battery parameters" (abstract only).
5. M. Naguib, P. Kollmeyer, A. Emadi, review of pack-level SOC estimation methods,
   *IEEE Access*, 2021 (abstract only).
6. A. Barai et al., LFP OCV hysteresis measurements, Univ. of Warwick, 2015
   (wrap.warwick.ac.uk/70160; snippet only) and follow-up wrap.warwick.ac.uk/81701.
7. Cell-to-cell variation of 1100 fresh LFP cells, TU Munich
   (portal.fis.tum.de; abstract only).
8. Datasheets: Sunmoon IFR32700 6000 mAh; FBTech IFR32700 6 Ah.
9. AIS-039 (IDC definition), AIS-040 (e-vehicle range), ARAI.
10. Ather Rizta LFP pack and IDC range: autocarindia.com (2026).
11. Daly 16S LFP passive-balancing BMS spec: dalybms.com.
12. Public LFP datasets for future validation: Mendeley "A123 26650 M1B" (UCCS,
    OCV + dynamic tests −25…45 °C), IEEE DataPort A123 ANR26650M1-B, CALCE A123 LFP.
