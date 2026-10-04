"""Command-line entry point: `campus-ops <command>`."""

import argparse
import json
import logging
import sys
from collections.abc import Sequence

from campus_ops.config import get_settings
from campus_ops.db import connect
from campus_ops.generators.dataset import generate_sources
from campus_ops.generators.edge_cases import EDGE_CASES
from campus_ops.logging_config import configure_logging
from campus_ops.source_writer import replace_source_data

log = logging.getLogger("campus_ops.cli")


def _parser() -> argparse.ArgumentParser:
    settings = get_settings()
    parser = argparse.ArgumentParser(prog="campus-ops", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    def add_generation_options(command: argparse.ArgumentParser) -> None:
        command.add_argument(
            "--seed", type=int, default=settings.seed, help="random seed (default %(default)s)"
        )
        command.add_argument(
            "--scale",
            type=float,
            default=settings.scale,
            help="size multiplier (default %(default)s)",
        )

    summary = commands.add_parser(
        "summary", help="generate in memory and print row counts and fingerprint"
    )
    add_generation_options(summary)
    load = commands.add_parser(
        "load-sources", help="replace SourceSystems data with the generated dataset"
    )
    add_generation_options(load)
    commands.add_parser("edge-cases", help="list the deliberate edge cases and their identifiers")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    settings = get_settings()
    configure_logging(settings.log_level)
    args = _parser().parse_args(argv)

    if args.command == "edge-cases":
        print(
            json.dumps(
                [
                    {"code": e.code, "description": e.description, "keys": e.keys}
                    for e in EDGE_CASES
                ],
                indent=2,
            )
        )
        return 0

    if not 0 < args.scale <= 20:  # noqa: PLR2004 - documented scale bound
        print("--scale must be greater than 0 and at most 20", file=sys.stderr)
        return 2

    dataset = generate_sources(args.seed, args.scale)
    summary = {
        "seed": args.seed,
        "scale": args.scale,
        "fingerprint": dataset.fingerprint(),
        "rows": dataset.counts(),
    }

    if args.command == "load-sources":
        log.info(
            "loading sources seed=%d scale=%s fingerprint=%s",
            args.seed,
            args.scale,
            summary["fingerprint"],
        )
        with connect(settings, settings.source_database) as connection:
            replace_source_data(connection, dataset)
        log.info("source load committed")

    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
