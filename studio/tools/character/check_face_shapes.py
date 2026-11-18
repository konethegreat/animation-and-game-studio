import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_probe as probe


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    body = probe.import_body(Path(args.source))
    probe.slim_lower_face(body)
    probe.add_build_keys(body)
    probe.add_feature_keys(body)
    probe.add_shape_keys(body)
    probe.pose_body(body)
    rims = probe.open_eyes(body)
    names = ("feat_eye_tilt", "feat_eye_hood", "feat_brow_arch", "feat_lip_bow", "feat_lip_balance", "feat_nose_tip")
    keys = body.data.shape_keys.key_blocks
    missing = [name for name in names if name not in keys]
    assert not missing, f"Missing independent face controls: {missing}"
    co, _ = probe.body_arrays(body)
    deltas = probe.key_deltas(body, names)
    x, y, z = co.T
    cheek = probe.key_deltas(body, ["feat_cheeks"])["feat_cheeks"]
    edges = probe.mesh_edges(body)
    edge_length = np.linalg.norm(co[edges[:, 0]] - co[edges[:, 1]], axis=1)
    gradient = np.linalg.norm(cheek[edges[:, 0]] - cheek[edges[:, 1]], axis=1) / np.maximum(edge_length, 1e-6)
    assert gradient.max() < 0.28, f"Cheekbone control has a discontinuity: gradient {gradient.max():.3f}"
    female = probe.key_deltas(body, ["build_female"])["build_female"]
    chin = (np.abs(x) < 0.35) & (y > 149) & (y < 152) & (z > 11.8)
    assert chin.any(), "Missing anterior chin sample"
    assert female[chin, 2].mean() > -0.3, f"Neck shaping retracts the chin: {female[chin, 2].mean():.3f} cm"
    for name, delta in deltas.items():
        assert np.isfinite(delta).all(), f"{name}: non-finite coordinates"
        lengths = np.linalg.norm(delta, axis=1)
        assert 0.04 < lengths.max() < 0.8, f"{name}: ineffective or oversized deformation"
        assert lengths[y < 145].max() < 1e-5, f"{name}: changes the body"
        for end in (-1, 1):
            points = co + end * delta
            assert np.isfinite(points).all(), f"{name}: invalid endpoint {end}"

    rim = rims[1.0]
    inner, outer = rim[np.argmin(x[rim])], rim[np.argmax(x[rim])]
    assert deltas["feat_eye_tilt"][outer, 1] - deltas["feat_eye_tilt"][inner, 1] > 0.15
    upper, lower = rim[np.argmax(y[rim])], rim[np.argmin(y[rim])]
    hood = deltas["feat_eye_hood"]
    assert hood[upper, 1] < -0.04 and hood[lower, 1] > 0.01
    for end in (-1, 1):
        aperture = co[rim] + hood[rim] * end
        assert 0.35 < np.ptp(aperture[:, 1]) < 2.0, f"Collapsed or oversized eye at {end}"

    xs, ys = probe.mouth_curve(body)
    line = np.interp(np.abs(x), xs, ys)
    seam = (np.abs(y - line) < 0.035) & (np.abs(x) < 2) & (z > 12)
    for name in ("feat_lip_bow", "feat_lip_balance"):
        assert np.linalg.norm(deltas[name][seam], axis=1).max(initial=0) < 0.02, f"{name}: opens mouth seam"

    parts = probe.build_eyes(body, rims, Path(args.out))
    brows = probe.build_brows(body)[0]
    assert "feat_brow_arch" in brows.data.shape_keys.key_blocks, "Brow hairs do not follow arch"
    assert np.linalg.norm(probe.key_deltas(brows, ["feat_brow_arch"])["feat_brow_arch"], axis=1).max() > 0.05
    for side, tag in ((1.0, "L"), (-1.0, "R")):
        waterline = next(part for part in parts if part.name == f"waterline_{tag}")
        lashes = next(part for part in parts if part.name == f"lashes_{tag}")
        for name in ("feat_eye_tilt", "feat_eye_hood"):
            assert name in waterline.data.shape_keys.key_blocks, f"Waterline missing {name}"
            actual = probe.key_deltas(waterline, [name])[name]
            expected = np.repeat(deltas[name][rims[side]], 2, axis=0)
            np.testing.assert_allclose(actual, expected, atol=2e-5)
            assert name in lashes.data.shape_keys.key_blocks, f"Lashes missing {name}"
            assert np.linalg.norm(probe.key_deltas(lashes, [name])[name], axis=1).max() > 0.03
    print("PASS: six bounded facial controls, lip seam, eye aperture, waterline, lashes and brow attachment")


if __name__ == "__main__":
    main()
