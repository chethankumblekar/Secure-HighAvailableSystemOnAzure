package k8srequiredresources

# This is the exact bug this project shipped once: `required - provided`
# between an array (input.parameters.requests, per the CRD schema) and a
# set silently evaluates to undefined in Rego, so `count(missing) > 0`
# never fires and the constraint reports "enforced" while admitting
# everything. This test fails loudly under that bug — see
# docs/roadmap.md's Phase 5 entry and the fix commit for the full story.
test_violates_when_resources_entirely_missing {
	count(violation) > 0 with input as {
		"review": {"object": {"spec": {"containers": [{"name": "app"}]}}},
		"parameters": {"requests": ["cpu", "memory"], "limits": ["cpu", "memory"]},
	}
}

test_violates_when_only_limits_missing {
	count(violation) > 0 with input as {
		"review": {"object": {"spec": {"containers": [{
			"name": "app",
			"resources": {"requests": {"cpu": "25m", "memory": "32Mi"}},
		}]}}},
		"parameters": {"requests": ["cpu", "memory"], "limits": ["cpu", "memory"]},
	}
}

test_violates_when_only_requests_missing {
	count(violation) > 0 with input as {
		"review": {"object": {"spec": {"containers": [{
			"name": "app",
			"resources": {"limits": {"cpu": "250m", "memory": "128Mi"}},
		}]}}},
		"parameters": {"requests": ["cpu", "memory"], "limits": ["cpu", "memory"]},
	}
}

test_no_violation_when_requests_and_limits_present {
	count(violation) == 0 with input as {
		"review": {"object": {"spec": {"containers": [{
			"name": "app",
			"resources": {
				"requests": {"cpu": "25m", "memory": "32Mi"},
				"limits": {"cpu": "250m", "memory": "128Mi"},
			},
		}]}}},
		"parameters": {"requests": ["cpu", "memory"], "limits": ["cpu", "memory"]},
	}
}

test_violation_message_names_the_container {
	vs := violation with input as {
		"review": {"object": {"spec": {"containers": [{"name": "billing-api"}]}}},
		"parameters": {"requests": ["cpu", "memory"], "limits": ["cpu", "memory"]},
	}
	v := vs[_]
	contains(v.msg, "billing-api")
}
