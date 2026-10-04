"""Logging setup. Log counts, identifiers of batches and fingerprints only; never
names, birth dates, contact values or other person-level attributes."""

import logging
import time


def configure_logging(level: str = "INFO") -> None:
    formatter = logging.Formatter(
        fmt="%(asctime)s.%(msecs)03dZ %(levelname)s %(name)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    formatter.converter = time.gmtime
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
