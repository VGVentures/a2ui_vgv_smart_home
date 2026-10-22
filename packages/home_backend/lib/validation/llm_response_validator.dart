/// {@template llm_response_validator}
/// A rule applied to a fully assembled LLM response before it reaches the
/// client.
/// {@endtemplate}
///
/// Implementations return `null` when the response satisfies the rule.
/// Otherwise they return a non-empty list of human-readable error lines, each
/// already formatted for direct inclusion in a retry prompt sent back to the
/// LLM.
///
/// Concrete validators typically hold state (catalog identifiers, schemas)
/// so the single-method interface is intentional.
// ignore: one_member_abstracts
abstract interface class LlmResponseValidator {
  /// Validates [response]. Returns `null` on success or a list of error
  /// lines on failure.
  List<String>? validate(String response);
}

/// {@template llm_response_repairer}
/// A validator that can also put a reply right, instead of sending it back to
/// the model.
/// {@endtemplate}
///
/// For a rule the model keeps breaking and code can always mend, like adding
/// up the columns of a screen, mending is cheaper and surer than a retry: it
/// costs no model call and cannot fail the same way twice.
// ignore: one_member_abstracts
abstract interface class LlmResponseRepairer {
  /// Returns [response] with what the rule objects to put right, or [response]
  /// itself when it already satisfies the rule or cannot be mended.
  String repair(String response);
}
