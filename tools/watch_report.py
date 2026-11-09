"""Generate the Chinese acceptance report from tools/watch/run_result.json."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def translate(reason: str) -> str:
    if reason == "test database reset failed":
        return "测试库初始化失败"
    if reason.startswith("backend:"):
        return "后端验收未通过（" + reason[len("backend:"):].strip() + "）"
    if reason.startswith("ClientSmoke failed"):
        return "ClientSmoke 未通过（" + reason[len("ClientSmoke failed"):].strip(" ()") + "）"
    if reason.startswith("ReplaySmoke failed"):
        return "ReplaySmoke 未通过（" + reason[len("ReplaySmoke failed"):].strip(" ()") + "）"
    if reason.startswith("screenshot suite failed"):
        return "截图套件未完成（" + reason[len("screenshot suite failed"):].strip(" ()") + "）"
    if reason.startswith("missing screenshots:"):
        return "缺少截图：" + reason.split(":", 1)[1].strip()
    if reason.startswith("screenshots too small:"):
        return "截图过小/疑似空白：" + reason.split(":", 1)[1].strip()
    if reason.startswith("blank screenshots:"):
        return "疑似空白截图：" + reason.split(":", 1)[1].strip()
    if reason == "S04 report content too low":
        return "S04 战报内容量不足"
    if reason == "S05 replay content too low":
        return "S05 回放内容量不足"
    if reason.endswith(" missing"):
        return "资产缺失：" + reason[: -len(" missing")]
    if reason.endswith(" spec mismatch"):
        return "资产规格不符：" + reason[: -len(" spec mismatch")]
    if reason.endswith(" corners not transparent"):
        return "资产四角不透明：" + reason[: -len(" corners not transparent")]
    if reason == "probe JSON parse failed":
        return "截图/资产探针 JSON 解析失败"
    if reason == "probe produced no result":
        return "截图/资产探针未生成结果"
    if reason == "python not found; cannot probe screenshots/assets":
        return "找不到 Python，无法做截图/资产探针"
    return reason


def mark(value: bool) -> str:
    return "PASS" if value else "FAIL"


def build_report(data: dict) -> str:
    status = str(data.get("status", "FAIL"))
    time_text = str(data.get("time", "")).replace("T", " ")
    lines: list[str] = []
    lines.append("# 灵宠山河 · 自动验收状态")
    lines.append("")
    lines.append(f"- 检查时间：{time_text}")
    lines.append(f"- 结论：**{status}**")
    lines.append(f"- 指纹：`{data.get('hash', '')}`")
    last_pass = data.get("last_pass") or "从未通过"
    lines.append(f"- 上次通过：{last_pass}")
    lines.append(f"- 本轮耗时：{data.get('duration_sec', 0)} 秒")
    lines.append("")

    backend_ok = bool(data.get("backend_ok"))
    smoke_ok = bool(data.get("smoke_ok"))
    replay_ok = bool(data.get("replay_ok"))
    capture_ok = bool(data.get("capture_ok"))
    missing = data.get("missing") or []
    too_small = data.get("too_small") or []
    blank = data.get("blank") or []
    content_fail = data.get("content_fail") or []
    asset_fail = data.get("asset_fail") or []
    apk_stale = bool(data.get("apk_stale"))
    capture_skipped = bool(data.get("capture_skipped"))

    lines.append("## 硬检查")
    lines.append("")
    lines.append("| 检查 | 结果 | 详情 |")
    lines.append("|---|---|---|")
    lines.append(f"| 后端验收 | {mark(backend_ok)} | {data.get('backend_passed', 0)} passed / {data.get('backend_failed', 0)} failed |")
    lines.append(f"| ClientSmoke | {mark(smoke_ok)} | 登录 / 军令 / 教师权限 |")
    lines.append(f"| ReplaySmoke | {mark(replay_ok)} | 战局回放 |")
    capture_detail = "本轮跳过" if capture_skipped else "平板 / 手机竖屏 / 手机横屏"
    lines.append(f"| 截图套件 | {mark(capture_ok)} | {capture_detail} |")
    shot_ok = not missing and not too_small
    lines.append(f"| 截图完整性 | {mark(shot_ok)} | 缺 {len(missing)} / 过小 {len(too_small)} |")
    panel_ok = not blank and not content_fail
    lines.append(f"| 空面板启发式 | {mark(panel_ok)} | S04 战报 / S05 回放内容量 |")
    lines.append(f"| 美术资产 | {mark(not asset_fail)} | 5 城地标 + 6 表情 + UI Kit + map_c |")
    apk_label = "STALE" if apk_stale else "OK"
    lines.append(f"| APK | {apk_label} | {data.get('apk_mb', 0)} MB，{data.get('apk_time') or '缺失'} |")
    lines.append("")

    reasons = data.get("fail_reasons") or []
    if reasons or any([missing, too_small, blank, content_fail, asset_fail]):
        lines.append("## 失败项")
        lines.append("")
        if reasons:
            for reason in reasons:
                lines.append(f"- {translate(str(reason))}")
        else:
            if missing:
                lines.append("- 缺少截图：" + "、".join(map(str, missing)))
            if too_small:
                lines.append("- 截图过小/疑似空白：" + "、".join(map(str, too_small)))
            if blank:
                lines.append("- 疑似空白截图：" + "、".join(map(str, blank)))
            for item in content_fail:
                lines.append(f"- {translate(str(item))}")
            for item in asset_fail:
                lines.append(f"- {translate(str(item))}")
        lines.append("")

    images = data.get("images") or []
    if images:
        lines.append("## 截图明细")
        lines.append("")
        lines.append("| 截图 | 尺寸 | 大小 | 内容分 | 结果 |")
        lines.append("|---|---:|---:|---:|---|")
        for metric in images:
            name = str(metric.get("name", ""))
            width = metric.get("width", 0)
            height = metric.get("height", 0)
            kb = round(int(metric.get("bytes", 0)) / 1024)
            std = metric.get("std", 0)
            colors = metric.get("unique", 0)
            verdict = "疑似空白" if metric.get("blank_like") else "OK"
            lines.append(f"| {name} | {width}×{height} | {kb} KB | std={std} / colors={colors} | {verdict} |")
        lines.append("")

    dirty = data.get("dirty") or []
    lines.append("## 工作区")
    lines.append("")
    lines.append(f"- 未提交改动：{len(dirty)} 项")
    if dirty:
        lines.append("")
        for line in dirty[:15]:
            lines.append(f"- `{line}`")
        if len(dirty) > 15:
            lines.append(f"- ……其余 {len(dirty) - 15} 项")
    lines.append("")

    lines.append("## 下一步")
    lines.append("")
    if status == "PASS":
        if dirty:
            lines.append("- 自动验收通过，可以审阅未提交改动并合并 / 打包。")
        else:
            lines.append("- 自动验收通过，工作区干净；可进入真机试跑或下一里程碑。")
        if apk_stale:
            lines.append("- APK 落后于客户端源码，需要重打。")
    elif status == "WARN":
        lines.append("- 代码、后端、截图通过；APK 过期或截图不新鲜，重打 APK / 重拍截图。")
    elif status == "FAIL":
        lines.append("- 按“失败项”修；只改对应区域，修完重拍截图并重跑冒烟。")
        lines.append("- 不接受空面板、黑块、默认控件作为完成。")
    elif status == "UNSTABLE":
        lines.append("- 验收过程中源码发生变化（Agent 正在写）；下一轮会自动重跑。")
    else:
        lines.append("- 查看日志。")
    lines.append("")
    lines.append("> 本报告只覆盖机器可判部分；视觉盲评、真机 FPS、触控手感仍需人工验收。")
    lines.append("")
    lines.append("联系表：`tools/watch/contact_latest.jpg`")
    lines.append("")
    return "\r\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--fail-msg", default="")
    parser.add_argument("--ready-msg", default="")
    args = parser.parse_args()

    result_path = Path(args.result)
    data = json.loads(result_path.read_text(encoding="utf-8-sig"))
    report = build_report(data)
    with open(args.status, "w", encoding="utf-8-sig", newline="") as f:
        f.write(report)

    status = str(data.get("status", "FAIL"))
    time_text = str(data.get("time", "")).replace("T", " ")
    dirty = data.get("dirty") or []

    if args.fail_msg:
        fail_path = Path(args.fail_msg)
        if status == "FAIL":
            lines = [f"【自动验收未通过】{time_text}", "", "失败项："]
            reasons = data.get("fail_reasons") or []
            if reasons:
                lines.extend("- " + translate(str(r)) for r in reasons)
            else:
                lines.append("- 见 tools/watch/STATUS.md")
            lines.extend([
                "",
                "请只改 client/（或对应后端文件），修完重拍截图，并重跑 ClientSmoke / ReplaySmoke。",
                "报告：tools/watch/STATUS.md",
                "联系表：tools/watch/contact_latest.jpg",
            ])
            with open(fail_path, "w", encoding="utf-8-sig", newline="") as f:
                f.write("\r\n".join(lines))
        elif fail_path.exists():
            fail_path.unlink()

    if args.ready_msg:
        ready_path = Path(args.ready_msg)
        if status == "PASS" and dirty:
            lines = [
                f"【自动验收通过，可合并 / 打包】{time_text}",
                "",
                f"未提交改动：{len(dirty)} 项",
                "",
                "报告：tools/watch/STATUS.md",
                "联系表：tools/watch/contact_latest.jpg",
            ]
            with open(ready_path, "w", encoding="utf-8-sig", newline="") as f:
                f.write("\r\n".join(lines))
        elif ready_path.exists():
            ready_path.unlink()


if __name__ == "__main__":
    main()
