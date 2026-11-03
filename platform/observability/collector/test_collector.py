import unittest

from collector import log_time_ns, parse_lines, loki_payload


class CollectorTests(unittest.TestCase):
    def test_nanosecond_timestamp_preserved(self):
        self.assertEqual(log_time_ns("2026-01-01T00:00:00.000000001Z"),
                         1767225600000000001)

    def test_reject_bad_time(self):
        with self.assertRaises(ValueError):
            log_time_ns("tomorrow")

    def test_deduplicate_by_committed_cursor(self):
        raw = ("2026-01-01T00:00:00.000000001Z one\n"
               "2026-01-01T00:00:00.000000002Z two\n")
        first = parse_lines(raw, 0)
        self.assertEqual(len(first), 2)
        self.assertEqual(parse_lines(raw, first[-1][0]), [])

    def test_payload_uses_bounded_labels(self):
        payload = loki_payload("iot-validation", "a-pod", "ingestion", [(1, "hello")])
        stream, = payload["streams"]
        self.assertEqual(stream["stream"]["service"], "ingestion")
        self.assertEqual(stream["values"], [["1", "hello"]])


if __name__ == "__main__":
    unittest.main()
