// What a self-check answers, so that one entry point can aggregate several.
//
// Three outcomes rather than two, because one of the checks asks the network:
// "I could not find out" has to stay distinguishable from "I found out, and it
// is wrong". Collapsing them makes a dropped connection read as a broken
// release — and be believed.

enum CheckOutcome {
  /// Nothing to report.
  ok,

  /// Real findings, listed in [CheckReport.findings].
  findings,

  /// The check could not be carried out at all. Not a finding.
  unavailable,
}

class CheckReport {
  const CheckReport.ok(this.title, this.summary)
    : outcome = CheckOutcome.ok,
      findings = const [];

  const CheckReport.findings(this.title, this.findings, this.summary)
    : outcome = CheckOutcome.findings;

  const CheckReport.unavailable(this.title, this.summary)
    : outcome = CheckOutcome.unavailable,
      findings = const [];

  final String title;
  final CheckOutcome outcome;
  final List<String> findings;

  /// One line: what the check concluded, and — when there are findings — how
  /// they are fixed. Printed whether or not anything was found.
  final String summary;

  /// The exit code this check would use on its own: 0 clean, 1 findings,
  /// 2 could not be carried out.
  int get exitCode => switch (outcome) {
    CheckOutcome.ok => 0,
    CheckOutcome.findings => 1,
    CheckOutcome.unavailable => 2,
  };
}
