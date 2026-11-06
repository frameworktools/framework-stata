"""fw_bridge.py: Framework for Stata's bridge to framework-py.

Part of the framework package. Stata runs it with ``python script``. Arguments
travel in a JSON file and results come back in another, so titles and paths
need no quoting.

    python script fw_bridge.py, args(<action> <args.json> <result.json>)
"""

import json
import sys
from pathlib import Path


def _capture_receipt(framework, receipts):
    """Keep the delivery receipt that framework-py passes to track_external.

    framework.publish() returns only the URL. The receipt also has the
    version, the version link, and the folder location, which Stata reports
    as r(version), r(version_url), and r(location) for every backend.
    """
    try:
        import framework.publish_bundle as bundle
    except ImportError:
        return None
    original = getattr(bundle, "track_external", None)
    if original is None:
        return None

    def track_external(manifest, receipt, *args, **kwargs):
        if isinstance(receipt, dict):
            receipts.append({**receipt, "slug": (manifest or {}).get("slug")})
        return original(manifest, receipt, *args, **kwargs)

    bundle.track_external = track_external
    return lambda: setattr(bundle, "track_external", original)


def _text(value):
    return "" if value is None else str(value)


def main(argv: list[str]) -> None:
    action, args_file, result_file = argv[1], argv[2], argv[3]
    args = json.loads(Path(args_file).read_text(encoding="utf-8"))
    try:
        import framework

        if action == "version":
            result = {"ok": True, "version": getattr(framework, "__version__", "")}
        elif action == "publish":
            options = {
                key: args[key]
                for key in ("to", "slug", "title", "description", "kind", "visibility")
                if args.get(key)
            }
            receipts: list[dict] = []
            restore = _capture_receipt(framework, receipts)
            try:
                url = framework.publish(
                    args["path"], include_private=bool(args.get("include_private")), **options
                )
            finally:
                if restore is not None:
                    restore()
            if isinstance(url, list):
                url = url[0] if url else ""
            receipt = receipts[-1] if receipts else {}
            location = _text(receipt.get("location"))
            result = {
                "ok": True,
                "url": _text(receipt.get("url")) or ("" if url == location else _text(url)),
                "version": _text(receipt.get("version")),
                "version_url": _text(receipt.get("version_url")),
                "location": location,
                "slug": _text(receipt.get("slug")),
            }
        else:
            result = {"ok": False, "error": f"Unknown action {action}"}
    except Exception as error:  # Every failure goes back to Stata as a message.
        result = {"ok": False, "error": str(error), "type": type(error).__name__}
    Path(result_file).write_text(json.dumps(result), encoding="utf-8")


main(sys.argv)
