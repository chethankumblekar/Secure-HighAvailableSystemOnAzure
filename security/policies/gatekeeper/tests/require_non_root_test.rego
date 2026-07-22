package k8srequirenonroot

test_violates_when_securitycontext_missing {
	count(violation) > 0 with input as {"review": {"object": {"spec": {"containers": [{"name": "app"}]}}}}
}

test_violates_when_runasnonroot_false {
	count(violation) > 0 with input as {"review": {"object": {"spec": {
		"securityContext": {"runAsNonRoot": false},
		"containers": [{"name": "app"}],
	}}}}
}

test_no_violation_when_runasnonroot_true {
	count(violation) == 0 with input as {"review": {"object": {"spec": {
		"securityContext": {"runAsNonRoot": true, "runAsUser": 65532},
		"containers": [{"name": "app"}],
	}}}}
}
