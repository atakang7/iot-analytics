import unittest
from verify_actions import verify


class ActionPolicyTests(unittest.TestCase):
    def test_sha_is_required(self):
        verify("steps:\n - uses: actions/checkout@" + "a" * 40, "test.yaml")

    def test_mutable_tag_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "mutable"):
            verify("steps:\n - uses: actions/checkout@v4", "test.yaml")

    def test_privileged_trigger_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "pull_request_target"):
            verify("pull_request_target:\nsteps:\n - uses: actions/checkout@" + "a" * 40, "test.yaml")

    def test_broad_write_all_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "write-all"):
            verify("permissions: write-all\nsteps:\n - uses: actions/checkout@" + "a" * 40, "test.yaml")


if __name__ == "__main__":
    unittest.main()
