#!/usr/bin/env python
__license__ = """
The MIT License (MIT)
Copyright (c) 2018 Oleg Geier

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

import feedparser521 as fp
import json
import time

COPY_ENTRY_TAGS = False
COPY_ENTRY_SUMMARY = False


def valueFormatter(key, obj):
    if isinstance(obj, time.struct_time):
        return list(obj)
    if key == "etag":
        # stupid server convention to append but not consider changed etag
        # some servers append '-gzip' if gzip header is sent
        return obj.replace("-gzip", "")
    return obj


def copyIfExists(source, source_path, target, target_path):
    src = source
    trgt = target
    try:
        srcPTH = source_path.split("/")
        trgtPTH = target_path.split("/")
        for x in srcPTH[:-1]:
            src = src[x]
        for x in trgtPTH[:-1]:
            trgt = trgt[x]

        key = srcPTH[-1]
        trgt[trgtPTH[-1]] = valueFormatter(key, src[key])
    except Exception:
        pass


def prepareResult(obj):
    r = {"header": dict(), "feed": dict(), "entries": list()}
    try:
        if obj.debug_message.startswith("The feed has not changed since"):
            obj.status = 304
    except Exception:
        pass
    try:
        r["header"]["status"] = obj.status
        if obj.status == 304 or len(obj.entries) == 0:
            return r
    except Exception:
        return r

    copyIfExists(obj, "etag", r, "header/etag")
    copyIfExists(obj, "modified", r, "header/modified")
    copyIfExists(obj, "headers/date", r, "header/date")
    copyIfExists(obj, "feed/title", r, "feed/title")
    copyIfExists(obj, "feed/subtitle", r, "feed/subtitle")
    copyIfExists(obj, "feed/author", r, "feed/author")
    copyIfExists(obj, "feed/link", r, "feed/link")
    copyIfExists(obj, "feed/image/href", r, "feed/icon")
    copyIfExists(obj, "feed/published_parsed", r, "feed/published")

    for entry in obj.entries:
        e = dict()
        copyIfExists(entry, "title", e, "title")
        copyIfExists(entry, "subtitle", e, "subtitle")
        copyIfExists(entry, "author", e, "author")
        copyIfExists(entry, "link", e, "link")
        copyIfExists(entry, "published_parsed", e, "published")
        if COPY_ENTRY_SUMMARY:
            copyIfExists(entry, "summary", e, "summary")
        if COPY_ENTRY_TAGS:
            try:
                e["tags"] = list()
                for tag in entry.tags:
                    e["tags"].append(tag.term)
            except Exception:
                pass
        r["entries"].append(e)
    return r


def parse(url, etag=None, modified=None):
    if isinstance(modified, list):
        modified = time.struct_time(modified)
    d = fp.parse(url, etag=etag, modified=modified)
    return json.dumps(prepareResult(d), separators=(',', ':'))
