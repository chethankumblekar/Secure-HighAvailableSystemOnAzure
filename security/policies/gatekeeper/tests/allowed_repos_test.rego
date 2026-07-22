package k8sallowedrepos

test_violates_disallowed_registry {
	count(violation) > 0 with input as {
		"review": {"object": {"spec": {"containers": [{"name": "app", "image": "docker.io/library/nginx"}]}}},
		"parameters": {"repos": ["ghcr.io/chethankumblekar/", "tenantforge/"]},
	}
}

test_no_violation_ghcr_registry {
	count(violation) == 0 with input as {
		"review": {"object": {"spec": {"containers": [{
			"name": "app",
			"image": "ghcr.io/chethankumblekar/tenantforge-sample-service:latest",
		}]}}},
		"parameters": {"repos": ["ghcr.io/chethankumblekar/", "tenantforge/"]},
	}
}

test_no_violation_local_dev_registry {
	count(violation) == 0 with input as {
		"review": {"object": {"spec": {"containers": [{"name": "app", "image": "tenantforge/sample-service:dev"}]}}},
		"parameters": {"repos": ["ghcr.io/chethankumblekar/", "tenantforge/"]},
	}
}

test_prefix_match_is_not_substring_match {
	# "ghcr.io/chethankumblekar-evil/x" must NOT pass just because it
	# contains "ghcr.io/chethankumblekar" as a substring somewhere other
	# than a true prefix boundary.
	count(violation) > 0 with input as {
		"review": {"object": {"spec": {"containers": [{
			"name": "app",
			"image": "evil.io/ghcr.io/chethankumblekar/tenantforge-sample-service",
		}]}}},
		"parameters": {"repos": ["ghcr.io/chethankumblekar/", "tenantforge/"]},
	}
}
