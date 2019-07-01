#!/usr/bin/env python3

import sys
import json
from parse import parse, with_pattern


def parse_lower(text):
    return text.lower()


@with_pattern(r".*")
def parse_optional(text):
    return text


def parse_kat(text):
    lines = text.split("\n")[1:]
    parsers = dict(lower=parse_lower, optional=parse_optional)
    return dict(parse("{:lower} = {:optional}", line, parsers) for line in lines)


with open(sys.argv[1]) as file:
    data = file.read().strip()

kats = list(map(parse_kat, data.split("\n\n")))

with open(sys.argv[2], "w") as file:
    json.dump(kats, file, indent=2)
