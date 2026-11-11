# Stategraph HTTP backend for the native terraform CLI.
#
# This is a PARTIAL configuration. `address` is deliberately omitted so this
# public repository does not publish the state UUID; the http backend reads it
# straight from the environment, along with the API key:
#
#   export TF_HTTP_ADDRESS="https://app.stategraph.cloud/api/v1/states/backend/<uuid>"
#   export TF_HTTP_PASSWORD="$STATEGRAPH_API_KEY"
#   task init
#
# Auth is HTTP Basic with the API key as the PASSWORD; the username is
# arbitrary. Never hardcode the key or the address in this file.
#
# Declaring the empty `backend "http"` block here (rather than in a gitignored
# `*_override.tf`) is what stops a fresh clone from silently initialising a
# LOCAL state file and planning to recreate every managed repository.
#
# plan and apply go through `stategraph tf` (see the Taskfile), whose
# transactions are the concurrency control. This backend has no lock endpoint,
# so it serves read-only inspection and state surgery only.

terraform {
  backend "http" {
    username = "terraform"
  }
}
