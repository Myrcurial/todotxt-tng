// Runs every check suite. Exits non-zero if any check fails.
// Usage: swift run TodoTxtCoreChecks   (or scripts/check.sh)

MainActor.assumeIsolated {
    specPriorityChecks()
    specDateChecks()
    specProjectContextChecks()
    specCompletionChecks()
    keyValueChecks()
    leniencyChecks()
    roundTripChecks()
    mutationChecks()
    unicodeChecks()
    extensionChecks()
    queryChecks()
    storeChecks()
    CheckRunner.shared.finish()
}
